# Current state

確認時点: 2026-06-23 15:44:42 JST

## Git 状態

| 項目 | 状態 | 根拠 |
|---|---|---|
| repo root | `/Users/hiroyuki/Documents/Veqral` | command: `pwd` |
| current branch | `codex/handover-package-20260623` | command: `git branch --show-current` |
| branch base | `origin/main` | command: `git switch -c codex/handover-package-20260623 origin/main` |
| latest commit | `a73d87f Merge pull request #47 from hiroyuki0504/codex/aihub-local-runtime-cleanup` | command: `git log -1 --oneline --decorate` |
| repo remote | `https://github.com/hiroyuki0504/Veqral.git` | command: `git remote -v` |
| GitHub default branch | `main` | command: `gh repo view --json ...` |
| GitHub visibility | `PUBLIC` | command: `gh repo view --json ...` |
| open GitHub issues | none returned | command: `gh issue list --state open --limit 20 --json ...` |
| open PRs in latest list | #46 and #45 draft open; #47 merged | command: `gh pr list --state all --limit 20 --json ...` |

作成前から未追跡だったファイル:

- `CURRENT_APP_HANDOFF_20260621.md`
- `CURRENT_IMPLEMENTATION_STATUS_20260606.md`
- `CURRENT_IMPLEMENTATION_STATUS_20260607.md`
- `VEQRAL_AI_HANDOFF_TEXTBOX.md`

これらはユーザー/過去作業の成果物として扱い、削除しない。

根拠:
- command: `git status --short --branch`

## 作業中断地点

この turn の目的は handover docs 作成であり、機能コード変更はしていない。作業中断点は `docs/handover/` 一式と `AGENTS.md` の文脈追記を review/stage/commit/push/draft PR する地点。

次に見るべきファイル:

1. `docs/handover/README.md`
2. `docs/handover/17-next-actions.md`
3. `docs/handover/14-open-questions.md`
4. `docs/handover/18-documentation-drift.md`

## 動作確認済みの範囲

| 分類 | コマンド/確認 | 結果 |
|---|---|---|
| Swift version | `swift --version` | Apple Swift 6.3.2 |
| Xcode version | `xcodebuild -version` | Xcode 26.5, build 17F42 |
| Xcode schemes | XcodeBuildMCP `list_schemes` / `xcodebuild -list` | `Veqral`, `VeqralWatch` |
| simulators | XcodeBuildMCP `list_sims` | iOS 26.5 / watchOS 26.5 simulators available |
| MacHost build | `swift build --package-path MacHost` | PASS |
| MacHost tests | `swift test --package-path MacHost` | PASS, 2 Redactor tests |
| Host smokes | 17 smoke commands | 全 PASS |
| iOS Simulator build | `xcodebuild ... -scheme Veqral ... iOS Simulator id=97E6... CODE_SIGNING_ALLOWED=NO build` | PASS |
| Mac Catalyst build | `xcodebuild ... -scheme Veqral ... platform=macOS,variant=Mac Catalyst CODE_SIGNING_ALLOWED=NO build` | PASS |
| Watch Simulator build | `xcodebuild ... -scheme VeqralWatch ... watchOS Simulator id=5D460... CODE_SIGNING_ALLOWED=NO build` | PASS |
| live Host health | `curl -fsS http://127.0.0.1:7878/v1/health` | `status=ok`, `port=7878`, `tailscaleIP=100.96.40.99` |
| LaunchAgent | `launchctl print gui/$(id -u)/dev.hiroyuki.veqral.host` | running, KeepAlive, RunAtLoad |
| plist/localization | `plutil -lint ...` + localization key parity command | PASS / no key diff output |
| whitespace | `git diff --check` | PASS |
| secret grep | regex grep | only known dummy/placeholder hits |
| production grep | `TODO|FIXME|...|mock|stub|fake|demo` over source | Sales Lab `mock` domain wording only |

## Host smoke results

All commands below passed on 2026-06-23:

| Command | What it protects |
|---|---|
| `swift run --package-path MacHost VeqralHost smoke-discord-notifications` | Discord payload redaction and 4 local notification payload shapes |
| `swift run --package-path MacHost VeqralHost smoke-project-memory` | Hermes project source mapping and read-only project memory |
| `swift run --package-path MacHost VeqralHost smoke-run-usage` | Claude/Codex/text usage parsing |
| `swift run --package-path MacHost VeqralHost smoke-aihub-digest-bridge` | HostState finish hook to AI-Hub session digest temp vault |
| `swift run --package-path MacHost VeqralHost smoke-host-telemetry` | CPU/load/memory/disk/thermal/process sample |
| `swift run --package-path MacHost VeqralHost smoke-voice-cleanup` | cleanup prompt and output sanitizing |
| `swift run --package-path MacHost VeqralHost smoke-cost-governance` | token/cost budget pause threshold |
| `swift run --package-path MacHost VeqralHost smoke-portfolio-real-data` | isolated sample Portfolio path when real roots unset |
| `swift run --package-path MacHost VeqralHost smoke-auth-onboarding` | provider readiness / secret hygiene marker |
| `swift run --package-path MacHost VeqralHost smoke-hermes-control` | Hermes preset/policy apply and baseURL/context handling |
| `swift run --package-path MacHost VeqralHost smoke-sales-lead-repository` | Sales lead repository JSON path |
| `swift run --package-path MacHost VeqralHost smoke-sales-import-csv` | Sales CSV import |
| `swift run --package-path MacHost VeqralHost smoke-sales-audit` | official URL audit artifact generation |
| `swift run --package-path MacHost VeqralHost smoke-sales-mock` | Sales Lab redesign artifact generation |
| `swift run --package-path MacHost VeqralHost smoke-sales-proposal` | proposal artifact generation |
| `swift run --package-path MacHost VeqralHost smoke-sales-no-autosend` | no automatic outbound sending |
| `swift run --package-path MacHost VeqralHost smoke-sales-redact` | Sales Lab redaction |

## 未確認の範囲

| 範囲 | 状態 | 理由 | 次の確認方法 |
|---|---|---|---|
| Gate2 real XCUITest script | 未実行 | `Scripts/run_gate2_xcuitests.sh` は real Hermes memory inheritance を実行するため、LLM/auth/cost/time 判断が必要 | `VEQRAL_GATE2_SKIP_DEVICES=1 VEQRAL_GATE2_ONLY=iphone-simulator Scripts/run_gate2_xcuitests.sh` |
| iPhone 実機 5 項目 | 未確認 | この turn では端末操作なし | `DEVICE_ACCEPTANCE.md` の iPhone セクション |
| iPad 実機 5 項目 | 未確認 | `devicectl` では paired/available だが `xctrace` では offline と表示 | `DEVICE_ACCEPTANCE.md` の iPad セクション |
| Watch 実機 | 未確認 | `xctrace` では offline | Watch preset/approval を実機で確認 |
| 外部 Discord webhook | 未確認 | この turn では実 webhook 送信を避けた | `VEQRAL_DISCORD_WEBHOOK` 設定後に Devices の test |
| APNs push | 未確認/未運用 | free personal team では push capability 非対応という既存記録 | 有料 Apple Developer Program 後に capability/env を設定 |
| App Store/TestFlight | 未確認 | deploy 対象ではない | Apple Developer 設定と signing を確認 |
| CI/CD | 未確認/存在確認できず | `.github` がこの checkout に存在しない | GitHub repo settings を人間が確認 |

## 実装済み機能

- Pairing QR/manual code + HMAC device token
- Remote Host health / telemetry / devices / audit
- Remote Run lifecycle: create, list, snapshot, logs, events, diff, artifacts, cancel, resume, approve, reject
- Risk approval gate
- Codex direct / Claude direct / Hermes / Shell runtime selection
- Hermes native memory visibility and project memory read-only surface
- Hermes control and vault approvals
- Cost governance
- Voice input cleanup flow
- Saved commands
- Discord notification support
- Portfolio command center
- Sales Lab MVP
- Watch approval scaffold
- AI-Hub session digest bridge

根拠:
- `AGENTS.md`
- `README.md`
- `MacHost/Sources/VeqralHost/main.swift`
- `MacHost/Sources/VeqralHost/HermesControl.swift`
- `Veqral/AppState.swift`
- Host smoke results above

## 部分実装の機能

| 機能 | 部分状態 | 根拠 |
|---|---|---|
| Watch | Simulator build PASS, 実機/cellular/APNs 未確認 | `WATCH_APPROVAL_PR_A6.md`, command: Watch build |
| APNs push | code/config path exists, feature flag/offline policyあり、実運用なし | `AGENTS.md`, `MacHost/Sources/VeqralHost/main.swift`, `Veqral/Veqral.entitlements` |
| Sales Lab Places discovery | endpoint exists but 501 disabled | `SALES_LAB_PR.md`, `MacHost/Sources/VeqralHost/main.swift` |
| Cross-vendor Hermes memory | same-provider real 2 model pass, Claude/Anthropic side blocked previously | `HERMES_CROSS_VENDOR_PR_A7.md`, `PROGRESS.md` |
| Gate2 device acceptance | script and checklistあり、今回実機未確認 | `Scripts/run_gate2_xcuitests.sh`, `DEVICE_ACCEPTANCE.md` |

## 壊れている/怪しい箇所

| 箇所 | 状態 | 根拠 | 対応 |
|---|---|---|---|
| README Hermes version | README は v0.15.1 と書くが live health は v0.17.0 | `README.md`, curl health | README drift 修正 |
| README local model policy | README に cloud-only/removed local fallback が残るが latest AGENTS/Host は AI-Hub policy/local preset を持つ | `README.md`, `AGENTS.md`, `HermesControl.swift` | 方針を lane/policy で更新 |
| `HERMES_REMOTE_CONTROL_PR.md` title | 「ローカルAI削除」とあるが #47 で local runtime policy が戻っている | `HERMES_REMOTE_CONTROL_PR.md`, `AGENTS.md` | drift として明示済み |
| local `main` branch | origin/main より 7 commit behind | command: `git status`, `git log main...origin/main` | 作業は current branch/origin/main ベースで継続 |

## 最後に失敗したコマンド

| コマンド | 失敗理由 | 影響 |
|---|---|---|
| XcodeBuildMCP `build_sim` | session defaults に scheme が未設定で、公開 tool に defaults 設定がなかった | `xcodebuild` 明示引数で代替し PASS |
| 初回 smoke loop shell | zsh の `commands` 配列名が special associative array に当たり失敗 | 実 smoke は走っていない。配列名を `smoke_cmds` に変えて全 PASS |
