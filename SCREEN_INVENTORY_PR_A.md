# PR-A Screen Inventory

## Base

- Branch: `codex/pr-a-screen-inventory`
- Stacked on: `codex/pr1-core-fixes` / PR #15
- Clean-main note: PR #9 through #15 are still open draft PRs, so this branch cannot honestly claim to be cut from a fully clean `main` yet. Merge ordering still needs #9 -> #15 before PR-A can become a clean-main cleanup.

## Navigation Facts

`AppSection.allCases` defines 15 routed sections. They are all reachable through one of:

- iPhone: primary tabs (`Command`, `Approvals`, `Projects`, `Devices`) plus `More`
- iPad: `RegularRootView` sidebar
- Mac Catalyst: `MacRootView` sidebar

`sectionDestination(_:)` resolves every `AppSection` case.

## Keep / Merge / Cut

| Section | Route | Decision | Code fact |
| --- | --- | --- | --- |
| Command | `.home -> CommandCenterRunView` | keep | Primary command surface. Creates runs, streams logs, shows diff surface, approval callout, Host connection strip. |
| Approvals | `.approvals -> ApprovalsView` | keep | Primary tab. Uses `store.pendingApprovals()`, `store.approve`, and `store.reject`. |
| Projects | `.projects -> ProjectsView` | keep | Hermes Project/Chat lifecycle is wired: create/select/rename chat and submit to selected chat. |
| Devices | `.devices -> DevicesView` | keep | QR/manual pairing, Host refresh, CLI diagnostics, runtime select, remote device revoke. |
| Intent | `.chat -> IntentCaptureView` | merge candidate | Reachable, but mostly reuses `CommandComposer` and summaries from Command/Memory. No unique state transition beyond command submission. |
| Requirements | `.requirements -> RequirementsView` | merge candidate | Reachable, but currently selected-run context plus phase rail only; no separate requirements store/model. |
| Agents | `.agents -> AgentsView` | user decision | Reachable but largely static organization/runtime explanation. Real worker org is explicitly future scope. |
| Models | `.models -> ModelAssignmentView` | merge candidate | Hermes provider picker is real, but direct modes cannot change model here. Could merge into Projects or Devices later. |
| Runs | `.runs -> RunsView` | keep | Adds phase filter and archive action beyond Command active-run list. |
| Terminal | `.terminal -> TerminalView` | merge candidate | Functional command/log surface, but overlaps with `CommandCenterRunView` terminal work surface. |
| Diff | `.diff -> DiffView` | keep | Adds hunk attach and image diff modes not present in Command's compact diff list. |
| Artifacts | `.artifacts -> ArtifactsView` | keep | Displays Host artifacts and refreshes Host status on appear. |
| History | `.history -> HistoryView` | keep | Codex/Claude history read-only list/detail/resume is wired to Host history APIs. |
| Memory | `.memory -> MemoryView` | keep | Live Hermes memory file list/read/diff/save is wired to Host memory APIs. Scope panel is mostly explanatory but not enough to cut the screen. |
| GitHub | `.github -> GitHubOpsView` | keep | Host-backed status refresh and draft PR creation are wired. |

## Removed In This Branch

| Item | File | Reason |
| --- | --- | --- |
| `DashboardView` | `Veqral/Screens.swift` | Unreachable old home surface. `sectionDestination(.home)` uses `CommandCenterRunView` instead. |
| `SidebarView` | `Veqral/RootView.swift` | Unreachable old `List` sidebar. iPad/Mac use `CommandCenterSidebar`. |
| `InspectorView` | `Veqral/Screens.swift` | Unreachable old inspector. iPad/Mac use `CommandCenterInspectorView`. |
| `MetricTile`, `CommandMetric` | `Veqral/Components.swift`, `Veqral/Models.swift` | Only used by removed `DashboardView`. |
| `RunRow`, `AgentRun` | `Veqral/Components.swift`, `Veqral/Models.swift` | Old run row/model unused by live `CommandRun` flow. |
| `DeviceRow`, `Device` | `Veqral/Components.swift`, `Veqral/Models.swift` | Old local device row/model unused by remote device list. |
| `ApprovalRow`, `ApprovalRequest`, `RiskType` | `Veqral/Components.swift`, `Veqral/Models.swift` | Old approval row/model unused by live `CommandApproval` flow. |
| `ProjectItem`, `AgentProfile`, `ModelProfile`, `RequirementSection`, `RequirementState`, `ChatMessage`, `ArtifactItem`, `MemoryEntry`, `DiffFile`, `LogLine`, `MemoryRow` | `Veqral/Models.swift`, `Veqral/Screens.swift` | Seed-era models/views with no live references. |

## User Decision Items

- Whether `Intent` and `Requirements` should remain separate tabs or be folded into `Command`.
- Whether `Agents` should stay visible before PM/role/delegation work exists.
- Whether `Models` should stay standalone, or live under Hermes Project settings.
- Whether `Terminal` should remain a standalone tab, or only exist as the Command work surface.
