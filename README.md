# Veqral

Veqral is a SwiftUI command center for running and supervising local agent work from iPhone, iPad, and Mac Catalyst.

The current build is P0: the command center can run local shell commands and Hermes Agent prompts from the Mac Catalyst app, and iPhone/iPad can pair with a Swift Mac Host over Tailscale to create Hermes runs, stream PTY logs over WebSocket, approve/reject guarded work, cancel/resume sessions, and keep device tokens in Keychain.

The default UI is the dark Agent Command Center concept.

## What Works

- Enter a Command to create a new Run.
- Switch the runtime between `Hermes Agent` and `Local Shell`.
- Hermes prompts run through `hermes chat -Q --source veqral --checkpoints --worktree` on Mac.
- The Swift Mac Host lives in `MacHost/` and runs as a menu bar app.
- Mac Host exposes `GET /v1/health`, `GET /v1/pairing`, `POST /v1/pair`, `GET/POST /v1/runs`, `GET /v1/runs/:id/events`, run snapshots/logs/diff/artifacts, and approve/reject/cancel/resume actions.
- Mac Host exposes HMAC-protected device listing/revocation, audit log, GitHub status, and draft PR creation endpoints.
- Mac Host exposes unattended remote-operation status/apply/revert endpoints, plus a local menu bar setup window that requires confirmation, admin authorization, and a one-time login password entry before changing macOS autologin, screen-lock, sleep, display-sleep, and autorestart settings.
- The unattended setup flow checks FileVault, warns when FileVault blocks autologin, skips autologin when allowed, reads settings back after changes, and can revert the settings.
- The Mac Host menu can install/remove a LaunchAgent for login-time restart and KeepAlive recovery.
- iPhone/iPad remote requests use per-device HMAC headers and the device token is stored in Keychain.
- iPhone/iPad can open `veqral://pair?...` QR links, reconnect to persisted remote runs after app restart, and receive local notifications for approvals and run completion.
- Remote PTY logs stream line-by-line over WebSocket and are redacted before leaving the Mac Host.
- Host runs, logs, audit entries, and Hermes `session_id` values persist under `~/.veqral-host`.
- Mac Host exposes HMAC-protected Hermes memory APIs for `~/.hermes/memories/USER.md`, `~/.hermes/memories/MEMORY.md`, and Markdown files under `~/.hermes/skills`.
- The Memory screen can list remote Hermes memory files, load content, preview a unified diff before saving, and write the selected file back through Mac Host.
- Read-only commands run locally in the Mac Catalyst app through `/bin/zsh -lc`.
- Mutating or risky commands such as file changes, package installs, `rm`, `sudo`, production deploys, secrets, and screen-control commands stop in the approval queue.
- Risky Hermes prompts such as deletion, production, secrets, billing, browser, and screen-control requests also stop in the approval queue before launching Hermes.
- Approve or reject pending actions from the inspector, phone dashboard, or Approvals screen.
- Logs, run status, selected run, approvals, working directory, and git diff summaries persist in Application Support as JSON.
- The app detects the current Git root, branch, remote, and working tree status for the selected working directory.
- The app detects the local Hermes executable and version from common install paths such as `~/.local/bin/hermes`.
- The Devices screen exposes Remote Mac Host pairing, live health, paired devices, revocation, and Host audit log.
- The GitHub screen reads branch/remote/working tree/PR/CI/auth status from the Host and can request a draft PR through `gh`.
- The Diff and Artifacts screens sync remote git diff summaries and generated files from Host runs.
- The Models screen maps PM, architect, implementer, reviewer, tester, and researcher roles to provider/model profiles while showing that every role shares one Context Package.
- Local command execution separates stdout and stderr, validates the working directory, captures git diff summaries, and times out long-running commands after 180 seconds.
- iPhone and iPad builds can create and track Runs; local shell execution is intentionally Mac-only.

## Hermes

Veqral expects Hermes Agent to be installed on the Mac running the Catalyst app:

```sh
hermes --version
hermes doctor
```

The current local check passed with Hermes Agent v0.15.1. `hermes doctor` reports that OpenAI Codex auth is logged in, while some optional providers and tools are not configured.

### Hermes memory inheritance smoke

`VeqralHostSmoke verify-memory-inheritance` proves Veqral's core promise with a disposable Hermes source and isolated `HERMES_HOME`. It must use real Hermes native memory and two real models (`A != B`); do not add a custom memory layer or hard-code the expected fact.

Current passing route: monthly-login ChatGPT subscription through Hermes `openai-codex`. The smoke keeps Hermes memory isolated, then links the existing Hermes login auth from `~/.hermes/auth.json` into the disposable `HERMES_HOME`; it does not require API keys.

```sh
export VEQRAL_MEMTEST_PROVIDER_A=openai-codex
export VEQRAL_MEMTEST_MODEL_A=gpt-5.5
export VEQRAL_MEMTEST_PROVIDER_B=openai-codex
export VEQRAL_MEMTEST_MODEL_B=gpt-5.4
swift run --package-path MacHost VeqralHostSmoke verify-memory-inheritance --report HERMES_MEMORY_INHERITANCE_PR0.md
```

If the Hermes login home is not `~/.hermes`, point the smoke at it with `VEQRAL_MEMTEST_AUTH_HOME`. Claude/Anthropic can be selected only when Hermes reports that Claude Code/setup-token auth is usable on the Mac.

Free local fallback: install/start Ollama and choose two different pulled models. This avoids subscription/API setup while still proving Hermes native memory across A != B models.

```sh
ollama pull qwen2.5:7b
ollama pull llama3.1:8b
curl http://127.0.0.1:11434/api/tags
export VEQRAL_MEMTEST_PROVIDER_A=custom
export VEQRAL_MEMTEST_MODEL_A=qwen2.5:7b
export VEQRAL_MEMTEST_BASE_URL_A=http://127.0.0.1:11434/v1
export VEQRAL_MEMTEST_PROVIDER_B=custom
export VEQRAL_MEMTEST_MODEL_B=llama3.1:8b
export VEQRAL_MEMTEST_BASE_URL_B=http://127.0.0.1:11434/v1
swift run --package-path MacHost VeqralHostSmoke verify-memory-inheritance --report HERMES_MEMORY_INHERITANCE_PR0.md
```

API-key providers remain optional fallback only. When used, put keys in env or Keychain, never in code or reports:

```sh
security add-generic-password -U -s dev.hiroyuki.veqral.host -a openrouter:api-key -w "$OPENROUTER_API_KEY"
security add-generic-password -U -s dev.hiroyuki.veqral.host -a anthropic:api-key -w "$ANTHROPIC_API_KEY"
```

Override the account/service names if needed with `VEQRAL_MEMTEST_KEYCHAIN_SERVICE`, `VEQRAL_MEMTEST_OPENROUTER_KEY_ACCOUNT`, `VEQRAL_MEMTEST_ANTHROPIC_KEY_ACCOUNT`, or per-custom-endpoint `VEQRAL_MEMTEST_API_KEY_ACCOUNT_A/B`.

## Operational Gaps

P1 after this Host:

- Store user/project/decision memory metadata in SwiftData or SQLite, with pin, forget, memory-candidate review actions, and Mac-to-Mac memory sync.
- Generate real Context Packages from memory, requirements, repo summary, relevant files, safety policy, and device capabilities.
- Expand artifact previews beyond path listing into screenshots, web preview URLs, PDFs, test reports, and build products.
- Expand GitHub operations beyond status/draft PR into automated branch naming, commit staging policy, CI retry, review response, guarded merge, and guarded deploy.
- Add camera QR scanning on iPhone/iPad and deeper Hermes internal approval correlation.
- Add Mac mini as a second Host, multi-model PM/Reviewer organization, skill creation/update flows, MCP setup, gateways, cron, and delegation visualization.

## Run Mac Host

```sh
cd MacHost
swift run VeqralHost
```

Open the menu bar item and choose `Show Pairing QR`, or fetch pairing data directly:

```sh
curl http://127.0.0.1:7878/v1/pairing
```

For a dedicated Mac mini or always-on Host, open the menu bar item and choose `Unattended Remote Setup...`. This flow is intentionally local and explicit because it changes security and power settings.

## Open

```sh
open Veqral.xcodeproj
```

## Build From Terminal

```sh
xcodebuild -project Veqral.xcodeproj -scheme Veqral -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=NO build
```

## Build Mac App

```sh
xcodebuild -project Veqral.xcodeproj -scheme Veqral -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build
```
