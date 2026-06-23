# Documentation drift and contradiction log

確認時点: 2026-06-23 15:44:42 JST

This file exists because the user explicitly requested contradictions between existing docs and implementation to be recorded. It is separate from `13-known-issues-and-risks.md` so doc maintenance can be handled as a focused follow-up.

| ID | ドキュメント上の記述 | 実態 | 根拠 | 対応案 | 優先度 |
|---|---|---|---|---|---|
| DRIFT-001 | `README.md` refers to Hermes v0.15.1-era setup/status | live Host health reports Hermes Agent v0.17.0, upstream bb7ff7dc | `README.md`, command: `curl -fsS http://127.0.0.1:7878/v1/health` | update README to version-neutral health check or current dated version | P1 |
| DRIFT-002 | `README.md` still contains cloud-only / local fallback removed language in places | current `AGENTS.md` and Host support AI-Hub policy lanes and local Ollama-compatible presets via resolver | `README.md`, `AGENTS.md`, `MacHost/Sources/VeqralHost/HermesControl.swift` | rewrite model section around AI-Hub policy/lane resolver | P1 |
| DRIFT-003 | `HERMES_REMOTE_CONTROL_PR.md` title says local AI deletion/removal | later #47 `codex/aihub-local-runtime-cleanup` restored local runtime via policy lanes | `HERMES_REMOTE_CONTROL_PR.md`, `AGENTS.md`, `HermesControl.swift` | add note at top of old PR doc or supersede with current policy doc | P2 |
| DRIFT-004 | Some older PR/status docs mention watchOS 26.5 platform unavailable | current environment has watchOS 26.5 simulator and `VeqralWatch` simulator build PASS | `WATCH_APPROVAL_PR_A6.md`, command: Watch Simulator build | update Watch status: simulator build now passes; real Watch still unverified | P2 |
| DRIFT-005 | `Scripts/run_gate2_xcuitests.sh` has hard-coded default simulator/device destination IDs | successful handover builds used explicit currently available simulator IDs, not the script defaults | `Scripts/run_gate2_xcuitests.sh`, xcodebuild commands | before running Gate2, either refresh defaults or pass `VEQRAL_GATE2_*_DEST` env vars | P2 |
| DRIFT-006 | Root has several untracked status/handoff files outside canonical docs | they are not part of tracked current docs and may duplicate/stale-context the handover | command: `git status --short --branch` | review and either import useful facts or archive/delete with explicit user approval | P2 |
| DRIFT-007 | Local `main` branch at task start was behind `origin/main` by 7 commits | current handover branch is based on `origin/main`; local `main` should not be treated as current | command: `git status`, `git log main...origin/main` | fetch/switch from `origin/main` for new work; optionally fast-forward local main later | P1 |
| DRIFT-008 | Existing docs say Gate2 XCUITest has passed in prior integration | this handover did not rerun Gate2 script; only builds/smokes/live health passed | prior docs, this command log | keep prior pass as historical; do not claim current Gate2 pass until rerun | P1 |

## Resolution policy

When a drift row is fixed:

1. Patch the stale source doc.
2. Run appropriate verification.
3. Move the row to a resolved section or update its `対応案` with the fixing commit/PR.
