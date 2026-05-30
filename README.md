# Veqral

Veqral is a SwiftUI command center for running and supervising local agent work from iPhone, iPad, and Mac Catalyst.

The current build is MVP 0.8: the command center can run local shell commands and Hermes Agent prompts from the Mac Catalyst app, with approvals, logs, diffs, persisted state, live workspace inspection, current Git repository status, model assignment UI, shared Context Package visibility, and a QR-style Mac Host pairing scaffold. Broader remote Mac Host execution, artifacts, and PR automation remain product-shaped scaffolding.

The default UI is the dark Agent Command Center concept.

## What Works

- Enter a Command to create a new Run.
- Switch the runtime between `Hermes Agent` and `Local Shell`.
- Hermes prompts run through `hermes chat -Q --source veqral --checkpoints` on Mac.
- Read-only commands run locally in the Mac Catalyst app through `/bin/zsh -lc`.
- Mutating or risky commands such as file changes, package installs, `rm`, `sudo`, production deploys, secrets, and screen-control commands stop in the approval queue.
- Risky Hermes prompts such as deletion, production, secrets, billing, browser, and screen-control requests also stop in the approval queue before launching Hermes.
- Approve or reject pending actions from the inspector, phone dashboard, or Approvals screen.
- Logs, run status, selected run, approvals, working directory, and git diff summaries persist in Application Support as JSON.
- The app detects the current Git root, branch, remote, and working tree status for the selected working directory.
- The app detects the local Hermes executable and version from common install paths such as `~/.local/bin/hermes`.
- The Devices screen exposes a Mac Host pairing QR payload, Tailscale endpoint, and per-session pairing token placeholder.
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

P0 before real outside-the-house operation:

- Build the separate macOS menu bar Agent Host and login item.
- Replace the QR placeholder with signed one-time pairing, Keychain storage, token rotation, and device revocation.
- Add the Host transport API over Tailscale: create run, stream PTY logs, cancel/resume, approval response, diff/artifact fetch, and health checks.
- Move iPhone/iPad execution from local placeholders to the paired Mac Host.
- Redact secrets from logs before persistence or streaming.
- Persist audit logs for approval, rejection, command start, command finish, and artifact access.

P1 after the Host exists:

- Connect Hermes sessions by ID so runs can resume across app launches.
- Store user/project/decision memory in SwiftData or SQLite, with edit, pin, forget, and memory-candidate review actions.
- Generate real Context Packages from memory, requirements, repo summary, relevant files, safety policy, and device capabilities.
- Add real artifacts: screenshots, web preview URLs, PDFs, test reports, and build products.
- Add GitHub operations for branch, commit, PR, CI, review response, and guarded deploy.

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
