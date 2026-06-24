#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
APP_DIR="${VEQRAL_LAUNCHER_APP:-$HOME/Applications/Veqral.app}"
APP_PARENT=$(dirname -- "${APP_DIR}")
ICON_SRC="${ROOT}/Veqral/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
SCRIPT_SRC=$(mktemp /tmp/veqral-launcher-script.XXXXXX)
ICON_BASE=$(mktemp -d /tmp/veqral-launcher-icon.XXXXXX)
ICONSET="${ICON_BASE}/Veqral.iconset"
mkdir -p "${ICONSET}"

cat > "${SCRIPT_SRC}" <<'APPLESCRIPT'
on run
	set hostStatus to "unknown"
	try
		set hostStatus to do shell script "/usr/bin/python3 - <<'PY'\nimport json, urllib.request\ntry:\n    with urllib.request.urlopen('http://127.0.0.1:7878/v1/health', timeout=3) as r:\n        data=json.load(r)\n    print('OK / port ' + str(data.get('port')) + ' / ' + str(data.get('host')))\nexcept Exception as e:\n    print('DOWN: ' + str(e))\nPY"
	on error errText
		set hostStatus to "DOWN: " & errText
	end try
	set msg to "Veqral\n\nMac Host: " & hostStatus & "\n\n通常はこのまま閉じてOKです。プロジェクトを開く場合だけ Project を押してください。"
	set choice to button returned of (display dialog msg buttons {"Project", "OK"} default button "OK" with title "Veqral")
	if choice is "Project" then
		tell application "Finder" to open POSIX file "__VEQRAL_PROJECT_ROOT__"
	end if
end run
APPLESCRIPT

mkdir -p "${APP_PARENT}"
/usr/bin/python3 - "${SCRIPT_SRC}" "${ROOT}" <<'PY'
from pathlib import Path
import sys

script = Path(sys.argv[1])
root = sys.argv[2].replace('\\', '\\\\').replace('"', '\\"')
script.write_text(script.read_text().replace('__VEQRAL_PROJECT_ROOT__', root))
PY

/usr/bin/osacompile -o "${APP_DIR}" "${SCRIPT_SRC}"

# Match the user-facing Mac launcher icon to the dark Veqral icon used for iPhone/iPad.
sips -z 16 16 "${ICON_SRC}" --out "${ICONSET}/icon_16x16.png" >/dev/null
sips -z 32 32 "${ICON_SRC}" --out "${ICONSET}/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "${ICON_SRC}" --out "${ICONSET}/icon_32x32.png" >/dev/null
sips -z 64 64 "${ICON_SRC}" --out "${ICONSET}/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "${ICON_SRC}" --out "${ICONSET}/icon_128x128.png" >/dev/null
sips -z 256 256 "${ICON_SRC}" --out "${ICONSET}/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "${ICON_SRC}" --out "${ICONSET}/icon_256x256.png" >/dev/null
sips -z 512 512 "${ICON_SRC}" --out "${ICONSET}/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "${ICON_SRC}" --out "${ICONSET}/icon_512x512.png" >/dev/null
cp "${ICON_SRC}" "${ICONSET}/icon_512x512@2x.png"
iconutil -c icns "${ICONSET}" -o /tmp/Veqral.icns
cp /tmp/Veqral.icns "${APP_DIR}/Contents/Resources/applet.icns"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile applet' "${APP_DIR}/Contents/Info.plist" 2>/dev/null || true

# Register for Spotlight/LaunchServices as the single user-facing app entry.
touch "${APP_DIR}"
LSREG='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
if [ -x "${LSREG}" ]; then
  "${LSREG}" -f "${APP_DIR}"
fi
mdimport "${APP_DIR}" 2>/dev/null || true

echo "Installed Veqral launcher: ${APP_DIR}"
osadecompile "${APP_DIR}" | grep -nE 'Device Setup|USER_INPUT|Project|通常|Mac Host' || true
