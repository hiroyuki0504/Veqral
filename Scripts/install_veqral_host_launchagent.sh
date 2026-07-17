#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Install the Veqral Mac Host binary and LaunchAgent plist locally.

Usage:
  Scripts/install_veqral_host_launchagent.sh --apply [--restart] [--skip-build]

The installer refuses to touch the real user environment unless --apply is
provided after explicit approval. Pass --restart only after a separate explicit
approval to restart the running LaunchAgent. Credential migration is never automated.

Environment overrides:
  VEQRAL_HOST_INSTALL_DIR   Default: ~/.veqral-host/bin
  VEQRAL_HERMES_CONFIG      Default: ~/.hermes/config.yaml
  VEQRAL_HERMES_VAULT       Default: ~/Library/Application Support/AI-Hub/vault
  VEQRAL_AIHUB_ROOT         Default: ~/Documents/AI-Hub/hermes-hub
  VEQRAL_KEYCHAIN_SERVICE   Default: dev.hiroyuki.veqral.host.tokens.v2
  VEQRAL_HOST_CODESIGN_IDENTITY
                            Default: first available Apple Development identity
USAGE
}

RESTART=0
SKIP_BUILD=0
APPLY=0
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --restart) RESTART=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "${APPLY}" -ne 1 ]]; then
  echo "Refusing to mutate the real Veqral Host, LaunchAgent, or login Keychain without --apply." >&2
  echo "Use Scripts/verify_pr_ready.sh for isolated verification." >&2
  exit 2
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
PACKAGE_DIR="${ROOT}/MacHost"
PRODUCT="${PACKAGE_DIR}/.build/release/VeqralHost"
INSTALL_DIR="${VEQRAL_HOST_INSTALL_DIR:-${HOME}/.veqral-host/bin}"
BINARY="${INSTALL_DIR}/VeqralHost"
BACKUP_DIR="${INSTALL_DIR}/backups"
LABEL="dev.hiroyuki.veqral.host"
KEYCHAIN_SERVICE="${VEQRAL_KEYCHAIN_SERVICE:-${LABEL}.tokens.v2}"
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
SIGNING_IDENTITY="${VEQRAL_HOST_CODESIGN_IDENTITY:-}"
if [[ -z "${SIGNING_IDENTITY}" ]]; then
  SIGNING_IDENTITY=$(/usr/bin/security find-identity -v -p codesigning 2>/dev/null \
    | /usr/bin/sed -nE 's/^[[:space:]]*[0-9]+\)[[:space:]]+([0-9A-F]{40})[[:space:]]+"Apple Development:.*$/\1/p' \
    | /usr/bin/head -n 1)
fi
if [[ -z "${SIGNING_IDENTITY}" ]]; then
  if [[ "${VEQRAL_ALLOW_ADHOC_HOST_SIGNING:-0}" != "1" ]]; then
    echo "No Apple Development signing identity is available. Refusing an ad-hoc Host update because it would invalidate existing Keychain ACLs." >&2
    echo "Set VEQRAL_ALLOW_ADHOC_HOST_SIGNING=1 only for an isolated Host with no persistent device tokens." >&2
    rm -f "${BINARY}.new"
    exit 1
  fi
  SIGNING_IDENTITY="-"
fi
codesign --force --sign "${SIGNING_IDENTITY}" --identifier "${LABEL}" "${BINARY}.new"
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
KEYCHAIN_SERVICE_VALUE="${KEYCHAIN_SERVICE}" \
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
        "VEQRAL_KEYCHAIN_SERVICE": os.environ["KEYCHAIN_SERVICE_VALUE"],
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
echo "LaunchAgent env: VEQRAL_KEYCHAIN_SERVICE=${KEYCHAIN_SERVICE}"

if [[ "${RESTART}" -eq 1 ]]; then
  UID_VALUE=$(id -u)
  launchctl bootout "gui/${UID_VALUE}" "${PLIST}" >/dev/null 2>&1 || true

  echo "Keychain token migration is intentionally not automated. Re-pair devices if the Host signing identity or Keychain ACL changes."

  launchctl bootstrap "gui/${UID_VALUE}" "${PLIST}"
  launchctl kickstart -k "gui/${UID_VALUE}/${LABEL}"
  echo "Restarted LaunchAgent: ${LABEL}"
else
  echo "Not restarted. After separate approval, run: $0 --apply --skip-build --restart"
fi
