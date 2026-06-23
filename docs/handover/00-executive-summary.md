# Executive summary

確認時点: 2026-06-23 15:44:42 JST

## このプロジェクトは何か

Veqral は、iPhone / iPad / Mac Catalyst / Apple Watch から、自分の Mac 上で動く AI コーディングエージェントを遠隔操作する SwiftUI アプリと Swift 製 Mac Host です。

主対象エージェント:

- Codex 直接: `codex exec` / `codex exec resume`。履歴は `~/.codex`。
- Claude 直接: `claude --print` / `claude --resume`。履歴は `~/.claude`。
- Hermes 司令塔: Project / Chat / provider / model / AI-Hub policy / Hermes native memory。履歴と記憶は Hermes 側。
- Local shell: 承認 gate 下で Mac 上の `/bin/zsh` を実行。

根拠:
- `AGENTS.md`
- `README.md`
- `MacHost/Sources/VeqralHost/main.swift`
- `Veqral/AppState.swift`

## 何を解決するものか

Mac の前にいなくても、スマホ/タブレット/Watch から agent 作業を作成し、ログを見て、危険操作を承認し、Hermes の記憶・モデル方針・AI-Hub/Obsidian 承認にアクセスすることを解決する。

Veqral の差別化は、単なる remote CLI ではなく、Hermes native memory と AI-Hub/Obsidian の curated knowledge をつなぐことです。

根拠:
- `AGENTS.md`
- `CURRENT_APP_HANDOFF_20260621.md`
- memory: `/Users/hiroyuki/.codex/memories/MEMORY.md`

## 現在どこまで進んでいるか

確認済みの実装範囲:

- Mac Host は LaunchAgent で起動し、`127.0.0.1:7878` の `/v1/health` が `status=ok`。
- Tailscale IP は health 上で `100.96.40.99`。
- Host は Hermes/Codex/Claude/Shell adapter を検出。
- iOS Simulator build、Mac Catalyst build、Watch Simulator build はこの turn で成功。
- MacHost SwiftPM build/test と Host smoke 17 本はこの turn で成功。
- GitHub repo は public `hiroyuki0504/Veqral`、default branch は `main`。
- #47 `Fix Veqral redaction drift and AI-Hub policy presets` は `MERGED`。

根拠:
- command: `curl -fsS http://127.0.0.1:7878/v1/health`
- command: `launchctl print gui/$(id -u)/dev.hiroyuki.veqral.host`
- command: `swift build --package-path MacHost`
- command: `swift test --package-path MacHost`
- command: `xcodebuild -project Veqral.xcodeproj -scheme Veqral ... build`
- command: `xcodebuild -project Veqral.xcodeproj -scheme VeqralWatch ... build`
- command: `gh repo view --json nameWithOwner,url,defaultBranchRef,visibility`
- command: `gh pr list --state all --limit 20 --json ...`

## 今すぐ使えるもの

- Mac Host health / pairing / HMAC-protected API
- Remote Run create/list/snapshot/log/diff/artifact/cancel/resume/approve/reject
- WebSocket run log streaming
- Hermes control: config/preset/policy/apply
- Hermes vault approvals
- Memory visibility: Hermes `MEMORY.md` / `state.db` session read-only view
- Codex/Claude direct history viewer
- Discord notification local smoke
- Host telemetry
- Voice cleanup
- Cost governance
- Sales Lab MVP
- Watch approval scaffold and Watch simulator build

根拠:
- `AGENTS.md`
- `README.md`
- `MacHost/Sources/VeqralHost/main.swift`
- `MacHost/Sources/VeqralHost/HermesControl.swift`
- command: Host smoke command group in `16-source-index.md`

## まだ未完成のもの

- iPhone/iPad 実機 Gate2 5 項目の今回再確認
- Watch 実機 / cellular / APNs 経路
- APNs push 本番。有料 Apple Developer Program と `.p8` 等が必要。
- Claude/Anthropic を Hermes-readable subscription/login として使った cross-vendor memory proof
- Google Places official discovery。現 Sales Lab は manual/CSV のみ。
- 実外部 Discord webhook delivery の今回再確認
- CI/CD。`.github` はこの checkout に存在しない。
- App Store / TestFlight / hosted backend。現状はローカル Mac Host 運用。

根拠:
- `AGENTS.md`
- `DEVICE_ACCEPTANCE.md`
- `SALES_LAB_PR.md`
- command: `find .github -maxdepth 3 -type f -print`
- command: `gh issue list --state open --limit 20 --json ...`

## 次にやるべきこと

1. この handover package を review し、必要なら merge する。
2. README の古い記述を直す。特に Hermes v0.15.1、cloud-only/local-model 方針、Operational Gaps。
3. `DEVICE_ACCEPTANCE.md` に沿って iPhone/iPad 実機 5 項目を確認する。
4. Gate2 XCUITest runner を実行するか判断する。real LLM 実走を含むため、実行前に目的を明確化する。
5. #A7 cross-vendor memory は Hermes-readable Claude/Anthropic login が復旧してから再実走する。
6. Sales Lab の Google Places official discovery は API key / quota / terms を確認してから別 PR。

根拠:
- `docs/handover/17-next-actions.md`
- `docs/handover/14-open-questions.md`

## 最大のリスク

最大のリスクは、Veqral / Hermes / AI-Hub / Obsidian / Codex / Claude の正本が複数あるのに、古い docs や AI 記憶を現在の実態として扱ってしまうことです。

特に危険:

- README と最新 AGENTS/実装の方針が一部ずれている。
- `~/.codex` と `~/.claude` は read-only の履歴正本であり、編集してはいけない。
- Hermes memory は native memory/session が正本であり、自作共有 memory を作ってはいけない。
- secret 値は Keychain/env/auth file にあり、docs に書いてはいけない。
- `Scripts/run_gate2_xcuitests.sh` は real Hermes memory inheritance を走らせる。

根拠:
- `AGENTS.md`
- `README.md`
- `Scripts/run_gate2_xcuitests.sh`
- `docs/handover/18-documentation-drift.md`

## 絶対に見落としてはいけないこと

- 現在の作業ブランチは `codex/handover-package-20260623`。`main` へ直コミットしない。
- この turn で機能コードは変更していない。
- 既存の未追跡 handoff ファイルは作成前から存在した。消さない。
- `docs/handover/15-ai-context-export.md` に AI 文脈を外部化済み。
- 未確認事項は `docs/handover/14-open-questions.md` に集約済み。
