# Veqral Backlog Progress

This file is the resume point for the clean main baseline. The former stacked Draft PR backlog is now integrated into `main`.

## Status

- [x] #0 Hermes 記憶継承の自動実証 — real 2-model Hermes native-memory pass recorded in PR #29 (`codex/gates-hermes-device-acceptance`)
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
- [x] #12 スタック→clean main 統合（ユーザー承認制） — completed after explicit GO via `codex/main-stack-integration-20260601`

## Current Item

#A2 記憶の体験化（差別化の堀）

## Differentiation Backlog

- [x] #A0 コード実査監査 — `AUDIT.md` を追加し、Discord 2xx 実判定、Host/Hermes test isolation、redact 追加、Portfolio DELETE fail-closed を修正。Draft PR: `codex/a0-code-audit`
- [x] #A1 Gate2 自動受け入れ — XCUITest target と `Scripts/run_gate2_xcuitests.sh` を追加。saved command / telemetry / memory visibility / Discord 2xx / voice transcript approval gate は iPhone/iPad simulator で PASS。実機 XCUITest は local Xcode account/provisioning 未設定で BLOCKED（`dev.hiroyuki.veqral.ui-tests.xctrunner` profile なし、CLI から Xcode Accounts が見えない）として `GATE2_XCUITEST_ACCEPTANCE_PR_A1.md` に記録。
- [ ] #A2 記憶の体験化
- [ ] #A3 コストガバナンス
- [ ] #A4 司令塔を実データで
- [ ] #A5 認証オンボーディング・ウィザード
- [ ] #A6 Apple Watch 承認アプリ
- [ ] #A7 クロスベンダー #0 再実走
- [ ] Final main 統合（ユーザー GO 後のみ）

## Notes

- #0 report: `HERMES_MEMORY_INHERITANCE_PR0.md`.
- #0 current result: PASS. `verify-memory-inheritance` ran with isolated `HERMES_HOME`, Hermes native memory only, and `openai-codex/gpt-5.5 -> openai-codex/gpt-5.4`; Chat A wrote a disposable code name to Hermes `MEMORY.md`, and Chat B returned the same value. The latest transcript is in `HERMES_MEMORY_INHERITANCE_PR0.md`.
- Main integration: #9〜#29 landed into clean `main` in one union integration after user GO. Backup branch: `pre-portfolio-main-20260601-061622`. Integration branch: `codex/main-stack-integration-20260601`.
- #0 backend decision: Hermes can drive ChatGPT subscription login through `openai-codex` when `~/.hermes/auth.json` is available. The smoke links that auth file into the disposable `HERMES_HOME` instead of copying credentials or using API keys. Claude/Anthropic login is not currently usable on this Mac, and local Ollama is not running at `127.0.0.1:11434`.
- #0 model rationale: same-provider model swap is weaker than cross-vendor Claude/GPT, but it satisfies the accepted A≠B route because both are real monthly-login models and the native memory fact crossed from `gpt-5.5` to `gpt-5.4`. Cross-vendor can be rerun later after Hermes-readable Claude auth is restored.
- Gate2 device acceptance checklist is in `DEVICE_ACCEPTANCE.md`. It covers iPhone/iPad tap checks for voice input, host telemetry, saved command drafts, Discord webhook delivery, and Hermes memory visibility. Light instrumentation added in this branch: Discord test notification, telemetry failure message, and Memory last fetch time.
- Gate2 XCUITest automation is documented in `GATE2_XCUITEST_ACCEPTANCE_PR_A1.md`. Simulator acceptance is green for the five automatable items. Physical XCUITest is blocked by local Xcode signing/account state: no CLI-visible Apple account, no provisioning profiles, and physical devices currently appear offline in `xcrun xctrace list devices`. Rerun `VEQRAL_GATE2_ONLY=iphone-device Scripts/run_gate2_xcuitests.sh` and `VEQRAL_GATE2_ONLY=ipad-device Scripts/run_gate2_xcuitests.sh` after reconnecting devices and adding the Apple account in Xcode Settings.
- #3 reconnect/resume implementation is documented in `WEBSOCKET_RECONNECT_PR3.md`. Manual device smoke is still needed for real network interruption.
- #4 Discord implementation is documented in `DISCORD_NOTIFICATIONS_PR4.md`. Local Host smoke passed with 4 redacted payloads; external Discord delivery still needs a real webhook URL configured on the paired Host.
- #5 Memory visibility is documented in `MEMORY_VISIBILITY_PR5.md`. Host smoke passed; paired-device confirmation after a real Hermes Project chat is still needed.
- #6 Run usage is documented in `RUN_USAGE_PR6.md`. Host parser smoke passed for Claude stream JSON, Codex usage JSON, and usage text. Run details now show input/output/reasoning/cache/total tokens and estimated/actual cost when the Host can derive them.
- #7 Approval context is documented in `APPROVAL_CONTEXT_PR7.md`. High-risk approve now opens a review sheet with command text and linked diff/file context before approval is sent.
- #8 Saved command drafts are documented in `SAVED_COMMANDS_PR8.md`. Command composer now saves reusable drafts, restores them by tap, and writes a best-effort iCloud Documents cache with local fallback.
- #9 Host telemetry is documented in `HOST_TELEMETRY_PR9.md`. Mac Host now serves authenticated telemetry, health includes an initial snapshot, and Devices polls CPU/memory/disk/thermal/uptime/power/network/process data every 5 seconds while visible. Raw temperature/fan remain best-effort and show `—` when unavailable.
- #10 Voice input is documented in `VOICE_INPUT_PR10.md`. Composer mic opens a confirmation sheet with iOS Speech dictation, local filler/self-correction cleanup, Host LLM cleanup via existing agent CLIs, editable cleaned command, and final send through `submitDraft()`.
- #12 Integration execution is documented in `MAIN_INTEGRATION_PLAN_PR12.md`. Future work should branch from clean `main`, not the former 20-step stack.
