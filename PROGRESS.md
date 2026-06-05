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

- [x] #45 finalization: `codex/minimal-mac-terminal-shell` is the active final branch for the direct Codex/Claude client reposition. The missing #42 voice crash hardening was audited and manually folded into this branch.
- [x] Voice hardening in #45: mic tap only opens the sheet, the sheet no longer auto-starts recording, mic/Speech permission callbacks return on the main actor, iOS 17+ uses `AVAudioApplication.requestRecordPermission`, first grant only warms up permissions, and real capture uses `AVAudioRecorder` Linear PCM `.caf` followed by `SFSpeechURLRecognitionRequest` transcription. The old live `AVAudioEngine.installTap` path is removed.
- [x] #45 verification: MacHost `swift build`, iOS Simulator build, Mac Catalyst build, watchOS generic build, voice grant/deny/error/recording-indicator XCUITest on iPhone Simulator and iPad Simulator, and Host smokes all pass. Production grep has expected Sales Lab "mock redesign" domain-word hits only; secret grep has the expected smoke placeholder hit only.
- [x] #45 simulator/Catalyst distribution: rebuilt the iOS Simulator app at `/tmp/veqral-ios-distribution`, installed and launched it on iPhone 17 Pro Simulator and iPad Pro 13-inch Simulator, and launched the Mac Catalyst app. All three processes are running from the latest #45 build.
- [ ] #45 real-device distribution and acceptance: iPhone, iPad, and Watch were visible to Xcode as offline/unavailable and not present on USB, so real-device install could not be refreshed in this run. When devices are connected/unlocked/trusted, rebuild/install/launch on real iPhone/iPad. Real microphone audio still needs the one human tap-through because XCUITest cannot inject hardware microphone audio. Required manual path: mic opens sheet without crash -> Start Recording handles Speech permission without crash -> Start Recording handles microphone permission without crash -> Start Recording shows red dot/timer/level -> Stop transcribes or enters editable Ready fallback -> deny path does not crash.
- [ ] #45 main landing: wait for explicit user GO after real-device voice/direct-client acceptance. Do not merge or push main before that.

Clean main baseline before #45: #A0〜#A7 were union-integrated after explicit user GO via `codex/final-a-union-20260602`.

## Audit / Differentiation Backlog

- [x] #A0 コード実査監査 — Draft PR #30 (`codex/a0-code-audit`), `AUDIT.md`
- [x] #A1 Gate2 自動受け入れ — Draft PR #31 (`codex/a1-gate2-xcuitest`), XCUITest harness and runner
- [x] #A2 記憶の体験化 — Draft PR #32 (`codex/a2-memory-experience`), Hermes-native memory query/handoff
- [x] #A3 コストガバナンス — Draft PR #33 (`codex/a3-cost-governance`), project budget guard
- [x] #A4 司令塔を実データで — Draft PR #34 (`codex/a4-portfolio-real-data`), isolated sample acceptance when real roots unset
- [x] #A5 認証オンボーディング — Draft PR #35 (`codex/a5-auth-onboarding`), login readiness and Keychain markers
- [x] #A6 Apple Watch 承認アプリ — Draft PR #36 (`codex/a6-watch-approval`), Watch UI scaffolded with honest watchOS/APNs partials
- [x] #A7 クロスベンダー #0 再実走 — Draft PR #37 (`codex/a7-cross-vendor-memory`), blocked before LLM execution because Hermes-readable Claude/Anthropic subscription login is not restored. See `HERMES_CROSS_VENDOR_PR_A7.md`.
- [x] Final main 統合 — completed after explicit user GO via `codex/final-a-union-20260602`

## Notes

- #0 report: `HERMES_MEMORY_INHERITANCE_PR0.md`.
- #0 current result: PASS. `verify-memory-inheritance` ran with isolated `HERMES_HOME`, Hermes native memory only, and `openai-codex/gpt-5.5 -> openai-codex/gpt-5.4`; Chat A wrote a disposable code name to Hermes `MEMORY.md`, and Chat B returned the same value. The latest transcript is in `HERMES_MEMORY_INHERITANCE_PR0.md`.
- Main integration: #9〜#29 landed into clean `main` in one union integration after user GO. Backup branch: `pre-portfolio-main-20260601-061622`. Integration branch: `codex/main-stack-integration-20260601`.
- Final A integration: #A0〜#A7 landed into clean `main` in one union integration after user GO. Backup branch/tag: `pre-a-diff-main-20260602-004405`. Integration branch: `codex/final-a-union-20260602`.
- Gate2 automated acceptance: PASS on iPhone Simulator and iPad Simulator via `Scripts/run_gate2_xcuitests.sh`. The voice sheet Stop control was made easier to hit and guarded against duplicate cleanup so injected-transcript cleanup reaches the approval gate reliably.
- #0 backend decision: Hermes can drive ChatGPT subscription login through `openai-codex` when `~/.hermes/auth.json` is available. The smoke links that auth file into the disposable `HERMES_HOME` instead of copying credentials or using API keys. Claude/Anthropic login is not currently usable on this Mac, and local Ollama is not running at `127.0.0.1:11434`.
- #0 model rationale: same-provider model swap is weaker than cross-vendor Claude/GPT, but it satisfies the accepted A≠B route because both are real monthly-login models and the native memory fact crossed from `gpt-5.5` to `gpt-5.4`. Cross-vendor can be rerun later after Hermes-readable Claude auth is restored.
- #A7 cross-vendor result: attempted `anthropic/claude-haiku-4-5 -> openai-codex/gpt-5.5` as subscription/login auth only. The verifier did not run the LLMs because the Claude side reports logged out when API-key environment is removed. This is recorded in `HERMES_CROSS_VENDOR_PR_A7.md` and appended to `HERMES_MEMORY_INHERITANCE_PR0.md`; no fake pass was created.
- Gate2 device acceptance checklist is in `DEVICE_ACCEPTANCE.md`. It covers iPhone/iPad tap checks for voice input, host telemetry, saved command drafts, Discord webhook delivery, and Hermes memory visibility. Light instrumentation added in this branch: Discord test notification, telemetry failure message, and Memory last fetch time.
- #3 reconnect/resume implementation is documented in `WEBSOCKET_RECONNECT_PR3.md`. Manual device smoke is still needed for real network interruption.
- #4 Discord implementation is documented in `DISCORD_NOTIFICATIONS_PR4.md`. Local Host smoke passed with 4 redacted payloads; external Discord delivery still needs a real webhook URL configured on the paired Host.
- #5 Memory visibility is documented in `MEMORY_VISIBILITY_PR5.md`. Host smoke passed; paired-device confirmation after a real Hermes Project chat is still needed.
- #6 Run usage is documented in `RUN_USAGE_PR6.md`. Host parser smoke passed for Claude stream JSON, Codex usage JSON, and usage text. Run details now show input/output/reasoning/cache/total tokens and estimated/actual cost when the Host can derive them.
- #7 Approval context is documented in `APPROVAL_CONTEXT_PR7.md`. High-risk approve now opens a review sheet with command text and linked diff/file context before approval is sent.
- #8 Saved command drafts are documented in `SAVED_COMMANDS_PR8.md`. Command composer now saves reusable drafts, restores them by tap, and writes a best-effort iCloud Documents cache with local fallback.
- #9 Host telemetry is documented in `HOST_TELEMETRY_PR9.md`. Mac Host now serves authenticated telemetry, health includes an initial snapshot, and Devices polls CPU/memory/disk/thermal/uptime/power/network/process data every 5 seconds while visible. Raw temperature/fan remain best-effort and show `—` when unavailable.
- #10 Voice input is documented in `VOICE_INPUT_PR10.md`. Composer mic opens a confirmation sheet with iOS Speech dictation, local filler/self-correction cleanup, Host LLM cleanup via existing agent CLIs, editable cleaned command, and final send through `submitDraft()`.
- #12 Integration execution is documented in `MAIN_INTEGRATION_PLAN_PR12.md`. Future work should branch from clean `main`, not the former 20-step stack.
- #45 branch convergence: `codex/minimal-mac-terminal-shell` supersedes the older reposition follow-up. `codex/chatgpt-mobile-ux-voice-fix` is treated as the source of the voice hardening now folded into #45; `codex/direct-clients-reposition`/#43 is replaced by #45; swarm branches #38〜#41 remain parked/closed rather than part of the direct-client baseline.
