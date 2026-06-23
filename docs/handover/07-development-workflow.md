# Development workflow

確認時点: 2026-06-23 15:44:42 JST

## Required tools

| Tool | Required for | Confirmed version/state | 根拠 |
|---|---|---|---|
| macOS | Xcode, LaunchAgent, iOS/watchOS build | current machine used for all checks | command outputs |
| Xcode | iOS/Mac Catalyst/Watch builds | Xcode 26.5, build 17F42 | command: `xcodebuild -version` |
| Swift | MacHost build/test | Apple Swift 6.3.2 | command: `swift --version` |
| Git | branch/PR workflow | repo on branch `codex/handover-package-20260623` | command: `git status --short --branch` |
| GitHub CLI | GitHub repo/PR/issue inspection | `gh repo view`, `gh pr list`, `gh issue list` worked | command outputs |
| XcodeBuildMCP | simulator inventory | schemes/sims listed; direct build tool lacked defaults | MCP tool output |
| Hermes CLI | Hermes runtime/smoke | live Host reports Hermes v0.17.0 | `/v1/health` |
| Codex CLI | direct Codex runtime | live Host reports `codex-cli 0.130.0` | `/v1/health` |
| Claude Code CLI | direct Claude runtime | live Host reports `2.1.170` | `/v1/health` |
| Ollama | local AI-Hub policy lanes | process observed; model resolution not re-run in this turn | command: `ps` |

## Setup

Minimum checkout setup:

```bash
cd /Users/hiroyuki/Documents/Veqral
git fetch origin
git switch -c codex/<task-name> origin/main
```

Do not base new work on the local `main` if it is behind `origin/main`.

根拠:
- local `main` was observed behind `origin/main` by 7 commits before this branch was created.
- current handover branch was created from `origin/main`.

## Build

Mac Host:

```bash
swift build --package-path MacHost
```

iOS Simulator:

```bash
xcodebuild -project Veqral.xcodeproj -scheme Veqral -configuration Debug -destination 'platform=iOS Simulator,id=<available-ios-simulator-id>' CODE_SIGNING_ALLOWED=NO build
```

Mac Catalyst:

```bash
xcodebuild -project Veqral.xcodeproj -scheme Veqral -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build
```

Watch Simulator:

```bash
xcodebuild -project Veqral.xcodeproj -scheme VeqralWatch -configuration Debug -destination 'platform=watchOS Simulator,id=<available-watch-simulator-id>' CODE_SIGNING_ALLOWED=NO build
```

直近確認:
- MacHost build PASS
- iOS Simulator build PASS
- Mac Catalyst build PASS
- Watch Simulator build PASS

## Test

Mac Host unit tests:

```bash
swift test --package-path MacHost
```

Host smoke example:

```bash
swift run --package-path MacHost VeqralHost smoke-host-telemetry
```

Gate2 XCUITest script:

```bash
VEQRAL_GATE2_SKIP_DEVICES=1 VEQRAL_GATE2_ONLY=iphone-simulator Scripts/run_gate2_xcuitests.sh
```

Gate2 script status: not run in this handover turn because it can involve real Hermes memory inheritance, LLM auth/cost/time, and device targets. See `08-testing-and-verification.md`.

## Lint / format / static checks

There is no dedicated SwiftLint or formatter config in the checkout. The confirmed checks are:

```bash
git diff --check
plutil -lint Veqral/Info.plist Veqral/Veqral.entitlements Veqral/en.lproj/Localizable.strings Veqral/ja.lproj/Localizable.strings
```

Production marker grep:

```bash
rg -n "TODO|FIXME|HACK|XXX|not implemented|unimplemented|mock|stub|fake|demo" Veqral MacHost/Sources VeqralWatch VeqralUITests
```

直近結果: `mock` appears as Sales Lab domain wording only. No `TODO/FIXME/HACK` markers were found in production Swift source.

## Branch and PR policy

| Rule | Current policy | 根拠 |
|---|---|---|
| New work branch | create from clean `origin/main` | `AGENTS.md` |
| Main direct commit | prohibited without explicit user approval | `AGENTS.md` |
| Draft PR | default after scoped work | `AGENTS.md` |
| Feature scope | keep within requested Veqral scope | `AGENTS.md` |
| Unrelated changes | do not revert or include | developer instructions and current untracked files |
| High severity actions | require explicit user approval | `AGENTS.md` |

## Change checklist

Before a PR:

1. Confirm branch and diff:

```bash
git status --short --branch
git diff --stat
```

2. Run scoped verification:

```bash
swift build --package-path MacHost
swift test --package-path MacHost
git diff --check
```

3. For app/Host behavior changes, add or rerun relevant smoke(s).

4. For UI changes, build iOS Simulator and Mac Catalyst. For Watch changes, build `VeqralWatch`.

5. For user-facing text, check both:

```bash
plutil -lint Veqral/en.lproj/Localizable.strings Veqral/ja.lproj/Localizable.strings
```

6. For large handoff/state changes, update:

- `AGENTS.md`
- relevant PR doc such as `*_PR*.md`
- `docs/handover/` if the handover package is affected

## Files commonly changed by feature area

| Feature area | Primary files | Also update |
|---|---|---|
| Host API / Run behavior | `MacHost/Sources/VeqralHost/main.swift` | smoke command, docs, redaction tests if secrets/logs touched |
| Hermes control | `MacHost/Sources/VeqralHost/HermesControl.swift` | `HERMES_REMOTE_CONTROL_PR.md`, AI-Hub docs, smoke-hermes-control |
| App state / API client | `Veqral/AppState.swift` | UI screens and snapshot persistence |
| Main UI screens | `Veqral/Screens.swift`, `Veqral/CommandCenterViews.swift`, `Veqral/Components.swift` | localizations, UI tests |
| Watch | `VeqralWatch/VeqralWatchApp.swift`, Xcode project | Watch build, Watch handoff doc |
| Gate2 | `Scripts/run_gate2_xcuitests.sh`, `VeqralUITests/Gate2AcceptanceUITests.swift` | `DEVICE_ACCEPTANCE.md` |
| Shared redaction/models | `MacHost/Sources/VeqralShared/*` | `MacHost/Tests/VeqralSharedTests/*` |
| Handoff docs | `docs/handover/*`, `AGENTS.md` | no feature code |

## Do not do by default

- Do not create custom shared memory or MCP for Veqral memory.
- Do not edit/delete `~/.codex` or `~/.claude`.
- Do not fake cross-vendor memory PASS with API-key fallback.
- Do not enable APNs push without paid Apple Developer setup and explicit approval.
- Do not add automated outbound Sales Lab sending.
- Do not deploy, merge to main, or force-push without explicit approval.

根拠:
- `AGENTS.md`
- `HERMES_CROSS_VENDOR_PR_A7.md`
- `SALES_LAB_PR.md`
- `Veqral/AppState.swift`
- `MacHost/Sources/VeqralHost/main.swift`
