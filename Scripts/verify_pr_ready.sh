#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "${ROOT}"

echo "== git diff --check =="
git diff --check

echo "== MacHost swift test =="
(
  cd MacHost
  swift test
)

echo "== Host smokes =="
swift run --package-path MacHost VeqralHost smoke-project-memory
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
