#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "${ROOT}"

VERIFY_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/veqral-pr-verify.XXXXXX")
cleanup() {
  rm -rf "${VERIFY_ROOT}"
}
trap cleanup EXIT

export VEQRAL_TEST_MODE=1
export VEQRAL_HOST_HOME="${VERIFY_ROOT}/host"
export VEQRAL_TEST_SECRET_STORE_PATH="${VEQRAL_HOST_HOME}/test-secrets.json"
export VEQRAL_DISABLE_DISCORD_WEBHOOK=1
export VEQRAL_PUSH_ENABLED=0
mkdir -p "${VEQRAL_HOST_HOME}"

echo "== test isolation guard =="
python3 Scripts/check_test_isolation.py

echo "== git diff --check =="
git diff --check

echo "== MacHost swift test =="
(
  cd MacHost
  swift test
)

echo "== Host security smoke =="
python3 Scripts/smoke_host_security.py

echo "== Host smokes =="
swift run --package-path MacHost VeqralHost smoke-project-memory
swift run --package-path MacHost VeqralHost smoke-hermes-history
swift run --package-path MacHost VeqralHost smoke-hermes-control
swift run --package-path MacHost VeqralHost smoke-aihub-digest-bridge
swift run --package-path MacHost VeqralHost smoke-run-usage

if [[ "${VEQRAL_SKIP_LOCAL_LLM_SMOKE:-0}" != "1" ]]; then
  swift run --package-path MacHost VeqralHost smoke-local-llm
else
  echo "SKIP: smoke-local-llm (VEQRAL_SKIP_LOCAL_LLM_SMOKE=1)"
fi

if [[ "${VEQRAL_SKIP_XCODEBUILD:-0}" != "1" ]]; then
  echo "== Xcode build =="
  xcodebuild -project Veqral.xcodeproj -scheme Veqral \
    -destination 'platform=iOS Simulator,name=iPhone 17' build
else
  echo "SKIP: xcodebuild (VEQRAL_SKIP_XCODEBUILD=1)"
fi

echo "PASS: verify_pr_ready"
