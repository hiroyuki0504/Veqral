# Portfolio Real Data PR A4

## Scope

- Added `VeqralHost smoke-portfolio-real-data` to exercise the Portfolio path end to end without mutating the live registry when the real portfolio roots are not configured.
- The smoke creates an isolated sample Swift asset, discovers it through the real `PortfolioRegistryStore`, saves it to an isolated registry, loads list/detail/status/logs/log-summary, queues a high-severity control run, approves it, executes it, and verifies the captured output.
- Added `VEQRAL_HOST_HOME` support so Host smokes can isolate runs/logs/audit data from the user's real `~/.veqral-host`.
- Added `includeGitHub` to the discover request. The app keeps the default behavior, while the A4 smoke disables GitHub discovery so the sample fixture is deterministic and does not depend on the user's GitHub account.
- Added `VEQRAL_DISABLE_DISCORD_WEBHOOK` so smokes do not send real Discord notifications even if a webhook is present in Keychain.

## A4 Result

- Current machine has no `VEQRAL_PORTFOLIO_CODE_ROOTS` / `VEQRAL_PORTFOLIO_ENGAGEMENT_ROOTS` and no explicit `VEQRAL_PORTFOLIO_REGISTRY_REPO` / `VEQRAL_PORTFOLIO_REGISTRY_PATH` in the shell environment used for this run.
- Because the real roots were not configured, A4 used an explicit isolated sample fixture. This is not recorded as real-asset acceptance.
- Smoke output:

```text
PASS: Portfolio A4 smoke mode=sample-fixture; §0 roots unset assets=1 status=running run=DE7BF8E4 missing=VEQRAL_PORTFOLIO_CODE_ROOTS/ENGAGEMENT_ROOTS,VEQRAL_PORTFOLIO_REGISTRY_REPO/PATH
```

## Verified Flow

- Discover: local code root scan found the sample Swift asset.
- Registry: `assets/<id>.yaml` was written and read back from an isolated registry.
- Detail/status: `cmd` health returned `running`.
- Logs: file tail returned the sample log line.
- Log summary: fallback summary returned non-empty redacted text.
- Operation: `restart` control queued a high-severity approval, approval moved the run to queued, Shell execution completed with exit code `0`, and PTY logs captured the command output.

## Remaining Live Acceptance

- Configure the paired Host with real values:
  - `VEQRAL_PORTFOLIO_CODE_ROOTS`
  - `VEQRAL_PORTFOLIO_ENGAGEMENT_ROOTS`
  - `VEQRAL_PORTFOLIO_REGISTRY_REPO` or `VEQRAL_PORTFOLIO_REGISTRY_PATH`
  - optional `VEQRAL_DISCORD_WEBHOOK`
- Then run discover from the 司令塔 UI against real assets and fill each asset's health/log/control fields before executing a live approval-gated operation.

## Validation

- `swift build --package-path MacHost`
- `swift run --package-path MacHost VeqralHost smoke-portfolio-real-data`
- iOS Simulator build through XcodeBuildMCP (`CODE_SIGNING_ALLOWED=NO`)
- `xcodebuild -project Veqral.xcodeproj -scheme Veqral -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build`
- `swift run --package-path MacHost VeqralHost smoke-project-memory`
- `swift run --package-path MacHost VeqralHost smoke-discord-notifications`
- `swift run --package-path MacHost VeqralHost smoke-host-telemetry`
- `swift run --package-path MacHost VeqralHost smoke-run-usage`
- `swift run --package-path MacHost VeqralHost smoke-voice-cleanup`
- `swift run --package-path MacHost VeqralHostSmoke verify-memory-inheritance`
- `git diff --check`
- Localizable lint + missing-key check
- source production grep clean
- concrete secret grep clean
