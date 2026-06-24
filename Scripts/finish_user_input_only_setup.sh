#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "${ROOT}"

DEVICE_ID="${VEQRAL_DEVICE_ID:-}"
CHECK_ONLY=0
NONINTERACTIVE=0
OPEN_XCODE=1
SKIP_LAUNCH=0

usage() {
  cat <<'USAGE'
Finish Veqral physical-device setup with only unavoidable user input.

Usage:
  Scripts/finish_user_input_only_setup.sh [--device <udid-or-name>] [--check-only] [--non-interactive] [--no-open-xcode] [--skip-launch]

What this script automates:
  1. Verifies live VeqralHost health and local runtime wiring.
  2. Detects connected physical iPhone/iPad devices.
  3. Builds the iOS app with automatic Xcode provisioning updates.
  4. Installs the app to the selected physical device.
  5. Launches the app and retries after user-only trust/profile steps.

What the user may still need to input/tap:
  - Apple ID / password / 2FA inside Xcode Settings > Accounts.
  - Device-side trust: Settings > General > VPN & Device Management > trust developer profile.
  - First-run iOS permission dialogs such as Notifications.

No secrets are printed. Build logs stay under the generated DerivedData directory.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --device)
      DEVICE_ID="${2:-}"
      shift 2
      ;;
    --check-only)
      CHECK_ONLY=1
      shift
      ;;
    --non-interactive)
      NONINTERACTIVE=1
      shift
      ;;
    --no-open-xcode)
      OPEN_XCODE=0
      shift
      ;;
    --skip-launch)
      SKIP_LAUNCH=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

step() { printf '\n== %s ==\n' "$*"; }
need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 127
  fi
}

pause_for_user() {
  local message="$1"
  printf '\nUSER INPUT REQUIRED:\n%s\n' "$message"
  if [ "${NONINTERACTIVE}" = "1" ]; then
    echo "Non-interactive mode: stopping here." >&2
    exit 20
  fi
  printf '完了したら Enter を押してください: '
  # shellcheck disable=SC2034
  IFS= read -r _answer
}

need xcrun
need xcodebuild
need python3
need /usr/libexec/PlistBuddy

step "Live VeqralHost health"
python3 - <<'PY'
import json, urllib.request, sys
try:
    with urllib.request.urlopen('http://127.0.0.1:7878/v1/health', timeout=5) as response:
        data = json.load(response)
except Exception as exc:
    print(f'FAIL: live VeqralHost is not reachable on http://127.0.0.1:7878/v1/health: {exc}', file=sys.stderr)
    sys.exit(1)
print('status={status} host={host} port={port}'.format(
    status=data.get('status'), host=data.get('host'), port=data.get('port')
))
if data.get('status') != 'ok':
    print('FAIL: live VeqralHost returned non-ok health', file=sys.stderr)
    sys.exit(1)
PY

step "Xcode signing settings"
xcodebuild -project Veqral.xcodeproj -scheme Veqral -showBuildSettings 2>/dev/null \
  | grep -E 'PRODUCT_BUNDLE_IDENTIFIER|DEVELOPMENT_TEAM|CODE_SIGN_STYLE|PROVISIONING_PROFILE_SPECIFIER' \
  | sort -u || true

step "Connected physical iOS devices"
DEVICE_JSON=$(mktemp /tmp/veqral-devices.XXXXXX)
xcrun devicectl list devices --json-output "${DEVICE_JSON}" >/dev/null
DEVICE_TSV=$(mktemp /tmp/veqral-device-list.XXXXXX)
python3 - "${DEVICE_JSON}" > "${DEVICE_TSV}" <<'PY'
import json, sys
from pathlib import Path
payload = json.loads(Path(sys.argv[1]).read_text())
devices = payload.get('result', {}).get('devices', [])
rows = []
for device in devices:
    hardware = device.get('hardwareProperties', {}) or {}
    props = device.get('deviceProperties', {}) or {}
    conn = device.get('connectionProperties', {}) or {}
    if hardware.get('reality') != 'physical':
        continue
    if hardware.get('platform') not in {'iOS', 'iPadOS'}:
        continue
    if conn.get('pairingState') not in {None, 'paired'}:
        continue
    udid = hardware.get('udid') or device.get('identifier') or ''
    name = props.get('name') or device.get('identifier') or udid
    marketing = hardware.get('marketingName') or hardware.get('productType') or ''
    dtype = hardware.get('deviceType') or ''
    devmode = props.get('developerModeStatus') or ''
    transport = conn.get('transportType') or ''
    rows.append((udid, name, marketing, dtype, devmode, transport))
# Prefer iPhone, then any physical iOS/iPadOS device; keep stable order otherwise.
rows.sort(key=lambda row: (0 if row[3] == 'iPhone' else 1, row[1]))
for row in rows:
    print('\t'.join(str(part) for part in row))
PY

COUNT=$(wc -l < "${DEVICE_TSV}" | tr -d ' ')
if [ "${COUNT}" = "0" ]; then
  echo "No paired physical iOS/iPadOS devices found. Connect and unlock the iPhone/iPad, then rerun this script." >&2
  exit 1
fi

awk -F '\t' '{ printf "  [%d] %s — %s — %s — developerMode=%s — transport=%s — udid=%s\n", NR, $2, $3, $4, $5, $6, $1 }' "${DEVICE_TSV}"

SELECTED_LINE=""
if [ -n "${DEVICE_ID}" ]; then
  SELECTED_LINE=$(awk -F '\t' -v id="${DEVICE_ID}" '$1 == id || $2 == id { print; exit }' "${DEVICE_TSV}")
  if [ -z "${SELECTED_LINE}" ]; then
    echo "Requested device not found: ${DEVICE_ID}" >&2
    exit 1
  fi
elif [ "${COUNT}" = "1" ]; then
  SELECTED_LINE=$(sed -n '1p' "${DEVICE_TSV}")
else
  if [ "${NONINTERACTIVE}" = "1" ]; then
    echo "Multiple devices found. Rerun with --device <udid-or-name> or VEQRAL_DEVICE_ID=..." >&2
    exit 20
  fi
  printf '使うデバイス番号を入力してください: '
  IFS= read -r choice
  case "${choice}" in
    ''|*[!0-9]*) echo "Invalid choice: ${choice}" >&2; exit 2 ;;
  esac
  SELECTED_LINE=$(sed -n "${choice}p" "${DEVICE_TSV}")
  if [ -z "${SELECTED_LINE}" ]; then
    echo "Invalid device number: ${choice}" >&2
    exit 2
  fi
fi

TAB=$(printf '\t')
IFS="${TAB}" read -r DEVICE_ID DEVICE_NAME DEVICE_MARKETING DEVICE_TYPE DEVICE_DEVMODE DEVICE_TRANSPORT <<EOF
${SELECTED_LINE}
EOF
printf 'Selected device: %s (%s) udid=%s\n' "${DEVICE_NAME}" "${DEVICE_MARKETING}" "${DEVICE_ID}"

if [ "${CHECK_ONLY}" = "1" ]; then
  step "Check-only result"
  echo "Ready to run full physical-device setup."
  echo "If Xcode account/profile trust is missing, the full run will pause and tell you exactly what to input/tap."
  exit 0
fi

step "Build iOS app for physical device"
DD=$(mktemp -d /tmp/veqral-device-dd.XXXXXX)
BUILD_LOG="${DD}/xcodebuild-device.log"
echo "DerivedData=${DD}"
echo "Build log=${BUILD_LOG}"

while :; do
  set +e
  xcodebuild \
    -project Veqral.xcodeproj \
    -scheme Veqral \
    -configuration Debug \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "${DD}" \
    -allowProvisioningUpdates \
    build 2>&1 | tee "${BUILD_LOG}"
  BUILD_STATUS=${PIPESTATUS[0]}
  set -e
  if [ "${BUILD_STATUS}" = "0" ]; then
    break
  fi

  if grep -qiE 'No Accounts|No profiles|requires a development team|provisioning profile|Add a new account|Automatic signing' "${BUILD_LOG}"; then
    if [ "${OPEN_XCODE}" = "1" ]; then
      open -a Xcode "${ROOT}/Veqral.xcodeproj" || true
    fi
    pause_for_user "Xcode signing/provisioning が未完了です。Xcode が開いたら、Settings > Accounts で Apple ID を追加/選択し、Team 7XR5GVNQYQ で dev.hiroyuki.veqral の自動署名を許可してください。Apple ID / password / 2FA はあなたが入力してください。"
    echo "Retrying physical-device build..."
    continue
  fi

  echo "xcodebuild failed for a reason that does not look like user-input provisioning. See ${BUILD_LOG}" >&2
  exit "${BUILD_STATUS}"
done

APP_PATH="${DD}/Build/Products/Debug-iphoneos/Veqral.app"
if [ ! -d "${APP_PATH}" ]; then
  echo "Expected app not found: ${APP_PATH}" >&2
  exit 1
fi
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${APP_PATH}/Info.plist")
printf 'Built app: %s\nBundle ID: %s\n' "${APP_PATH}" "${BUNDLE_ID}"

step "Install app to physical device"
INSTALL_JSON=$(mktemp /tmp/veqral-install.XXXXXX)
xcrun devicectl device install app --device "${DEVICE_ID}" "${APP_PATH}" --json-output "${INSTALL_JSON}"
echo "Install result JSON=${INSTALL_JSON}"

if [ "${SKIP_LAUNCH}" = "1" ]; then
  echo "Skipping launch as requested."
  exit 0
fi

step "Launch app on physical device"
LAUNCH_LOG=$(mktemp /tmp/veqral-launch-log.XXXXXX)
LAUNCH_JSON=$(mktemp /tmp/veqral-launch-json.XXXXXX)
while :; do
  set +e
  xcrun devicectl device process launch \
    --device "${DEVICE_ID}" \
    --terminate-existing \
    "${BUNDLE_ID}" \
    --json-output "${LAUNCH_JSON}" 2>&1 | tee "${LAUNCH_LOG}"
  LAUNCH_STATUS=${PIPESTATUS[0]}
  set -e
  if [ "${LAUNCH_STATUS}" = "0" ]; then
    break
  fi

  if grep -qiE 'invalid code signature|not been explicitly trusted|inadequate entitlements|Security|RequestDenied' "${LAUNCH_LOG}"; then
    pause_for_user "iPhone/iPad 側の信頼設定が必要です。端末で 設定 > 一般 > VPNとデバイス管理 を開き、Veqral の開発元 profile を信頼してください。完了後 Enter で launch を再試行します。"
    echo "Retrying physical-device launch..."
    continue
  fi

  echo "Launch failed. See ${LAUNCH_LOG} and ${LAUNCH_JSON}" >&2
  exit "${LAUNCH_STATUS}"
done

echo "Launch result JSON=${LAUNCH_JSON}"

step "First-run user prompt"
pause_for_user "Veqral が端末上で開いたら、通知許可などの iOS permission dialog は必要に応じてあなたがタップしてください。終わったら Enter を押すだけで完了確認します。"

step "Post-launch confirmation"
APPS_JSON=$(mktemp /tmp/veqral-apps.XXXXXX)
xcrun devicectl device info apps --device "${DEVICE_ID}" --include-all-apps --json-output "${APPS_JSON}" >/dev/null
python3 - "${APPS_JSON}" "${BUNDLE_ID}" <<'PY'
import json, sys
from pathlib import Path
payload = json.loads(Path(sys.argv[1]).read_text())
bundle_id = sys.argv[2]
text = json.dumps(payload, ensure_ascii=False)
if bundle_id not in text:
    print(f'WARN: bundle id {bundle_id} was not found in devicectl app listing')
else:
    print(f'PASS: {bundle_id} is installed on the selected device')
PY

python3 - <<'PY'
import json, urllib.request, sys
with urllib.request.urlopen('http://127.0.0.1:7878/v1/health', timeout=5) as response:
    data = json.load(response)
print('PASS: live VeqralHost remains healthy: status={status} port={port}'.format(status=data.get('status'), port=data.get('port')))
PY

echo "DONE: Physical-device setup reached user-input-only completion path."
