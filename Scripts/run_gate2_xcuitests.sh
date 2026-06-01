#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pick_free_port() {
  python3 - <<'PY'
import socket
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.bind(("127.0.0.1", 0))
    print(s.getsockname()[1])
PY
}

HOST_PORT="${VEQRAL_GATE2_HOST_PORT:-18778}"
WEBHOOK_PORT="${VEQRAL_GATE2_WEBHOOK_PORT:-$(pick_free_port)}"
PROJECT_ID="${VEQRAL_GATE2_PROJECT_ID:-gate2-xcuitest}"
SOURCE="veqral-${PROJECT_ID}"
IPHONE_SIM_DEST="${VEQRAL_GATE2_IPHONE_SIM_DEST:-platform=iOS Simulator,id=45599AC5-0234-4E5A-936D-1EEF229459CD}"
IPAD_SIM_DEST="${VEQRAL_GATE2_IPAD_SIM_DEST:-platform=iOS Simulator,id=0412878A-E27B-4782-979F-30D66449CF4E}"
IPHONE_DEVICE_DEST="${VEQRAL_GATE2_IPHONE_DEVICE_DEST:-platform=iOS,id=00008140-001611892606801C}"
IPAD_DEVICE_DEST="${VEQRAL_GATE2_IPAD_DEVICE_DEST:-platform=iOS,id=00008142-00022594112B801C}"

WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/veqral-gate2.XXXXXX")"
MEM_TMP="$(mktemp -d "${TMPDIR:-/tmp}/veqral-gate2-memory.XXXXXX")"
WEBHOOK_LOG="${WORK_ROOT}/webhook.log"
REPORT="${WORK_ROOT}/memory-inheritance.md"
HOST_PID=""
WEBHOOK_PID=""

cleanup() {
  if [[ -n "${HOST_PID}" ]]; then kill "${HOST_PID}" >/dev/null 2>&1 || true; fi
  if [[ -n "${WEBHOOK_PID}" ]]; then kill "${WEBHOOK_PID}" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

echo "[gate2] Running real Hermes memory inheritance for source ${SOURCE}"
MEMORY_ATTEMPTS="${VEQRAL_GATE2_MEMORY_ATTEMPTS:-3}"
MEMORY_OK=0
for attempt in $(seq 1 "${MEMORY_ATTEMPTS}"); do
  ATTEMPT_REPORT="${REPORT%.md}-attempt-${attempt}.md"
  if TMPDIR="${MEM_TMP}/" \
    VEQRAL_MEMTEST_KEEP_WORKDIR=1 \
    VEQRAL_MEMTEST_SOURCE="${SOURCE}" \
    swift run --package-path "${ROOT}/MacHost" VeqralHostSmoke verify-memory-inheritance --report "${ATTEMPT_REPORT}"; then
    cp "${ATTEMPT_REPORT}" "${REPORT}"
    MEMORY_OK=1
    break
  fi
  cp "${ATTEMPT_REPORT}" "${REPORT}" 2>/dev/null || true
  echo "[gate2] Memory inheritance attempt ${attempt}/${MEMORY_ATTEMPTS} failed; retrying real Hermes run." >&2
done
if [[ "${MEMORY_OK}" != "1" ]]; then
  echo "[gate2] Hermes memory inheritance did not pass after ${MEMORY_ATTEMPTS} real attempts. See ${REPORT}." >&2
  exit 1
fi

FACT="$(
python3 - "${REPORT}" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
for line in text.splitlines():
    if line.startswith("- Code name:"):
        parts = line.split(chr(96))
        if len(parts) >= 3:
            print(parts[1])
            break
else:
    raise SystemExit("missing code name in memory report")
PY
)"
HERMES_HOME="$(getconf DARWIN_USER_TEMP_DIR)${SOURCE}/hermes-home"
if [[ ! -d "${HERMES_HOME}" ]]; then
  echo "[gate2] Hermes home not found: ${HERMES_HOME}" >&2
  exit 1
fi

echo "[gate2] Starting local 2xx Discord webhook sink on ${WEBHOOK_PORT}"
python3 -u - "${WEBHOOK_PORT}" "${WEBHOOK_LOG}" <<'PY' &
import http.server, socketserver, sys, time
port = int(sys.argv[1])
log_path = sys.argv[2]
class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("content-length", "0"))
        body = self.rfile.read(length)
        with open(log_path, "ab") as log:
            log.write(str(time.time()).encode() + b" " + self.path.encode() + b" " + body + b"\n")
        self.send_response(204)
        self.end_headers()
    def log_message(self, format, *args):
        return
with socketserver.TCPServer(("127.0.0.1", port), Handler) as httpd:
    httpd.serve_forever()
PY
WEBHOOK_PID=$!

if lsof -nP -iTCP:"${HOST_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "[gate2] Host port ${HOST_PORT} is already in use. Set VEQRAL_GATE2_HOST_PORT to an available port." >&2
  exit 1
fi

echo "[gate2] Starting isolated Mac Host on ${HOST_PORT}"
VEQRAL_HOST_HOME="${WORK_ROOT}/host" \
VEQRAL_HOST_PORT="${HOST_PORT}" \
VEQRAL_HOST_WORKING_DIRECTORY="${ROOT}" \
HERMES_HOME="${HERMES_HOME}" \
VEQRAL_DISCORD_WEBHOOK="http://127.0.0.1:${WEBHOOK_PORT}/discord" \
swift run --package-path "${ROOT}/MacHost" VeqralHost >/tmp/veqral-gate2-host.log 2>&1 &
HOST_PID=$!

for _ in {1..80}; do
  if curl -fsS "http://127.0.0.1:${HOST_PORT}/v1/pairing" >/tmp/veqral-gate2-pairing.json 2>/dev/null; then
    break
  fi
  sleep 0.5
done
if [[ ! -s /tmp/veqral-gate2-pairing.json ]]; then
  echo "[gate2] Mac Host did not expose /v1/pairing" >&2
  tail -80 /tmp/veqral-gate2-host.log >&2 || true
  exit 1
fi

echo "[gate2] Mac Host pairing endpoint is ready"

pairing_url_for_label() {
  local label="$1"
  curl -fsS "http://127.0.0.1:${HOST_PORT}/v1/pairing" >"${WORK_ROOT}/pairing-${label}.json"
  python3 - "${WORK_ROOT}/pairing-${label}.json" "${HOST_PORT}" "${label}" <<'PY'
import json, sys, urllib.parse
data = json.load(open(sys.argv[1]))
port = sys.argv[2]
label = sys.argv[3]
if "simulator" in label:
    endpoint = f"http://127.0.0.1:{port}"
    print("veqral://pair?" + urllib.parse.urlencode({"endpoint": endpoint, "code": data["pairingCode"]}))
else:
    print(data["pairingURL"])
PY
}

run_xcuitest() {
  local label="$1"
  local destination="$2"
  local derived="${WORK_ROOT}/DerivedData-${label// /-}"
  local pairing_url
  pairing_url="$(pairing_url_for_label "${label}")"
  echo "[gate2] Pairing URL for ${label}: ${pairing_url%%\&code=*}"
  echo "[gate2] XCUITest: ${label} (${destination})"
  if [[ "${label}" == *"-device" ]]; then
    VEQRAL_GATE2_PAIRING_URL="${pairing_url}" \
    VEQRAL_GATE2_WORKING_DIRECTORY="${ROOT}" \
    VEQRAL_GATE2_PROJECT_ID="${PROJECT_ID}" \
    VEQRAL_GATE2_MEMORY_FACT="${FACT}" \
    xcodebuild \
      -project "${ROOT}/Veqral.xcodeproj" \
      -scheme Veqral \
      -configuration Debug \
      -destination "${destination}" \
      -derivedDataPath "${derived}" \
      -allowProvisioningUpdates \
      -only-testing:VeqralUITests/Gate2AcceptanceUITests/testGate2Acceptance \
      test
  else
    VEQRAL_GATE2_PAIRING_URL="${pairing_url}" \
    VEQRAL_GATE2_WORKING_DIRECTORY="${ROOT}" \
    VEQRAL_GATE2_PROJECT_ID="${PROJECT_ID}" \
    VEQRAL_GATE2_MEMORY_FACT="${FACT}" \
    xcodebuild \
      -project "${ROOT}/Veqral.xcodeproj" \
      -scheme Veqral \
      -configuration Debug \
      -destination "${destination}" \
      -derivedDataPath "${derived}" \
      -only-testing:VeqralUITests/Gate2AcceptanceUITests/testGate2Acceptance \
      test
  fi
}

ONLY_TARGET="${VEQRAL_GATE2_ONLY:-all}"
if [[ "${ONLY_TARGET}" == "all" || "${ONLY_TARGET}" == "iphone-simulator" ]]; then
  run_xcuitest "iphone-simulator" "${IPHONE_SIM_DEST}"
fi
if [[ "${ONLY_TARGET}" == "all" || "${ONLY_TARGET}" == "ipad-simulator" ]]; then
  run_xcuitest "ipad-simulator" "${IPAD_SIM_DEST}"
fi

if [[ "${VEQRAL_GATE2_SKIP_DEVICES:-0}" != "1" ]]; then
  if [[ "${ONLY_TARGET}" == "all" || "${ONLY_TARGET}" == "iphone-device" ]]; then
    run_xcuitest "iphone-device" "${IPHONE_DEVICE_DEST}"
  fi
  if [[ "${ONLY_TARGET}" == "all" || "${ONLY_TARGET}" == "ipad-device" ]]; then
    run_xcuitest "ipad-device" "${IPAD_DEVICE_DEST}"
  fi
fi

if [[ ! -s "${WEBHOOK_LOG}" ]]; then
  echo "[gate2] Discord webhook sink did not receive a POST" >&2
  exit 1
fi

echo "[gate2] PASS. Fact=${FACT}"
echo "[gate2] Report=${REPORT}"
echo "[gate2] Webhook log=${WEBHOOK_LOG}"
