# Veqral Backlog Progress

This file is the resume point for the run-until-done backlog. Each item is one logical stacked Draft PR.

## Status

- [x] #0 Hermes 記憶継承の自動実証 — completed in PR #19 (`codex/backlog-0-hermes-memory-inheritance`) with an honest FAIL result
- [x] #1 UI/UX 洗練 — completed earlier in PR #14 (`codex/ui-japanese-polish`)
- [x] #2 残4件の統合 — completed in PR #17 (`codex/pr1-surface-consolidation`)
- [x] #3 WebSocket 再接続 + Run resume — completed in PR #20 (`codex/backlog-3-websocket-resume`)
- [x] #4 通知（Discord webhook） — completed in PR #21 (`codex/backlog-4-discord-notifications`)
- [ ] #5 記憶の可視化（Memory 画面で実 project memory 表示）
- [ ] #6 Run コスト/トークン表示
- [ ] #7 承認時に diff/コマンド表示
- [ ] #8 定型コマンドの保存/再送
- [ ] #9 Mac ホストテレメトリ
- [ ] #10 音声入力 P0
- [x] #11 司令塔（ポートフォリオ層）フル実装 — completed in PR #18 (`codex/pr2-portfolio-command-center`)
- [ ] #12 スタック→clean main 統合（ユーザー承認制）

## Current Item

#5 記憶の可視化（Memory 画面で実 project memory 表示）

## Notes

- #0 report: `HERMES_MEMORY_INHERITANCE_PR0.md`.
- #0 result: FAIL. The smoke test is reproducible and uses an isolated `HERMES_HOME`, but the available model routes could not complete a live two-model run: `copilot/gpt-4o-mini` and `copilot/claude-haiku-4.5` were rejected as not licensed/authorized. Earlier default route attempts also failed because isolated `openai-codex` auth was unavailable and `anthropic/claude-sonnet-4-6` rejected the configured API key. No fake pass was created.
- #3 reconnect/resume implementation is documented in `WEBSOCKET_RECONNECT_PR3.md`. Manual device smoke is still needed for real network interruption.
- #4 Discord implementation is documented in `DISCORD_NOTIFICATIONS_PR4.md`. Local Host smoke passed with 4 redacted payloads; external Discord delivery still needs a real webhook URL configured on the paired Host.
- #1/#2/#11 are marked done because they already exist as stacked Draft PRs in this repository.
- #12 must stop at "merge plan ready, waiting for explicit user approval"; no automatic main merge.
