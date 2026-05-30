# Veqral

Veqral is a SwiftUI command center for running and supervising local agent work from iPhone, iPad, and Mac Catalyst.

The current build is P0: the command center can run local shell commands and Hermes Agent prompts from the Mac Catalyst app, and iPhone/iPad can pair with a Swift Mac Host over Tailscale to create Hermes runs, stream PTY logs over WebSocket, approve/reject guarded work, cancel/resume sessions, and keep device tokens in Keychain.

The default UI is the dark Agent Command Center concept.

## What Works

- Enter a Command to create a new Run.
- Switch the runtime between `Hermes Agent` and `Local Shell`.
- Hermes prompts run through `hermes chat -Q --source veqral --checkpoints --worktree` on Mac.
- The Swift Mac Host lives in `MacHost/` and runs as a menu bar app.
- Mac Host exposes `GET /v1/health`, `GET /v1/pairing`, `POST /v1/pair`, `POST /v1/runs`, `GET /v1/runs/:id/events`, and approve/reject/cancel/resume actions.
- iPhone/iPad remote requests use per-device HMAC headers and the device token is stored in Keychain.
- Remote PTY logs stream line-by-line over WebSocket and are redacted before leaving the Mac Host.
- Host runs, logs, audit entries, and Hermes `session_id` values persist under `~/.veqral-host`.
- Read-only commands run locally in the Mac Catalyst app through `/bin/zsh -lc`.
- Mutating or risky commands such as file changes, package installs, `rm`, `sudo`, production deploys, secrets, and screen-control commands stop in the approval queue.
- Risky Hermes prompts such as deletion, production, secrets, billing, browser, and screen-control requests also stop in the approval queue before launching Hermes.
- Approve or reject pending actions from the inspector, phone dashboard, or Approvals screen.
- Logs, run status, selected run, approvals, working directory, and git diff summaries persist in Application Support as JSON.
- The app detects the current Git root, branch, remote, and working tree status for the selected working directory.
- The app detects the local Hermes executable and version from common install paths such as `~/.local/bin/hermes`.
- The Devices screen exposes Remote Mac Host pairing fields for the menu bar QR/code flow and persists the paired device without storing the token in app JSON.
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

## Operational Gaps

P1 after this Host:

- Store user/project/decision memory in SwiftData or SQLite, with edit, pin, forget, and memory-candidate review actions.
- Generate real Context Packages from memory, requirements, repo summary, relevant files, safety policy, and device capabilities.
- Add real artifacts: screenshots, web preview URLs, PDFs, test reports, and build products.
- Add GitHub operations for branch, commit, PR, CI, review response, and guarded deploy.
- Add login item installation, device revocation UI, QR scanning, diff/artifact endpoints, and deeper Hermes internal approval correlation.

## Run Mac Host

```sh
cd MacHost
swift run VeqralHost
```

Open the menu bar item and choose `Show Pairing QR`, or fetch pairing data directly:

```sh
curl http://127.0.0.1:7878/v1/pairing
```

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
