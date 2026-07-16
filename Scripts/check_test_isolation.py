#!/usr/bin/env python3
"""Fail closed if automated Veqral verification can touch the user's login Keychain."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "Scripts"
TARGETS = {
    ROOT / "Scripts/smoke_host_security.py": (
        "VEQRAL_TEST_MODE",
        "VEQRAL_TEST_SECRET_STORE_PATH",
    ),
    ROOT / "Scripts/run_gate2_xcuitests.sh": (
        "VEQRAL_TEST_MODE",
        "VEQRAL_TEST_SECRET_STORE_PATH",
    ),
    ROOT / "Scripts/verify_pr_ready.sh": (
        "VEQRAL_TEST_MODE",
        "VEQRAL_TEST_SECRET_STORE_PATH",
    ),
}
AUTOMATED_VERIFICATION = set(SCRIPTS.glob("smoke_*.py"))
AUTOMATED_VERIFICATION.update(SCRIPTS.glob("run_*test*.sh"))
AUTOMATED_VERIFICATION.update(SCRIPTS.glob("verify_*.sh"))
AUTOMATED_VERIFICATION.update(TARGETS)
INSTALLER = SCRIPTS / "install_veqral_host_launchagent.sh"
FORBIDDEN = (
    "/usr/bin/security",
    "security default-keychain",
    "security list-keychains",
    "security delete-generic-password",
    "security add-generic-password",
    "security unlock-keychain",
    "VEQRAL_KEYCHAIN_SERVICE",
    "VEQRAL_ALLOW_SYSTEM_KEYCHAIN",
)


def main() -> None:
    errors: list[str] = []
    for path in sorted(AUTOMATED_VERIFICATION):
        text = path.read_text(encoding="utf-8")
        for marker in FORBIDDEN:
            if marker in text:
                errors.append(f"{path.relative_to(ROOT)} contains forbidden main-Keychain marker: {marker}")

    for path, required in TARGETS.items():
        text = path.read_text(encoding="utf-8")
        for marker in required:
            if marker not in text:
                errors.append(f"{path.relative_to(ROOT)} is missing isolation marker: {marker}")

    installer_text = INSTALLER.read_text(encoding="utf-8")
    for marker in ("--apply", "Refusing to mutate the real Veqral Host"):
        if marker not in installer_text:
            errors.append(f"{INSTALLER.relative_to(ROOT)} is missing production mutation guard: {marker}")

    if errors:
        raise SystemExit("FAIL: Veqral test isolation guard\n- " + "\n- ".join(errors))
    print("PASS: Veqral automated verification is isolated from the user login Keychain")


if __name__ == "__main__":
    main()
