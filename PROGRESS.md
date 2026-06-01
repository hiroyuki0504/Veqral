# Veqral Backlog Progress

This file is the resume point for the run-until-done backlog. Each item is one logical stacked Draft PR.

## Status

- [x] #0 Hermes 記憶継承の自動実証 — completed in PR #19 (`codex/backlog-0-hermes-memory-inheritance`) with an honest FAIL result
- [x] #1 UI/UX 洗練 — completed earlier in PR #14 (`codex/ui-japanese-polish`)
- [x] #2 残4件の統合 — completed in PR #17 (`codex/pr1-surface-consolidation`)
- [x] #3 WebSocket 再接続 + Run resume — completed in PR #20 (`codex/backlog-3-websocket-resume`)
- [x] #4 通知（Discord webhook） — completed in PR #21 (`codex/backlog-4-discord-notifications`)
- [x] #5 記憶の可視化（Memory 画面で実 project memory 表示） — completed in PR #22 (`codex/backlog-5-memory-visibility`)
- [x] #6 Run コスト/トークン表示 — completed in PR #23 (`codex/backlog-6-run-usage`)
- [x] #7 承認時に diff/コマンド表示 — completed in PR #24 (`codex/backlog-7-approval-context`)
- [x] #8 定型コマンドの保存/再送 — completed in PR #25 (`codex/backlog-8-saved-commands`)
- [x] #9 Mac ホストテレメトリ — completed in PR #26 (`codex/backlog-9-host-telemetry`)
- [x] #10 音声入力 P0 — completed in PR #27 (`codex/backlog-10-voice-input`)
- [x] #11 司令塔（ポートフォリオ層）フル実装 — completed in PR #18 (`codex/pr2-portfolio-command-center`)
- [ ] #12 スタック→clean main 統合（ユーザー承認制）

## Current Item

#12 スタック→clean main 統合（ユーザー承認制）

## Notes

- #0 report: `HERMES_MEMORY_INHERITANCE_PR0.md`.
- #0 result: FAIL. The smoke test is reproducible and uses an isolated `HERMES_HOME`, but the available model routes could not complete a live two-model run: `copilot/gpt-4o-mini` and `copilot/claude-haiku-4.5` were rejected as not licensed/authorized. Earlier default route attempts also failed because isolated `openai-codex` auth was unavailable and `anthropic/claude-sonnet-4-6` rejected the configured API key. No fake pass was created.
- #3 reconnect/resume implementation is documented in `WEBSOCKET_RECONNECT_PR3.md`. Manual device smoke is still needed for real network interruption.
- #4 Discord implementation is documented in `DISCORD_NOTIFICATIONS_PR4.md`. Local Host smoke passed with 4 redacted payloads; external Discord delivery still needs a real webhook URL configured on the paired Host.
- #5 Memory visibility is documented in `MEMORY_VISIBILITY_PR5.md`. Host smoke passed; paired-device confirmation after a real Hermes Project chat is still needed.
- #6 Run usage is documented in `RUN_USAGE_PR6.md`. Host parser smoke passed for Claude stream JSON, Codex usage JSON, and usage text. Run details now show input/output/reasoning/cache/total tokens and estimated/actual cost when the Host can derive them.
- #7 Approval context is documented in `APPROVAL_CONTEXT_PR7.md`. High-risk approve now opens a review sheet with command text and linked diff/file context before approval is sent.
- #8 Saved command drafts are documented in `SAVED_COMMANDS_PR8.md`. Command composer now saves reusable drafts, restores them by tap, and writes a best-effort iCloud Documents cache with local fallback.
- #9 Host telemetry is documented in `HOST_TELEMETRY_PR9.md`. Mac Host now serves authenticated telemetry, health includes an initial snapshot, and Devices polls CPU/memory/disk/thermal/uptime/power/network/process data every 5 seconds while visible. Raw temperature/fan remain best-effort and show `—` when unavailable.
- #10 Voice input is documented in `VOICE_INPUT_PR10.md`. Composer mic opens a confirmation sheet with iOS Speech dictation, local filler/self-correction cleanup, Host LLM cleanup via existing agent CLIs, editable cleaned command, and final send through `submitDraft()`.
- #1/#2/#11 are marked done because they already exist as stacked Draft PRs in this repository.
- #12 must stop at "merge plan ready, waiting for explicit user approval"; no automatic main merge.
