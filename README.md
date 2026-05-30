# Veqral

Veqral is a SwiftUI prototype for a personal AI Agent Command Center on iPhone, iPad, and Mac Catalyst.

The current build is MVP 0.5: the command center is now usable for local command runs, approvals, logs, diffs, and persisted state, while the broader agent organization, device fleet, artifacts, and GitHub surfaces remain product-shaped scaffolding.

The default UI is the dark Agent Command Center concept. Use the sun/moon button in the command header or sidebar to switch between dark mode and white mode.

The visible copy intentionally mixes Japanese and English: decision points such as approvals, risk, action buttons, and status use Japanese, while developer terms such as Command, Run, Terminal, Diff, Context Pack, model names, and file paths stay in English.

## What Works

- Enter a Command to create a new Run.
- Safe commands run locally in the Mac Catalyst app through `/bin/zsh -lc`.
- Risky commands such as `rm`, `sudo`, production deploys, secrets, and screen-control commands stop in the approval queue.
- Approve or reject pending actions from the inspector, phone dashboard, or Approvals screen.
- Logs, run status, selected run, approvals, working directory, and git diff summaries persist in Application Support as JSON.
- iPhone and iPad builds can create and track Runs; local shell execution is intentionally Mac-only.

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
