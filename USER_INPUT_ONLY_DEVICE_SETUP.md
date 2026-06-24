# Veqral: user-input-only physical device finish

This repo is already live on the Mac Host and verified on Simulator. The only remaining non-automatable items are Apple/Xcode account credentials, device trust, and iOS permission dialogs.

## One command

From the integration worktree:

```bash
cd /Users/hiroyuki/Documents/Veqral/.worktrees/kanban-usable/integration
Scripts/finish_user_input_only_setup.sh
```

If multiple physical devices are connected, the script shows a numbered list and asks which device number to use. You can also skip that prompt:

```bash
VEQRAL_DEVICE_ID=00008140-001611892606801C Scripts/finish_user_input_only_setup.sh
```

## What the script does automatically

1. Checks live `VeqralHost` on `http://127.0.0.1:7878/v1/health`.
2. Detects paired physical iPhone/iPad devices via `xcrun devicectl`.
3. Builds `Veqral.app` for a physical iOS device using Xcode automatic provisioning.
4. Installs the `.app` on the selected device.
5. Launches `dev.hiroyuki.veqral` on the selected device.
6. Confirms the app is installed and the live Mac Host is still healthy.

## What the user may still need to input/tap

The script pauses only for these items:

- **Xcode account/signing:** if Xcode says no Apple account or provisioning profile exists, the script opens Xcode and waits. Add/sign in to the Apple ID in Xcode Settings > Accounts, then press Enter in the terminal.
- **iPhone/iPad developer trust:** if the device rejects launch because the developer profile is not trusted, open Settings > General > VPN & Device Management on the device, trust the developer profile, then press Enter.
- **iOS permissions:** if Veqral asks for notifications or another system permission, tap the desired choice on the device, then press Enter.

No Apple ID password, 2FA code, or device passcode is printed or stored by the script.

## Check-only mode

To verify the Mac Host and connected device detection without building/installing:

```bash
Scripts/finish_user_input_only_setup.sh --check-only
```

## Current known device

Previously detected:

```text
iPhone16 Ultra Pro Max
UDID: 00008140-001611892606801C
bundle already installed: dev.hiroyuki.veqral version 1.0
```

## Already completed before this step

- Live Mac Host installed and restarted from integration branch.
- LaunchAgent env includes `VEQRAL_HERMES_CONFIG`, `VEQRAL_HERMES_VAULT`, and `VEQRAL_AIHUB_ROOT`.
- local LLM smoke passed via Ollama `qwen3:8b` with thinking disabled for smoke.
- Obsidian/Hermes endpoints passed.
- Codex and Claude history signed API paths passed.
- iPhone 17 Simulator build/install/launch passed and displayed the Veqral Japanese command UI.
