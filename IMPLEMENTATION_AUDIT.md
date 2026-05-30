# Veqral Implementation Audit

Date: 2026-05-31
Branch: `veqral/finish-incomplete`
Base: PR #3 head `44c942d`

## Scope

This audit reviewed Codex session history under `~/.codex/sessions/**/rollout-*.jsonl` and the Veqral repository at `/Users/hiroyuki/Documents/Veqral`.

Inputs reviewed:

- 193 Codex session files scanned.
- 6 Veqral-related sessions identified by cwd/path/project references.
- Repository scan for `TODO`, `FIXME`, `HACK`, `XXX`, `stub`, `mock`, `placeholder`, `not implemented`, `unimplemented`, `simulator-only`, and related Japanese terms.

Secrets were not copied into this document. History findings are summarized and redacted.

## Summary

- ✅ Implemented / verified: 9
- 🔧 Incomplete or broken in current scope and fixed in this branch: 3
- ⏸️ Intentionally deferred by product scope: 11

## ✅ Implemented / Verified

1. iPhone/iPad to Mac Host E2E pipeline
   - Source: Codex session `rollout-2026-05-31T01-37-24...`
   - Status: Implemented before this branch. Pairing, Run creation, Hermes launch, WebSocket logs, approve/cancel/resume, and camera attachment were reported as passing on real devices.

2. Mac Host P0 execution path
   - Source: prior P0 prompts and PR #2/#3 work.
   - Location: `MacHost/Sources/VeqralHost/main.swift`
   - Status: Implemented. Host exposes health, pairing, run, stream, approval, cancel/resume, artifacts, GitHub, memory, and history routes.

3. Production mock data removal
   - Source: session `rollout-2026-05-31T01-37-24...`
   - Location: `Veqral/MockData.swift`, `Veqral/AppState.swift`
   - Status: Implemented in PR #3. `MockData.swift` is removed from the production target and legacy seeded runs/approvals/logs are cleaned during snapshot migration.

4. Camera and Photos attachment path
   - Source: session `rollout-2026-05-31T01-37-24...`
   - Location: `Veqral/Components.swift`, `Veqral/Info.plist`, `MacHost/Sources/VeqralHost/main.swift`
   - Status: Implemented. Handles authorization states, unavailable camera environments, image encoding, upload to Host, and artifact registration.

5. Menu bar appearance settings
   - Source: menu bar prompt in session `rollout-2026-05-30T18-36-16...`
   - Location: `MacHost/Sources/VeqralHost/main.swift`
   - Status: Implemented. Display title, style, selected symbol, language, and listening animation are persisted.

6. Menu bar icon identity bug
   - Source: user-reported bug in menu bar prompt.
   - Location: `MacHost/Sources/VeqralHost/main.swift`
   - Status: Implemented in PR #3. The selected icon no longer cycles through every option; animation only pulses the selected identity.

7. Claude/Codex History viewer
   - Source: history viewer prompt.
   - Location: `MacHost/Sources/VeqralHost/main.swift`, `Veqral/AppState.swift`, `Veqral/Screens.swift`, `Veqral/Models.swift`, `Veqral/RootView.swift`
   - Status: Implemented in PR #3. Host reads JSONL history read-only, redacts secrets, pages lists, and lazily loads details. iOS has History list, filters, search, and detail.

8. Hermes memory read/edit via Mac Host
   - Source: go-live prompt and PR #3 implementation.
   - Location: `MacHost/Sources/VeqralHost/main.swift`, `Veqral/AppState.swift`, `Veqral/Screens.swift`
   - Status: Implemented. USER.md, MEMORY.md, and skills markdown files can be listed/read; edits show diff before save.

9. GitHub status and draft PR path
   - Source: go-live/GitHub requirements.
   - Location: `MacHost/Sources/VeqralHost/main.swift`, `Veqral/AppState.swift`, `Veqral/Screens.swift`
   - Status: Implemented for status inspection and draft PR creation. Main merge/deploy remain approval/deferred by policy.

## 🔧 Fixed In This Branch

1. Pressable UI with empty actions
   - Source: repository scan found `Button(action: {})` in production views.
   - Location: `Veqral/Components.swift`, `Veqral/CommandCenterViews.swift`, `Veqral/RootView.swift`
   - Fix: Replaced inert buttons with real navigation, menus, draft command actions, or non-interactive status text. The iPad inspector "View all approvals" now switches to Approvals, phone quick chips populate actionable prompts, the run overflow uses a real menu, and phone project status links to Projects.

2. History list selected a session but did not load its turns
   - Source: code review of `refreshRemoteHistory`.
   - Location: `Veqral/AppState.swift`
   - Fix: After list refresh, the first selected session now automatically loads details when needed, so the detail pane does not falsely show an empty session before the user taps a row.

3. Hard-coded device count in an unused sidebar variant
   - Source: repository scan found `2 Macs reachable`.
   - Location: `Veqral/RootView.swift`
   - Fix: Replaced the hard-coded value with the real paired Host endpoint or a pairing prompt. This keeps inactive code from carrying fake production state.

## ⏸️ Intentionally Deferred

These were explicitly scoped out by the user or are product-level P1/P2 items. They were not built in this branch.

1. Mac mini second Host
   - Reason: P1; current P0 is single MacBook Pro Host over Tailscale.

2. Multi-model organization such as PM=Claude, Reviewer=Claude, Implementer=Codex
   - Reason: P1; current default execution model is Codex through Hermes/Mac Host.

3. MCP configuration screen
   - Reason: P1/P2; not needed for current E2E command pipeline.

4. Cron / scheduled autonomous jobs
   - Reason: P1/P2; current app is user-command driven.

5. Delegation graph visualization
   - Reason: P1/P2; current app exposes roles/context but not a full organization graph.

6. Memory sync between multiple Macs
   - Reason: P1/P2; Hermes memory on the paired Mac is the current source of truth.

7. Skills creation/update from Veqral
   - Reason: P1/P2; current implementation lists/edits existing markdown memory/skills files only.

8. Gateway integrations such as Discord, Telegram, or Slack
   - Reason: P1/P2; out of scope for the mobile command center path.

9. App Store distribution
   - Reason: Deferred; current distribution target is personal Developer ID / direct device install.

10. Built-in remote desktop / Veqral-native screen control
    - Reason: Deferred; screen control is approval-gated and out of current mobile app scope.

11. Full settings screen redesign and app-wide Japanese/English localization
    - Reason: Explicitly deferred. Menu bar language selection exists; broader app settings/localization should be designed as a separate UI/UX pass.

## Code Scan Notes

- No production `TODO`, `FIXME`, `HACK`, `XXX`, `not implemented`, or `unimplemented` markers remain in app/Host source.
- Remaining `placeholder` strings are TextField/password placeholder copy, not placeholder implementations.
- Remaining empty/unsupported cases in parsers return `nil` or `[]` deliberately for malformed external JSONL, missing files, or unavailable optional metadata.
