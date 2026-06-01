# PR #12: スタック → clean main 統合計画

## 状態

- #0〜#11 は Draft PR 化済み。
- この PR は統合計画だけ。`main` への merge / force-push / deploy はしない。
- `main` 統合はユーザーの明示承認を受けてから実行する。

## 対象スタック

`main` (`18b29b4`) から以下を順に含める。

1. #9 `veqral/foundation-multiagent`
2. #10 `veqral/usability-i18n`
3. #11 `veqral/usability-i18n-push`
4. #12 `veqral/free-device-polish`
5. #13 `codex/add-agents-handoff`
6. #14 `codex/ui-japanese-polish`
7. #15 `codex/pr1-core-fixes`
8. #16 `codex/pr-a-screen-inventory`
9. #17 `codex/pr1-surface-consolidation`
10. #18 `codex/pr2-portfolio-command-center`
11. #19 `codex/backlog-0-hermes-memory-inheritance`
12. #20 `codex/backlog-3-websocket-resume`
13. #21 `codex/backlog-4-discord-notifications`
14. #22 `codex/backlog-5-memory-visibility`
15. #23 `codex/backlog-6-run-usage`
16. #24 `codex/backlog-7-approval-context`
17. #25 `codex/backlog-8-saved-commands`
18. #26 `codex/backlog-9-host-telemetry`
19. #27 `codex/backlog-10-voice-input`

最新 tip は `codex/backlog-10-voice-input`。この branch は上記を線形に含む。

## 推奨統合手順

1. ユーザーから「main に統合してよい」という明示承認を受ける。
2. `git fetch origin`
3. `git checkout main && git pull --ff-only origin main`
4. `git checkout -b codex/main-stack-integration`
5. `git merge --no-ff origin/codex/backlog-10-voice-input`
6. conflict が出た場合は和集合で解消し、以下を必ず守る。
   - Push capability/entitlement は free team 用に OFF のまま。
   - APNs コードは温存、feature flag は OFF のまま。
   - Hermes native memory を唯一の記憶バックボーンにする。自作共有 memory/MCP は追加しない。
   - Codex/Claude の `~/.codex` / `~/.claude` は読み取り専用。
   - UI 文言は日本語主体。UUID/生パスは主表示にしない。
7. 検証を全通しする。
8. `codex/main-stack-integration` を push し、`main` 向け最終 PR を作る。
9. 最終 PR の merge もユーザー承認後に実行する。

## 統合後検証

- `swift build --package-path MacHost`
- `swift run --package-path MacHost VeqralHost verify-memory-inheritance`
- `swift run --package-path MacHost VeqralHost smoke-voice-cleanup`
- `swift run --package-path MacHost VeqralHost smoke-host-telemetry`
- `swift run --package-path MacHost VeqralHost smoke-run-usage`
- `swift run --package-path MacHost VeqralHost smoke-project-memory`
- `swift run --package-path MacHost VeqralHost smoke-discord-notifications`
- iOS Simulator build: `CODE_SIGNING_ALLOWED=NO`
- Mac Catalyst build: `CODE_SIGNING_ALLOWED=NO`
- `git diff --check`
- `plutil -lint Veqral/Info.plist Veqral/ja.lproj/Localizable.strings Veqral/en.lproj/Localizable.strings`
- Localizable missing-key check
- production grep: no new `mock/stub/fake/demo/not implemented`
- redact grep: no bearer/token/key/secret/Authorization value leaks

## 現時点の重要 findings

- #0 Hermes 記憶継承の実 LLM 証明は FAIL。テストはあるが、利用可能な 2 モデル credentials/license が揃わず、偽 pass は作っていない。多モデル継承は未証明として扱う。
- Push/APNs は free team では capability 非対応のため OFF。コードは温存。
- Discord は local smoke 済み。外部配送には実 webhook 設定が必要。
- Portfolio discover は roots/registry/controls 未設定でも動くが、実運用精度には Host env 設定が必要。
- Voice input は build 済み。マイク/Speech 権限と実 dictation は iPhone/iPad 実機確認が必要。

## 承認待ち

ここで停止する。`main` への統合・merge はユーザーの明示承認後に行う。
