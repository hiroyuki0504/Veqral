#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "${ROOT}"

VERIFY_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/veqral-forge-verify.XXXXXX")
cleanup() { rm -rf "${VERIFY_ROOT}"; }
trap cleanup EXIT

export VEQRAL_TEST_MODE=1
export VEQRAL_HOST_HOME="${VERIFY_ROOT}/host"
export VEQRAL_TEST_SECRET_STORE_PATH="${VEQRAL_HOST_HOME}/test-secrets.json"
export VEQRAL_DISABLE_DISCORD_WEBHOOK=1
export VEQRAL_PUSH_ENABLED=0
mkdir -p "${VEQRAL_HOST_HOME}"

echo "== isolation =="
python3 Scripts/check_test_isolation.py

echo "== diff =="
git diff --check

echo "== MacHost tests/build =="
swift test --package-path MacHost
swift build --package-path MacHost --product VeqralHost

echo "== isolated Host security smoke =="
python3 Scripts/smoke_host_security.py

echo "== isolated Forge client end-to-end smoke =="
Scripts/smoke_forge_client.sh

if [[ "${VEQRAL_SKIP_XCODEBUILD:-0}" != "1" ]]; then
  echo "== iOS build-for-testing =="
  xcodebuild -quiet \
    -project Veqral.xcodeproj \
    -scheme Veqral \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "${VERIFY_ROOT}/iOS" \
    CODE_SIGNING_ALLOWED=NO \
    build-for-testing

  echo "== Mac Catalyst build =="
  xcodebuild -quiet \
    -project Veqral.xcodeproj \
    -scheme Veqral \
    -destination 'platform=macOS,variant=Mac Catalyst' \
    -derivedDataPath "${VERIFY_ROOT}/Catalyst" \
    CODE_SIGNING_ALLOWED=NO \
    build
else
  echo "SKIP: Xcode builds"
fi

if [[ "${VEQRAL_SKIP_UI_TESTS:-0}" != "1" ]]; then
  VEQRAL_UI_TEST_DERIVED_DATA="${VERIFY_ROOT}/UI" Scripts/run_forge_ui_tests.sh
else
  echo "SKIP: Forge UI tests"
fi

echo "PASS: verify_pr_ready"
