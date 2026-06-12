# Swarm Orchestration Phase 2

## Scope

Phase 2 adds the Veqral client surface for the Phase 1 Mac Host swarm runner:

- new `群制御` section in the sidebar and More flow
- swarm coordinator status: active slots, queued/running counts, Xcode slot limit, thermal state, kill switch state
- task composer for repo path, agent kind, instruction, scope hints, verification commands, and draft PR creation
- task list with status colors and selection
- task detail with branch, repo path, timestamps, scope hints, PR link, logs, individual cancel, and global kill switch

The UI talks to the authenticated `/v1/swarm/*` API added in Phase 1. It does not create another transport or merge path.

## Safety

- `main` is not merged from the client.
- The kill switch is explicit and leaves the Host in a stopped state until Host restart.
- Task logs are displayed from the Host ledger after redaction.
- Draft PR creation remains a per-task option and depends on normal `gh` authentication on the Mac Host.

## Verification

- `swift build --package-path MacHost`
- `xcodebuild -project Veqral.xcodeproj -scheme Veqral -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`

## Manual Smoke

1. Pair the app with the Mac Host.
2. Open `群制御`.
3. Refresh and confirm slot/thermal/kill-switch status appears.
4. Queue a shell-backed smoke task from a scratch repo.
5. Confirm the task appears in the list, logs stream into detail after refresh, and individual cancel is disabled after terminal status.
6. Queue a long task and tap `全停止`; confirm the Host marks work cancelled and refuses new tasks until restart.
