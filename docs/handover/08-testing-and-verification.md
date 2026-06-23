# Testing and verification

確認時点: 2026-06-23 15:44:42 JST

## Test layers

| Layer | Location / command | Protects | Latest result |
|---|---|---|---|
| SwiftPM build | `swift build --package-path MacHost` | Host and shared Swift compileability | PASS |
| SwiftPM tests | `swift test --package-path MacHost` | `VeqralRedactor` secret redaction behavior | PASS, 2 tests |
| Host smoke commands | `swift run --package-path MacHost VeqralHost smoke-*` | Host behavior slices without full app UI | 17 commands PASS |
| iOS Simulator build | `xcodebuild -project Veqral.xcodeproj -scheme Veqral ... iOS Simulator ... build` | iOS app compileability | PASS |
| Mac Catalyst build | `xcodebuild -project Veqral.xcodeproj -scheme Veqral ... Mac Catalyst ... build` | Catalyst compileability | PASS |
| Watch Simulator build | `xcodebuild -project Veqral.xcodeproj -scheme VeqralWatch ... watchOS Simulator ... build` | Watch target compileability | PASS |
| Gate2 XCUITest | `Scripts/run_gate2_xcuitests.sh` | device/simulator acceptance and pairing/run flows | Not run this turn |
| Manual device acceptance | `DEVICE_ACCEPTANCE.md` | real iPhone/iPad voice/telemetry/Discord/Memory/saved commands | Not run this turn |
| Live health | `curl -fsS http://127.0.0.1:7878/v1/health` | running LaunchAgent and tool discovery | PASS |
| Static hygiene | `git diff --check`, `plutil -lint`, grep | whitespace, plist/localization, secrets/production markers | PASS with known Sales Lab wording |

## Host smoke commands and coverage

| Smoke command | Coverage |
|---|---|
| `smoke-discord-notifications` | Discord notification payloads, redaction, status/approval/failure/down event shapes |
| `smoke-project-memory` | Hermes project source mapping and read-only memory/session surface |
| `smoke-run-usage` | Claude stream JSON, Codex usage JSON, plain usage text parsing |
| `smoke-aihub-digest-bridge` | `HostState.finish()` to AI-Hub session digest bridge for non-shell runs |
| `smoke-host-telemetry` | CPU/load/memory/disk/thermal/process telemetry collection |
| `smoke-voice-cleanup` | dictation cleanup prompt and fallback sanitizing |
| `smoke-cost-governance` | token/cost budget threshold and pause behavior |
| `smoke-portfolio-real-data` | isolated sample Portfolio behavior when real roots/registry are unset |
| `smoke-auth-onboarding` | provider readiness marker and secret hygiene surface |
| `smoke-hermes-control` | Hermes config/preset/policy apply, base URL, context length handling |
| `smoke-sales-lead-repository` | Sales lead JSON repository |
| `smoke-sales-import-csv` | Sales Lab CSV import |
| `smoke-sales-audit` | official URL audit artifact generation |
| `smoke-sales-mock` | Sales Lab redesign mock artifact generation |
| `smoke-sales-proposal` | proposal artifact generation |
| `smoke-sales-no-autosend` | no automatic outbound sending |
| `smoke-sales-redact` | Sales Lab redaction |

Latest result: all PASS on 2026-06-23.

根拠:
- command outputs from smoke run
- `MacHost/Sources/VeqralHost/main.swift`

## Unit tests

SwiftPM currently exposes one confirmed test target:

| Test target | Location | What it protects | Latest result |
|---|---|---|---|
| `VeqralSharedTests` | `MacHost/Tests/VeqralSharedTests/VeqralRedactorTests.swift` | redaction of bearer tokens, API-looking tokens, webhook URLs, provider tokens in logs/payloads | PASS, 2 tests |

No app unit test target was confirmed in `xcodebuild -list`; app acceptance coverage is currently via XCUITest and manual/device checks.

## E2E / acceptance

`Scripts/run_gate2_xcuitests.sh` provisions an isolated Host home, pairs the UI via env-injected pairing URL, and runs the `VeqralUITests` target.

Important env knobs:

| Env | Purpose |
|---|---|
| `VEQRAL_GATE2_HOST_PORT` | isolated Host port |
| `VEQRAL_GATE2_WEBHOOK_PORT` | local webhook receiver |
| `VEQRAL_GATE2_PROJECT_ID` | Hermes project ID |
| `VEQRAL_GATE2_ONLY` | `iphone-simulator`, `ipad-simulator`, or all |
| `VEQRAL_GATE2_SKIP_DEVICES` | skip physical devices |
| `VEQRAL_GATE2_*_DEST` | Xcode destination overrides |
| `VEQRAL_MEMTEST_*` | Hermes memory inheritance smoke settings |

This script was not run in this handover turn. Reason: it can trigger real Hermes memory inheritance and device flows, and the task was documentation-focused. The script should be re-run before merging behavior changes that affect pairing, Memory, device acceptance, Run lifecycle, or UI acceptance.

根拠:
- `Scripts/run_gate2_xcuitests.sh`
- `VeqralUITests/Gate2AcceptanceUITests.swift`

## Manual verification checklist

Primary real-device checklist lives in `DEVICE_ACCEPTANCE.md`. Current unresolved device checks:

| Check | iPhone | iPad | Watch |
|---|---|---|---|
| QR pairing | previously reported connected; not rechecked this turn | not rechecked | not applicable |
| Voice input | not rechecked | not rechecked | not applicable |
| Host telemetry | not rechecked | not rechecked | not applicable |
| Saved command draft | not rechecked | not rechecked | not applicable |
| Discord real webhook | not rechecked | not rechecked | not applicable |
| Hermes memory visibility | not rechecked | not rechecked | not applicable |
| Watch preset/approval | not applicable | not applicable | not rechecked |

Do not mark any of these as verified until the real device screen flow has been observed.

## Minimum verification command set

For docs-only changes:

```bash
git diff --check
rg -n "TODO|FIXME|HACK|XXX|not implemented|unimplemented|stub|fake|demo" docs/handover AGENTS.md
```

For Host/API changes:

```bash
swift build --package-path MacHost
swift test --package-path MacHost
swift run --package-path MacHost VeqralHost smoke-<affected-area>
git diff --check
```

For UI changes:

```bash
xcodebuild -project Veqral.xcodeproj -scheme Veqral -configuration Debug -destination 'platform=iOS Simulator,id=<available-ios-sim>' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Veqral.xcodeproj -scheme Veqral -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build
```

For Watch changes:

```bash
xcodebuild -project Veqral.xcodeproj -scheme VeqralWatch -configuration Debug -destination 'platform=watchOS Simulator,id=<available-watch-sim>' CODE_SIGNING_ALLOWED=NO build
```

For release-candidate behavior changes:

```bash
Scripts/run_gate2_xcuitests.sh
```

Run the device sections of `DEVICE_ACCEPTANCE.md` manually after the automated checks.

## Full verification run used for this handover

| Command | Result | Notes |
|---|---|---|
| `swift --version` | PASS | Apple Swift 6.3.2 |
| `xcodebuild -version` | PASS | Xcode 26.5 |
| `xcodebuild -project Veqral.xcodeproj -list` | PASS | schemes `Veqral`, `VeqralWatch` |
| `swift build --package-path MacHost` | PASS | Host build |
| `swift test --package-path MacHost` | PASS | 2 Redactor tests |
| 17 Host smoke commands | PASS | listed above |
| iOS Simulator build | PASS | AppIntents metadata extraction warning only |
| Mac Catalyst build | PASS | multiple destination warning only |
| Watch Simulator build | PASS | AppIntents metadata extraction warning only |
| `curl -fsS http://127.0.0.1:7878/v1/health` | PASS | live Host ok |
| `launchctl print gui/$(id -u)/dev.hiroyuki.veqral.host` | PASS | running LaunchAgent |
| `plutil -lint ...` | PASS | plist/localization valid |
| localization key parity command | PASS | no diff output |
| `git diff --check` | PASS | before docs completion |
| secret grep | PASS with known dummy hits | no real secret value recorded |
| production grep | PASS with Sales Lab wording only | no source TODO/FIXME markers |

## Untested or weakly covered important behavior

| Behavior | Why important | Current gap | Next verification |
|---|---|---|---|
| real iPhone/iPad voice input | user-facing command flow | Simulator build only | `DEVICE_ACCEPTANCE.md` voice section |
| real external Discord webhook | notification delivery | only local smoke payloads | set webhook and trigger test |
| cross-vendor Hermes memory | core differentiation under provider swap | Claude/Anthropic login was previously blocked | rerun `HERMES_CROSS_VENDOR_PR_A7.md` after login restored |
| Watch on real device/cellular | approval from Watch | only simulator build | real Watch test |
| APNs | push notifications | feature disabled/free team | paid Developer setup and APNs env |
| Portfolio real roots | command center value on real projects | sample fixture smoke only | set roots/registry and run discover/control |
| Sales Lab browser screenshot quality | proposal quality | current artifacts are generated without real browser screenshot proof | separate UI/asset quality PR |
