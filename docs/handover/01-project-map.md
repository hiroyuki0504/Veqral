# Project map

確認時点: 2026-06-23 15:44:42 JST

## 主要ディレクトリツリー

```text
/Users/hiroyuki/Documents/Veqral
├── AGENTS.md
├── README.md
├── docs/handover/
├── MacHost/
│   ├── Package.swift
│   ├── Sources/
│   │   ├── VeqralHost/
│   │   ├── VeqralHostSmoke/
│   │   └── VeqralShared/
│   └── Tests/
│       └── VeqralSharedTests/
├── Scripts/
│   └── run_gate2_xcuitests.sh
├── Veqral/
│   ├── AppState.swift
│   ├── CommandCenterViews.swift
│   ├── Screens.swift
│   ├── Models.swift
│   ├── RootView.swift
│   ├── Components.swift
│   ├── Theme.swift
│   ├── PushNotifications.swift
│   ├── Info.plist
│   ├── Veqral.entitlements
│   ├── ja.lproj/Localizable.strings
│   └── en.lproj/Localizable.strings
├── Veqral.xcodeproj/
├── VeqralUITests/
└── VeqralWatch/
```

根拠:
- command: `find . -maxdepth 3 -type d ...`
- command: `rg --files ...`

## パス別役割

| パス | 種別 | 役割 | 正本か | 関連先 | 注意 |
|---|---|---|---|---|---|
| `AGENTS.md` | handover / policy | Veqral の確定原則、実装履歴、次の手番 | はい | 全 docs / AI context | 大きな変更後に更新する。 |
| `README.md` | user/dev overview | 概要、起動、基本 build 手順 | 部分的 | `18-documentation-drift.md` | 一部古い。現在状態の正本にはしない。 |
| `docs/handover/` | handover package | 今回作成した引き継ぎ正本 | はい | `AGENTS.md`, 実装, 検証結果 | 今後の引き継ぎ入口。 |
| `MacHost/Package.swift` | SwiftPM manifest | Host, smoke, shared redactor target 定義 | はい | `MacHost/Sources/*` | 外部 package dependency はない。 |
| `MacHost/Sources/VeqralHost/main.swift` | backend / daemon | Mac Host app, HTTP API, Run, pairing, state, smokes | はい | `Veqral/AppState.swift` | 大型ファイル。route 変更は App 側 client と docs も更新。 |
| `MacHost/Sources/VeqralHost/HermesControl.swift` | backend / integration | Hermes config/preset/policy/vault approvals | はい | AI-Hub, Obsidian vault | `VEQRAL_HERMES_VAULT` 未設定だと presets/approvals は無効。 |
| `MacHost/Sources/VeqralHostSmoke/main.swift` | CLI smoke | `verify-memory-inheritance` | はい | `Scripts/run_gate2_xcuitests.sh` | real LLM/auth を使う。 |
| `MacHost/Sources/VeqralShared/VeqralRedactor.swift` | shared code | secret/webhook/token redaction | はい | Host, app, tests | secret 漏洩防止の共通部品。 |
| `MacHost/Tests/VeqralSharedTests/` | SwiftPM tests | Redactor tests | はい | `VeqralRedactor.swift` | 現時点の単体テストは 2 件。 |
| `Scripts/run_gate2_xcuitests.sh` | verification script | Gate2 XCUITest runner | はい | Xcode, Host, Hermes smoke | real Hermes memory inheritance を含む。 |
| `Veqral/AppState.swift` | app state / client | persistence, app model, RemoteHostClient, Keychain | はい | Host routes | API caller の正本。 |
| `Veqral/Screens.swift` | SwiftUI screens | Portfolio, Devices, Memory, Approvals, Hermes control, Sales Lab | はい | `AppState.swift` | UI の多くが集約。 |
| `Veqral/CommandCenterViews.swift` | SwiftUI shell | command center layout / responsive UI | はい | `RootView.swift`, `Screens.swift` | iPhone/iPad/Catalyst の見た目に影響。 |
| `Veqral/Models.swift` | UI navigation model | AppSection / tabs / groups | はい | `RootView.swift` | 新画面追加時に更新。 |
| `Veqral/RootView.swift` | root navigation | section destination / layout branching | はい | `Models.swift`, `Screens.swift` | Mac Catalyst 3 pane に関係。 |
| `Veqral/Components.swift` | UI components | panels, pills, QR/camera bridge | はい | screens | `fatalError(init(coder:))` は storyboard 非対応 initializer。 |
| `Veqral/Theme.swift` | UI theme | colors / typography helpers | はい | all UI | UI polish 時に参照。 |
| `Veqral/PushNotifications.swift` | local/push notification model | local notification categories/actions | はい | Host push token/API | APNs capability は現在 off/未運用。 |
| `Veqral/Info.plist` | app config | URL scheme, privacy usage strings, ATS | はい | Xcode build | `NSAllowsArbitraryLoads=true` は Tailscale/local Host 用。 |
| `Veqral/Veqral.entitlements` | entitlement | `aps-environment` placeholder | 部分的 | APNs future | push capability は free team では実運用不可。 |
| `Veqral/ja.lproj/Localizable.strings` | localization | Japanese strings | はい | `Localization.swift` | en と key parity 確認済み。 |
| `Veqral/en.lproj/Localizable.strings` | localization | English strings | はい | `Localization.swift` | `.xcstrings` ではない。 |
| `VeqralUITests/Gate2AcceptanceUITests.swift` | UI test | Gate2 acceptance scenario | はい | `Scripts/run_gate2_xcuitests.sh` | 実行 script は real Hermes smoke も先に走る。 |
| `VeqralWatch/VeqralWatchApp.swift` | Watch app | Watch approval/preset UI/client | はい | Host Hermes endpoints | Simulator build は PASS。実機未確認。 |
| `Veqral.xcodeproj/project.pbxproj` | Xcode project | targets/schemes/build settings | はい | Xcode | 手編集はリスク。scheme は `Veqral`, `VeqralWatch`。 |
| `.gitignore` | git config | DerivedData/.build/.worktrees 等を除外 | はい | workspace | `.worktrees/` は無視。 |
| `.worktrees/` | generated/local worktrees | local worktree storage | いいえ | git worktree | 編集/commit 対象外。 |
| `CURRENT_APP_HANDOFF_20260621.md` | untracked handoff | 2026-06-21 の実環境 handoff | 参考 | `docs/handover/15-ai-context-export.md` | 作成前から未追跡。勝手に削除しない。 |
| `CURRENT_IMPLEMENTATION_STATUS_20260606.md` | untracked handoff | dated status | 参考 | older worktrees | 作成前から未追跡。古い可能性あり。 |
| `CURRENT_IMPLEMENTATION_STATUS_20260607.md` | untracked handoff | dated status | 参考 | older worktrees | 作成前から未追跡。古い可能性あり。 |
| `VEQRAL_AI_HANDOFF_TEXTBOX.md` | untracked prompt/handoff | 長文 handoff / prompt | 参考 | AI context | 古い branch 名を含む。正本ではない。 |
| `LICENSE` | legal | MIT license | はい | repo | Public repo。 |

## 生成物と手書きファイル

| パス | 生成/手書き | 扱い |
|---|---|---|
| `docs/handover/*.md` | 手書き | 今後更新対象。 |
| `*.md` at repo root | 手書き | PRごとの記録。古いものは日付/branch を見て扱う。 |
| `MacHost/.build/` | 生成物 | `.gitignore` 対象。消してよい。 |
| `DerivedData/` | 生成物 | `.gitignore` 対象。消してよい。 |
| `~/Library/Developer/Xcode/DerivedData/Veqral-*` | 生成物 | repo 外。build cache。消してよい。 |
| `~/.veqral-host/*` | runtime state | 消す前に backup。Host の runs/devices/config/logs を含む。 |
| `~/.codex`, `~/.claude`, `~/.hermes` | external native state | 読み取り中心。Veqral docs から勝手に編集/削除しない。 |

## 編集してよい/触るべきでない

| 対象 | 方針 |
|---|---|
| `docs/handover/` | 引き継ぎ更新時に編集してよい。 |
| `AGENTS.md` | 大きな変更の最後に現在地/次手番だけ更新する。 |
| `README.md` | drift 解消 PR で更新候補。 |
| `MacHost/Sources/*`, `Veqral/*.swift`, `VeqralWatch/*.swift` | 機能変更時のみ。docs-only PR では触らない。 |
| `Veqral.xcodeproj/project.pbxproj` | Xcode target/file 追加時のみ慎重に。 |
| `~/.codex`, `~/.claude` | read-only。編集/削除しない。 |
| `~/.hermes/auth.json` | secret/auth。docs に値を書かない。直接編集しない。 |
| `~/Library/LaunchAgents/dev.hiroyuki.veqral.host.plist` | deploy/Host 再配備時のみ。docs-only では読むだけ。 |
