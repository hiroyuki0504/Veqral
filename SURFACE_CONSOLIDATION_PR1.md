# PR1 Surface Consolidation

## Base

- Branch: `codex/pr1-surface-consolidation`
- Stacked on: PR #16 (`codex/pr-a-screen-inventory`)
- Clean-main note: PR #9 through #16 are still open draft PRs. This PR is intentionally stacked on the current tip and should be folded into a clean-main integration only after the existing stack is accepted.

## Before / After

| Previous top-level surface | Decision | New home |
| --- | --- | --- |
| `Intent` | Removed as a top-level screen. It duplicated the Command composer and recent-run intake. | `Command` composer now owns the instruction entry point. A small requirement memo affordance sits beside the composer on both compact and regular layouts. |
| `Requirements` | Removed as a top-level screen. It had selected-run context but no separate requirement store. | `Command` shows the selected run and requirement prompt action; run phase context stays in `Runs`. |
| `Agents` | Removed as a top-level screen. Runtime selection already exists in Command and Devices. | `Devices` keeps the Mac Host runtime selector for Hermes/Codex/Claude. `Command` keeps the runtime segmented control. |
| `Models` | Removed as a top-level screen. Provider/model routing only applies to Hermes Project chats. | `Projects` -> `Hermes Chats` now contains the Hermes model picker and writes to the selected chat. |
| `Terminal` | Removed as a top-level screen. It duplicated Command Shell mode and the run transcript. | `Command` keeps Shell runtime, working-directory entry, attachments, approval callout, PTY/log transcript, and diff surface. |

## Removed Code

- `AppSection` cases: `.chat`, `.requirements`, `.agents`, `.models`, `.terminal`
- Routed SwiftUI views: `IntentCaptureView`, `RequirementsView`, `AgentsView`, `ModelAssignmentView`, `TerminalView`
- Dead helper views after those removals: `ModelTrait`, `OrganizationGraph`, `AgentNode`, `ContextPackageIndicator`, `CommandComposer`, `QuickCommandButton`
- Dead navigation entry: iPhone Command header plus link to old Intent

## Preserved Paths

- Command execution still flows through `CommandCenterStore.submitDraft` / `submitCommand`.
- Hermes Project/Chat state still uses `AgentProjectSpace`, `AgentChatSpace`, and `selectHermesModel`.
- Direct Codex/Claude histories remain read-only and resumable from History.
- Host PTY/log streaming and approval UI are retained in Command and Approvals.
- Diff and Artifacts remain top-level because they have standalone hunk/image review and artifact browsing behavior.
- Runs remains top-level because it provides phase filtering and archive actions beyond the active Command list.

## No New Decisions

The four PR-A decision items are resolved in this PR. Any later removal of `Runs`, `Diff`, or `Artifacts` should be treated as a separate product choice because they still own live behavior.
