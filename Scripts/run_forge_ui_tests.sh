#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
DESTINATION=${VEQRAL_UI_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=latest}
DERIVED_DATA=${VEQRAL_UI_TEST_DERIVED_DATA:-${TMPDIR:-/tmp}/Veqral-Forge-UI}

cd "${ROOT}"
xcodebuild \
  -project Veqral.xcodeproj \
  -scheme Veqral \
  -destination "${DESTINATION}" \
  -derivedDataPath "${DERIVED_DATA}" \
  CODE_SIGNING_ALLOWED=NO \
  test \
  -only-testing:VeqralUITests/ForgeShellUITests
