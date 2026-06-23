#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Install the Veqral Mac Host binary and LaunchAgent plist locally.

Usage:
  Scripts/install_veqral_host_launchagent.sh [--restart] [--skip-build]

Default behavior builds and installs the binary/plist but does not restart the
running LaunchAgent. Pass --restart only after explicit approval.

Environment overrides:
  VEQRAL_HOST_INSTALL_DIR   Default: ~/.veqral-host/bin
  VEQRAL_HERMES_CONFIG      Default: ~/.hermes/config.yaml
  VEQRAL_HERMES_VAULT       Default: ~/Library/Application Support/AI-Hub/vault
  VEQRAL_AIHUB_ROOT         Default: ~/Documents/AI-Hub/hermes-hub
USAGE
}

RESTART=0
SKIP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --restart) RESTART=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
PACKAGE_DIR="${ROOT}/MacHost"
PRODUCT="${PACKAGE_DIR}/.build/release/VeqralHost"
INSTALL_DIR="${VEQRAL_HOST_INSTALL_DIR:-${HOME}/.veqral-host/bin}"
BINARY="${INSTALL_DIR}/VeqralHost"
BACKUP_DIR="${INSTALL_DIR}/backups"
LABEL="dev.hiroyuki.veqral.host"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
HERMES_CONFIG="${VEQRAL_HERMES_CONFIG:-${HOME}/.hermes/config.yaml}"
HERMES_VAULT="${VEQRAL_HERMES_VAULT:-${HOME}/Library/Application Support/AI-Hub/vault}"
AIHUB_ROOT="${VEQRAL_AIHUB_ROOT:-${HOME}/Documents/AI-Hub/hermes-hub}"
PATH_VALUE="${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  swift build --package-path "${PACKAGE_DIR}" -c release --product VeqralHost
fi

if [[ ! -x "${PRODUCT}" ]]; then
  echo "Built product not found or not executable: ${PRODUCT}" >&2
  exit 1
fi

mkdir -p "${INSTALL_DIR}" "${BACKUP_DIR}" "$(dirname -- "${PLIST}")"
if [[ -e "${BINARY}" ]]; then
  stamp=$(date +%Y%m%d-%H%M%S)
  cp -p "${BINARY}" "${BACKUP_DIR}/VeqralHost.${stamp}"
  echo "Backup: ${BACKUP_DIR}/VeqralHost.${stamp}"
fi

cp "${PRODUCT}" "${BINARY}.new"
if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "${BINARY}.new" >/dev/null 2>&1 || true
fi
mv "${BINARY}.new" "${BINARY}"
chmod 755 "${BINARY}"

PLIST_PATH="${PLIST}" \
LABEL_VALUE="${LABEL}" \
BINARY_PATH="${BINARY}" \
HOME_VALUE="${HOME}" \
PATH_VALUE_FOR_PLIST="${PATH_VALUE}" \
HERMES_CONFIG_VALUE="${HERMES_CONFIG}" \
HERMES_VAULT_VALUE="${HERMES_VAULT}" \
AIHUB_ROOT_VALUE="${AIHUB_ROOT}" \
/usr/bin/python3 - <<'PY'
import os
import plistlib
from pathlib import Path
plist = Path(os.environ["PLIST_PATH"])
data = {
    "Label": os.environ["LABEL_VALUE"],
    "ProgramArguments": [os.environ["BINARY_PATH"]],
    "RunAtLoad": True,
    "KeepAlive": True,
    "EnvironmentVariables": {
        "HOME": os.environ["HOME_VALUE"],
        "LANG": "en_US.UTF-8",
        "PATH": os.environ["PATH_VALUE_FOR_PLIST"],
        "VEQRAL_HERMES_CONFIG": os.environ["HERMES_CONFIG_VALUE"],
        "VEQRAL_HERMES_VAULT": os.environ["HERMES_VAULT_VALUE"],
        "VEQRAL_AIHUB_ROOT": os.environ["AIHUB_ROOT_VALUE"],
    },
    "StandardOutPath": str(Path.home() / "Library/Logs/VeqralHost.out.log"),
    "StandardErrorPath": str(Path.home() / "Library/Logs/VeqralHost.err.log"),
}
plist.write_bytes(plistlib.dumps(data, sort_keys=False))
PY

plutil -lint "${PLIST}"
echo "Installed binary: ${BINARY}"
echo "Installed plist:  ${PLIST}"
echo "LaunchAgent env: VEQRAL_HERMES_CONFIG=${HERMES_CONFIG}"
echo "LaunchAgent env: VEQRAL_HERMES_VAULT=${HERMES_VAULT}"
echo "LaunchAgent env: VEQRAL_AIHUB_ROOT=${AIHUB_ROOT}"

if [[ "${RESTART}" -eq 1 ]]; then
  UID_VALUE=$(id -u)
  launchctl bootout "gui/${UID_VALUE}" "${PLIST}" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/${UID_VALUE}" "${PLIST}"
  launchctl kickstart -k "gui/${UID_VALUE}/${LABEL}"
  echo "Restarted LaunchAgent: ${LABEL}"
else
  echo "Not restarted. After approval, run: $0 --skip-build --restart"
fi
