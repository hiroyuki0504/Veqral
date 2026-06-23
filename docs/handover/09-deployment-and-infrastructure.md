# Deployment and infrastructure

確認時点: 2026-06-23 15:44:42 JST

## Deployment model

Veqral is currently a local-device product, not a hosted web service. The deployed pieces are:

| Piece | Deployment target | Current status | 根拠 |
|---|---|---|---|
| Mac Host binary | user Mac under `~/.veqral-host/bin/VeqralHost` | installed and running via LaunchAgent | `launchctl print ...`, `ls -l ~/.veqral-host/bin/VeqralHost` |
| LaunchAgent plist | `~/Library/LaunchAgents/dev.hiroyuki.veqral.host.plist` | installed and running | `launchctl print ...` |
| iOS/iPadOS app | local Xcode install / device builds | Simulator build PASS; real-device install not repeated this turn | `xcodebuild` |
| Mac Catalyst app | local Xcode build | build PASS | `xcodebuild` |
| Watch app | local Xcode build/install | Watch Simulator build PASS; real Watch not verified | `xcodebuild` |
| GitHub repo | `github.com/hiroyuki0504/Veqral` | public repo, default branch `main` | `gh repo view` |

## CI/CD

No `.github` directory or workflow file exists in this checkout. No CI/CD pipeline was confirmed.

根拠:
- command: `find . -maxdepth 3 -type f`
- command: `gh repo view ...`

未確認:
- GitHub repository Settings may contain branch protections, Actions settings, environments, or secrets that are not visible from the local checkout. Check GitHub web settings if production policy depends on them.

## Containers / cloud hosting / infra as code

| Item | Status | 根拠 |
|---|---|---|
| Docker | not found in checkout | command: `find . -maxdepth 3 -type f` |
| Docker Compose | not found in checkout | same |
| Kubernetes | not found in checkout | same |
| Terraform/Pulumi | not found in checkout | same |
| Cloud hosting/domain/DNS/SSL | no hosted service confirmed | repo inspection and product architecture |

## Release artifacts

| Artifact | How produced | Current note |
|---|---|---|
| Host debug/release binary | `swift build --package-path MacHost` or release build command | live binary exists under `~/.veqral-host/bin/VeqralHost`; exact release command for latest deploy was not re-run |
| iOS app build | Xcode scheme `Veqral` | signing for real device depends on local Apple account/team |
| Mac Catalyst app | Xcode scheme `Veqral` with Mac Catalyst destination | build confirmed |
| Watch app | Xcode scheme `VeqralWatch` | simulator build confirmed |
| Handoff docs | `docs/handover/` | this PR adds them |

## Host release / restart procedure

Confirmed-safe build step:

```bash
swift build --package-path MacHost -c release
```

The live deployment shape is known, but the exact copy/sign/restart command sequence for the current installed binary was not executed in this handover turn. Before replacing the live Host binary, confirm:

1. Whether an old binary backup exists.
2. Whether ad-hoc signing is required after copying.
3. Whether any running Run should be allowed to finish before restart.

Known restart command, not executed:

```bash
launchctl kickstart -k gui/$(id -u)/dev.hiroyuki.veqral.host
```

根拠:
- `AGENTS.md` says the Host binary was deployed and ad-hoc signed after AI-Hub local runtime cleanup.
- `launchctl print ...` confirms the runtime location.

## Rollback

| Area | Rollback path | Confirmed? | Notes |
|---|---|---|---|
| Git code | `git revert` or branch switch + rebuild | yes, standard Git | do not rewrite main without approval |
| Host config | restore `~/.hermes/config.yaml.veqral-bak` or saved config copy | partly | `HermesControl.swift` creates `.veqral-bak` |
| Host binary | restore previous `~/.veqral-host/bin/VeqralHost` | unconfirmed | no backup path was confirmed in this turn |
| Host state | restore `~/.veqral-host` folder copy plus Keychain tokens | partly | Keychain is separate from files |
| App state | delete/restore Application Support and Keychain | partly | re-pairing may be easier |
| AI-Hub vault | restore vault from its own backup/sync | unconfirmed | external repo/sync policy must be checked |

## Migration

No app-owned database migration system was found. State evolution currently uses:

- JSON files under Host home and App Support.
- Swift `Codable` optional/default properties.
- Read-only Hermes SQLite access for `~/.hermes/state.db`.
- Obsidian vault folder conventions for AI-Hub approvals/sessions/presets.

根拠:
- `MacHost/Sources/VeqralHost/main.swift`
- `Veqral/AppState.swift`
- `MacHost/Sources/VeqralHost/HermesControl.swift`
- command: `rg -n "state.db|migrations|sqlite|\\.json" MacHost/Sources Veqral`

## Pre-release checklist

1. Rebase or branch from `origin/main`.
2. Run `swift build --package-path MacHost`.
3. Run `swift test --package-path MacHost`.
4. Run affected Host smokes.
5. Build iOS Simulator and Mac Catalyst.
6. Build Watch if Watch code/project changed.
7. Run `git diff --check`.
8. Run secret/redaction grep and production marker grep.
9. Run Gate2 XCUITest for pairing/run/memory-impacting changes.
10. Run `DEVICE_ACCEPTANCE.md` real-device checks for user-facing/device changes.
11. Update `AGENTS.md` and relevant PR/handover docs.

## Post-release checks

After replacing live Host:

1. Confirm LaunchAgent:

```bash
launchctl print gui/$(id -u)/dev.hiroyuki.veqral.host
```

2. Confirm health:

```bash
curl -fsS http://127.0.0.1:7878/v1/health
```

3. Confirm app pairing from at least one real device.
4. Confirm one low-risk Run completes.
5. Confirm approval gate with one high-risk test command if approval code changed.
6. Confirm Hermes control if config/policy code changed.
7. Confirm AI-Hub session digest if Run completion changed.
8. Check Host logs for new stderr.

## Access limitations

| Area | Status | Required confirmation |
|---|---|---|
| GitHub branch protection / repo secrets | not accessible from local files | GitHub Settings |
| Apple Developer account/team/certificates | not inspected | Xcode account settings / Apple Developer portal |
| APNs `.p8` and Team/Key IDs | not inspected and must not be recorded here | Apple Developer portal / Keychain/env owner |
| Tailscale admin policy | not inspected | Tailscale admin console |
| AI-Hub vault backup policy | not inspected | AI-Hub repo/vault owner |
