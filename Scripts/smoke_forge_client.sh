#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/veqral-forge-client-smoke.XXXXXX")
HOST_PID_FILE="${WORK}/host.pid"
CONTROLLER_PID=""
cleanup() {
  if [[ -f "${HOST_PID_FILE}" ]]; then
    kill "$(<"${HOST_PID_FILE}")" >/dev/null 2>&1 || true
  fi
  if [[ -n "${CONTROLLER_PID}" ]]; then
    kill "${CONTROLLER_PID}" >/dev/null 2>&1 || true
    wait "${CONTROLLER_PID}" >/dev/null 2>&1 || true
  fi
  rm -rf "${WORK}"
}
trap cleanup EXIT

PORT=$(python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(('127.0.0.1', 0))
    print(sock.getsockname()[1])
PY
)
HOST_HOME="${WORK}/host"
mkdir -p "${HOST_HOME}"

swift build --package-path "${ROOT}/MacHost" --product VeqralHost >/dev/null
swiftc \
  -swift-version 6 \
  -strict-concurrency=complete \
  -o "${WORK}/ForgeClientSmoke" \
  "${ROOT}/Scripts/ForgeClientSmoke.swift" \
  "${ROOT}/Veqral/ForgeCoding.swift" \
  "${ROOT}/Veqral/ForgeRuntimeModels.swift" \
  "${ROOT}/Veqral/ForgeRemoteProjection.swift" \
  "${ROOT}/Veqral/RunModels.swift" \
  "${ROOT}/Veqral/RemoteRunModels.swift" \
  "${ROOT}/Veqral/RemoteStreamModels.swift" \
  "${ROOT}/Veqral/RemoteArtifactModels.swift" \
  "${ROOT}/Veqral/RemoteDiffModels.swift" \
  "${ROOT}/Veqral/RemoteToolModels.swift" \
  "${ROOT}/Veqral/RemoteHostModels.swift" \
  "${ROOT}/Veqral/RemoteHostSecurity.swift" \
  "${ROOT}/Veqral/RemoteHostClient.swift" \
  "${ROOT}/MacHost/Sources/VeqralShared/VeqralForgeDomain.swift" \
  "${ROOT}/MacHost/Sources/VeqralShared/VeqralRedactor.swift"

(
  start_host() {
    VEQRAL_HOST_HOME="${HOST_HOME}" \
    VEQRAL_HOST_PORT="${PORT}" \
    VEQRAL_HOST_WORKING_DIRECTORY="${ROOT}" \
    VEQRAL_TEST_MODE=1 \
    VEQRAL_TEST_SECRET_STORE_PATH="${HOST_HOME}/test-secrets.json" \
    VEQRAL_DISABLE_DISCORD_WEBHOOK=1 \
    VEQRAL_PUSH_ENABLED=0 \
    "${ROOT}/MacHost/.build/debug/VeqralHost" >>"${WORK}/host.log" 2>&1 &
    HOST_PID=$!
    printf '%s\n' "${HOST_PID}" >"${HOST_PID_FILE}"
  }

  wait_ready() {
    for _ in {1..100}; do
      if curl -fsS "http://127.0.0.1:${PORT}/v1/pairing" >/dev/null 2>&1; then
        return 0
      fi
      if ! kill -0 "${HOST_PID}" >/dev/null 2>&1; then
        return 1
      fi
      sleep 0.1
    done
    return 1
  }

  start_host
  if ! wait_ready; then
    : >"${WORK}/host.failed"
    exit 1
  fi
  : >"${WORK}/initial.ready"

  for _ in {1..1200}; do
    [[ -f "${WORK}/restart.request" ]] && break
    sleep 0.1
  done
  if [[ ! -f "${WORK}/restart.request" ]]; then
    : >"${WORK}/host.failed"
    exit 1
  fi

  kill "${HOST_PID}" >/dev/null 2>&1 || true
  wait "${HOST_PID}" >/dev/null 2>&1 || true
  start_host
  if ! wait_ready; then
    : >"${WORK}/host.failed"
    exit 1
  fi
  : >"${WORK}/restart.done"
  wait "${HOST_PID}"
) &
CONTROLLER_PID=$!

for _ in {1..120}; do
  [[ -f "${WORK}/initial.ready" ]] && break
  if [[ -f "${WORK}/host.failed" ]]; then
    printf 'Host failed; log: %s\n' "${WORK}/host.log" >&2
    exit 1
  fi
  sleep 0.1
done
if [[ ! -f "${WORK}/initial.ready" ]]; then
  printf 'Host readiness timed out; log: %s\n' "${WORK}/host.log" >&2
  exit 1
fi

"${WORK}/ForgeClientSmoke" "http://127.0.0.1:${PORT}" "${ROOT}" "${WORK}"
