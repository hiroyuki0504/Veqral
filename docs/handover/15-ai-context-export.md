# AI context export

確認時点: 2026-06-23 15:44:42 JST

This file externalizes project context that was previously in conversation, AI memory, AGENTS notes, or prior handoff docs. Future maintainers should not need the chat that produced this package.

## Context ID: AICTX-001

**内容:**
Codex is expected to act as the main implementer for Veqral, not only as a reviewer. The normal mode is autonomous scoped implementation on a new branch with draft PR, while respecting high-severity approval boundaries.

**種別:**
方針

**根拠:**
`AGENTS.md`

**プロジェクト内の保存先:**
`AGENTS.md`, `docs/handover/07-development-workflow.md`

**未反映の場合のリスク:**
Future agents may stop at advice instead of delivering branch/PR-ready work, or may make unsafe main changes.

## Context ID: AICTX-002

**内容:**
Veqral's core product promise is remote control of local AI coding agents from iPhone/iPad/Mac Catalyst, with Hermes as the differentiator for memory orchestration.

**種別:**
事実

**根拠:**
`AGENTS.md`, `README.md`

**プロジェクト内の保存先:**
`README.md`, `docs/handover/00-executive-summary.md`

**未反映の場合のリスク:**
Maintainers may optimize around generic remote terminal behavior and miss the Hermes memory product requirement.

## Context ID: AICTX-003

**内容:**
Memory/history must not be implemented as a new Veqral-specific shared memory store. Hermes native memory/session is the source for Hermes mode; Codex and Claude direct modes stay siloed in their native histories.

**種別:**
方針

**根拠:**
`AGENTS.md`, `HERMES_MEMORY_INHERITANCE_PR0.md`, memory notes

**プロジェクト内の保存先:**
`AGENTS.md`, `docs/handover/03-architecture.md`, `docs/handover/05-data-and-state.md`

**未反映の場合のリスク:**
Future work could create a parallel memory layer that conflicts with Hermes and invalidates the product's continuity claim.

## Context ID: AICTX-004

**内容:**
Do not edit/delete `~/.codex` or `~/.claude`. Veqral may read histories for display/resume, but the native stores are owned by their tools.

**種別:**
方針

**根拠:**
`AGENTS.md`, `HistoryStore` in `MacHost/Sources/VeqralHost/main.swift`

**プロジェクト内の保存先:**
`docs/handover/05-data-and-state.md`, `docs/handover/13-known-issues-and-risks.md`

**未反映の場合のリスク:**
Native agent histories may be corrupted or deleted.

## Context ID: AICTX-005

**内容:**
For Veqral runtime and merge-readiness questions, inspect the live repo/config/logs first. A green core healthcheck does not automatically mean LaunchAgent wrappers, AI-Hub bridge, or device workflows are healthy.

**種別:**
ユーザー希望 / 方針

**根拠:**
AI memory notes, current live Host inspection

**プロジェクト内の保存先:**
`docs/handover/06-runtime-and-operations.md`, `docs/handover/08-testing-and-verification.md`

**未反映の場合のリスク:**
Maintainers may overclaim readiness from one passing command.

## Context ID: AICTX-006

**内容:**
The user rejected model-name fixation in Hermes/AI-Hub discussions. Future docs and UI should prefer policy/lane concepts such as `local-fast`, `local-reviewer`, `subscription-standard`, and only mention exact models when verifying a concrete transcript.

**種別:**
ユーザー希望 / 方針

**根拠:**
AI memory notes, `AGENTS.md`, `codex/aihub-local-runtime-cleanup` summary

**プロジェクト内の保存先:**
`docs/handover/12-decision-log.md`, `docs/handover/18-documentation-drift.md`

**未反映の場合のリスク:**
Future fixes may hard-code stale models and break AI-Hub policy routing.

## Context ID: AICTX-007

**内容:**
#A7 cross-vendor memory proof must not be faked with API-key fallback. It should run only when Hermes can read Claude/Anthropic subscription/login auth in the intended route.

**種別:**
方針

**根拠:**
`AGENTS.md`, `HERMES_CROSS_VENDOR_PR_A7.md`

**プロジェクト内の保存先:**
`docs/handover/13-known-issues-and-risks.md`, `docs/handover/17-next-actions.md`

**未反映の場合のリスク:**
The project could claim a core differentiator based on an artificial test route.

## Context ID: AICTX-008

**内容:**
Outbound Sales Lab sending must remain approval-gated. Current Sales Lab is manual/CSV registration, local artifacts, no automatic email/DM sending, and Google Places discovery is intentionally disabled.

**種別:**
方針 / 事実

**根拠:**
`SALES_LAB_PR.md`, Host smoke results, `AGENTS.md`

**プロジェクト内の保存先:**
`docs/handover/10-integrations-and-external-services.md`, `docs/handover/13-known-issues-and-risks.md`

**未反映の場合のリスク:**
Compliance/privacy issues or accidental outreach automation.

## Context ID: AICTX-009

**内容:**
When the user asks for local usability, "actually opened/compiled/playing now" is often expected, not just instructions. For Veqral this means builds, live health, simulator/device checks, and proof in docs.

**種別:**
ユーザー希望

**根拠:**
AI memory notes, this handover verification scope

**プロジェクト内の保存先:**
`docs/handover/08-testing-and-verification.md`, `docs/handover/17-next-actions.md`

**未反映の場合のリスク:**
Future agents may report theoretical readiness without running checks.

## Context ID: AICTX-010

**内容:**
Live browser/login/device state can be more authoritative than stale notes. For Veqral, live `/v1/health`, LaunchAgent state, git branch, and current Xcode environment should override older handoff claims when they conflict.

**種別:**
方針

**根拠:**
AI memory notes, current commands

**プロジェクト内の保存先:**
`docs/handover/02-current-state.md`, `docs/handover/18-documentation-drift.md`

**未反映の場合のリスク:**
Maintainers may preserve outdated README or PR-note facts.

## Context ID: AICTX-011

**内容:**
AI-Hub session digest should optimize for searchable continuity and next-step retrieval. It is not a native-history import and does not replace `~/.codex`, `~/.claude`, or Hermes state.

**種別:**
方針

**根拠:**
AI memory notes, `AGENTS.md`, `AIHubSessionDigestBridge`

**プロジェクト内の保存先:**
`docs/handover/05-data-and-state.md`, `docs/handover/12-decision-log.md`

**未反映の場合のリスク:**
Maintainers may treat curated notes as raw source of truth and lose detail.

## Context ID: AICTX-012

**内容:**
For AI-Hub/Obsidian storage cleanups, heavy generated archives should stay local-only, while curated notes can sync. Ask before deleting old archive generations.

**種別:**
ユーザー希望 / 未確認情報

**根拠:**
AI memory notes

**プロジェクト内の保存先:**
`docs/handover/14-open-questions.md` until confirmed with AI-Hub repo/vault policy

**未反映の場合のリスク:**
Potential accidental data loss or unwanted sync of large/sensitive artifacts.

## Context ID: AICTX-013

**内容:**
If Hermes/AI-Hub session context disappears mid-investigation, recover from sessions/files/skills and current handoff docs first instead of restarting reasoning from zero.

**種別:**
方針

**根拠:**
AI memory notes

**プロジェクト内の保存先:**
`docs/handover/06-runtime-and-operations.md`, this file

**未反映の場合のリスク:**
Future agents waste time and may contradict prior verified state.

## Context ID: AICTX-014

**内容:**
The current local `main` branch was behind `origin/main` at the start of this task. New work should be based on `origin/main`, as this handover branch is.

**種別:**
事実

**根拠:**
command: `git status --short --branch`, `git log main...origin/main`

**プロジェクト内の保存先:**
`docs/handover/02-current-state.md`, `docs/handover/07-development-workflow.md`

**未反映の場合のリスク:**
Future branches may accidentally omit recent AI-Hub/Hermes integration commits.

## Context ID: AICTX-015

**内容:**
The repo root has four pre-existing untracked handoff/status files. They were not created by this handover task and should not be deleted silently. Their content may be useful, but canonical placement is unresolved.

**種別:**
事実 / 未確認情報

**根拠:**
command: `git status --short --branch`

**プロジェクト内の保存先:**
`docs/handover/14-open-questions.md`, `docs/handover/16-source-index.md`

**未反映の場合のリスク:**
Useful handoff context may remain invisible or be accidentally removed.

## Context ID: AICTX-016

**内容:**
The user expects contradictions and unknowns to be named explicitly. "Probably" claims must be labeled as inference with confirmation method.

**種別:**
ユーザー希望

**根拠:**
current user prompt

**プロジェクト内の保存先:**
`docs/handover/README.md`, `docs/handover/14-open-questions.md`, `docs/handover/18-documentation-drift.md`

**未反映の場合のリスク:**
Handoff docs become a polished but unreliable summary.

## Context ID: AICTX-017

**内容:**
Memory notes used in this turn are routing/context, not a substitute for live verification. Where memory and live source conflict, live source wins.

**種別:**
方針

**根拠:**
AI memory notes, current command verification

**プロジェクト内の保存先:**
`docs/handover/16-source-index.md`, this file

**未反映の場合のリスク:**
Future readers may treat older memory as current fact.
