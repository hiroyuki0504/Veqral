# ChatGPT mobile UX / voice crash hardening

## 目的

Veqral の必要機能を削らず、iPhone/iPad の初期動線を「開いたらすぐ指令できる」構造へ寄せた。Mac Catalyst は既存の 3 ペイン作業面を維持し、モバイルだけを単一主面 + ドロワー + 奥の設定へ整理した。

## 情報設計

| 機能 | Before | After |
| --- | --- | --- |
| 指令 / 会話 | タブ・サイドバーの一画面 | 起動直後の主面。下部 composer を常設し、上部はメニュー / エージェント選択 / 新規のみ |
| 音声入力 | composer 内の補助導線 | 下部 composer の主要アクション。録音、整形、確認、送信は同じ流れ |
| エージェント選択 | Command 内の picker | 主面上部のメニュー。Hermes / Codex / Claude / Shell を残す |
| 承認 | タブ / サイドバー | ドロワー「今日」。高リスクは既存の確認シートを維持 |
| 履歴 resume | その他配下 | ドロワー「今日」。Command 主面からすぐ戻れる |
| Projects / Hermes Chat / model | Projects 画面 | ドロワー「ワークスペース」。既存の Project / Chat / model 設定を維持 |
| 司令塔 | タブ | ドロワー「ワークスペース」。詳細機能は既存画面に遷移 |
| Memory 可視化 | その他配下 | ドロワー「ワークスペース」 + 主面のクイック導線 |
| Runs / Diff / Artifacts / GitHub | その他配下 | ドロワー「ツール」 + 実行詳細から到達 |
| Devices / pairing / telemetry / Discord test | タブ / Devices | ドロワー「システム」。Host 状態とペアリングは既存画面を維持 |
| 言語切替 | その他配下 | ドロワー「システム」内の小さな設定 |
| Mac Catalyst | 3 ペイン | 変更なし。大画面作業面を維持 |

## 削除したもの

必要機能は削除していない。今回の変更で消したのは、モバイルの旧タブ構造としての見せ方だけで、各機能は主面、ドロワー、既存詳細画面のいずれかから到達できる。

## マイク crash 対策

`NSMicrophoneUsageDescription` と `NSSpeechRecognitionUsageDescription` は既に `Info.plist` に存在した。実機 crash の主なリスクは、許可前に `AVAudioSession` / `SFSpeechRecognizer` / input tap を触ること、二重 start/stop、録音中断時の teardown 不足にあったため、以下を固めた。

- Speech と microphone の権限を先に判定し、拒否 / 制限 / 非対応は UI エラーへ落とす。
- `AVAudioSession` は許可後にだけ設定し、activate / deactivate の失敗を crash にしない。
- input tap、recognition task、audio engine、interruption observer を一箇所で teardown する。
- 多重起動と古い recognition callback を guard する。
- 音声 callback からの UI 更新は main actor に寄せる。
- UI test 用の強制エラー経路を追加し、権限拒否相当で落ちないことを検証する。

## 検証

- MacHost `swift build`
- iOS Simulator build
- Mac Catalyst build
- watchOS generic build
- Gate2 XCUITest iPhone simulator
- Gate2 XCUITest iPad simulator
- Voice permission crash UI test
- `git diff --check`
- `plutil -lint` for `Info.plist` and `Localizable.strings`
- Localizable missing-key check

## 配布メモ

| Target | Result |
| --- | --- |
| iPhone Simulator | Gate2 XCUITest で build / install / launch / automated acceptance PASS |
| iPad Simulator | Gate2 XCUITest で build / install / launch / automated acceptance PASS |
| Mac Catalyst | generic Catalyst build PASS |
| 実機 iPhone `iPhone16 Ultra Pro Max` | free team signing build PASS、install PASS。launch は端末ロックで拒否 |
| 実機 iPad `Thinkpad` | free team signing build PASS、install PASS。launch は開発者プロファイル未信頼 / code signature trust で拒否 |
| Apple Watch `ろれっくす` | generic watchOS build PASS。実機 destination は Xcode で `known architecture` 不明として ineligible |
