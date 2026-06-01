# Auth Onboarding PR A5

## Scope

- Added an authenticated Host API for one-time auth onboarding:
  - `GET /v1/auth/onboarding`
  - `POST /v1/auth/onboarding/refresh`
- Added a Devices screen panel, `認証オンボーディング`, that shows Codex / Claude / Hermes readiness, login commands, Hermes provider readiness, and Keychain marker state.
- The UI lets the user copy login commands and then refresh the Host-side check after completing login on the Mac.
- `refresh` writes only readiness markers such as `auth-onboarding:codex:ready` to Keychain when the current login check is ready. It never stores passwords, OAuth codes, API keys, or copied CLI auth file contents.
- Added `VeqralHost smoke-auth-onboarding` to validate provider coverage and secret hygiene.

## Security Model

- The agent and app do not handle passwords or OAuth browser sessions.
- `~/.codex`, `~/.claude`, and `~/.hermes` are checked by file existence only; contents are not read, edited, copied, deleted, or logged.
- Sign-in-with-Google remains the user's normal browser/CLI login flow when the account is Google-backed.
- Keychain stores readiness markers only, not provider credentials.

## Current Machine Result

- `codex`, `claude`, and `hermes` CLIs are installed.
- `smoke-auth-onboarding` reported all three providers ready on this Mac:

```text
PASS: Auth onboarding smoke providers=3 ready=3 allReady=true
```

## Residuals

- A5 verifies login readiness and UI/Host wiring. It does not replace #A7's cross-vendor Hermes memory proof.
- #A7 still needs the actual Claude -> GPT Hermes native-memory run. If Hermes cannot drive Claude despite the local Claude credentials being present, #A7 must report that as a real provider failure rather than treating this readiness check as proof.

## Validation

- `swift build --package-path MacHost`
- `swift run --package-path MacHost VeqralHost smoke-auth-onboarding`
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
