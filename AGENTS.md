# Veqral 引継ぎ（Codex 用）

## あなたの役割

Veqral の主実装者。このプロジェクトはあなた（Codex）が `codex exec` 経由で実装してきた。以後も実装を担当する。

## Veqral とは

iPhone/iPad から、自分の Mac 上で動く AI コーディングエージェント（Codex / Claude Code / Hermes）を遠隔操作する「AI エージェント司令アプリ」。SwiftUI ネイティブ（iOS + iPad + Mac Catalyst）+ Swift 製の Mac Host。競合は CC Pocket（Codex/Claude 遠隔操作の OSS）。差別化は Hermes による記憶オーケストレーション。

## 構造（確定）

```text
Device(Mac)
└── エージェント選択
    ├── Codex 直接   : codex exec / codex exec resume。~/.codex の履歴。siloed
    ├── Claude 直接  : claude --print / claude --resume。~/.claude の履歴。siloed
    └── Hermes 司令塔 : Project → Chat(複数)。--source veqral-<projectID> + Hermes native memory + --provider/--model
```

## 確定原則（守る）

- 記憶/履歴のバックボーンは Hermes 本体（native memory/session）。自作の共有メモリや MCP は作らない。
- 2 モード：直接(Codex/Claude)=各自 siloed ／ Hermes=project 単位で記憶共有・chat 跨ぎで継承。
- 多モデルは Hermes 路線。記憶は Hermes 側にあるからモデルを差し替えても継承される（モデル=差し替え可能なエンジン、記憶=Hermes が持つ土台）。
- Codex/Claude の履歴ファイル（`~/.codex`, `~/.claude`）は読み取り専用。編集/削除しない。
- 既存インフラ（Mac Host PTY streaming / Run API: create・stream・cancel・resume / 承認 / redact / Keychain / 履歴ビューア / 更新耐性 adapter）を再利用。作り直さない。
- 組織化（PM/ロール/delegation）は段階的に後で（今は worker 段階）。データ構造に無理な前提を作らない。

## 安全・承認ポリシー

- 自動可：read/edit/create files、test/build/lint、git add/commit/branch/non-main push、draft PR。
- 要承認（高 severity）：delete、main への push/merge/force-push、deploy、`.env`/secrets/token、billing、Computer Use、予算超過。
- 秘密は Keychain/権限制限、ログは redact。main マージはユーザーの明示承認が必須。

## 技術・場所

- repo: `github.com/hiroyuki0504/Veqral`、ローカル `/Users/hiroyuki/Documents/Veqral`
- Mac Host: LaunchAgent 起動、`100.96.40.99:7878`（Tailscale）。pairing は QR(`veqral://pair?...`) + HMAC + device token
- iOS 署名: free personal team（push 以外は実機で動く）。実機は USB + Trust + Developer Mode 設定済み

## 現状（重要）

- `main` = `18b29b4`（PR #2〜#8 統合済み: P0 パイプライン + 実行時修正）
- 未マージのスタック（順に積層）: `main` ← #9 foundation ← #10 使いやすさ+日本語 ← #11 push ← #12 free-build+QR+UI磨き（最新統合元 `veqral/free-device-polish`）← #13 AGENTS 引継ぎ ← #14 UI日本語磨き ← #15 PR1 core fixes ← #16 PR-A screen inventory ← #17 PR1 surface consolidation ← #18 PR2 portfolio command center ← #19 backlog #0 Hermes memory smoke
- #9: Device→エージェント選択、Codex/Claude 直接、Hermes Project→Chat→model、History「Continue」resume。（更新耐性 adapter を同ブランチに足す指示済み → 入っているかブランチで確認）
- #10: ワンタップ承認(一覧から)、Chat/セッション名前付け+フィルタ、画像 diff 3 モード+hunk 添付、swipe、日本語/English/System 切替（`Localizable.strings` 体系。`.xcstrings` 移行は未）
- #11: APNs push（device build は free team では Push capability 非対応で停止 → #12 で外した）
- #12: Push capability/entitlement を build から除去 + push を feature flag OFF（コードは温存）、Devices に QR スキャナ + 手動 fallback、全画面共通の接続ストリップ、UI を少し製品寄りに。free team で実機 build 成功
- #13: Codex 用の引継ぎ `AGENTS.md` をリポジトリ直下に追加。
- #14 (`codex/ui-japanese-polish`): UI/UX のみ。日本語一本化、Home の警告カード中立化、UUID/パス前面表示抑制、状態色整理、Projects/Devices/Approvals/More 配下の文言・余白・重複 UI を整理。Run/pairing/WebSocket/Hermes/履歴/承認の挙動変更なし。
- #15 (`codex/pr1-core-fixes`): QR pairing URL に署名を追加（手動 code fallback は維持）、LaunchAgent 由来の Host 実行環境 PATH/HOME を補強、Mac Catalyst は常時 3 ペイン + 最小サイズ。実機指摘対応として、停止中 Run の近くにも承認ボタンを表示し、Devices は current deviceID と端末名一致の自分/旧自分レコードを非表示にする。iPhone 16 Pro Max はインストール+起動確認済み。iPad Pro 13-inch は当時インストール成功、起動は #18 で確認済み。
- #16 (`codex/pr-a-screen-inventory`): PR-A。`SCREEN_INVENTORY_PR_A.md` に画面/機能棚卸し、keep/merge/cut、判断待ちを記録。到達不能だった旧 `DashboardView` / `SidebarView` / `InspectorView` と、それらに紐づく seed-era rows/models を削除。Run/pairing/WebSocket/Hermes/履歴/承認の挙動変更なし。#9〜#15 が未マージのため #15 に stacked。
- #17 (`codex/pr1-surface-consolidation`): PR1。PR-A の残4件を確定整理。トップレベル `Intent`/`Requirements`/`Agents`/`Models`/`Terminal` を削除し、要件メモは Command、Hermes model 選択は Projects→Hermes Chats、agent/runtime 選択は Command/Devices、terminal/PTTY/log は Command 作業面へ統合。`SURFACE_CONSOLIDATION_PR1.md` に before/after を記録。Run/pairing/WebSocket/Hermes/履歴/承認の挙動変更なし。
- #18 (`codex/pr2-portfolio-command-center`): PR2。司令塔タブを追加し、Host の HMAC 認証下に Portfolio registry API（`assets/<id>.yaml`、discover/status/logs/log-summary/commits/control/promote）を実装。GitHub/ローカル/案件ルート discover、承認付き shell control/promote、Ollama→Claude ログ要約、Discord webhook 通知、SwiftUI 一覧/詳細/追加/編集/案件拡張/Project link/最近 commit を追加。`PORTFOLIO_COMMAND_CENTER_PR2.md` に DoD と残課題を記録。iPhone 16 Pro Max と iPad Pro 13-inch にインストール+起動確認済み。
- #19 (`codex/backlog-0-hermes-memory-inheritance`): Backlog #0。`VeqralHostSmoke verify-memory-inheritance` を追加し、Hermes native memory 継承を使い捨て `HERMES_HOME` で実 LLM 検証する smoke と `HERMES_MEMORY_INHERITANCE_PR0.md` を追加。結果は正直に FAIL（Copilot 2モデル route はライセンス/権限で拒否、default route は隔離 `openai-codex` 認証不可 + Anthropic key rejected）。自作 memory は追加していない。

## 未完了・次の手番

1. 実機検証（最優先）
   - QR ペアリング（ユーザー報告ではカメラ認識→connected 済み。#18 端末配布後に念のため再確認）
   - Hermes の記憶継承。同 Project で Chat①(モデル A)に記憶→Chat②(モデル B)が継承（#19 smoke では FAIL。実証には有効な 2モデル credentials/license が必要）
   - 使いやすさ機能（承認ボタンは Approvals/Run detail/phone run row で見えること、Devices に自分自身が出ないこと）
   - 司令塔 E2E: discover → Asset 編集（health/controls/案件）→ control が承認待ちに積まれる → 承認後 Run ログで結果確認 → log-summary → local-only promote
   - UI 受け入れ確認: 日本語のみ、赤い 0 バッジなし、未ペアリング strip が細い、UUID/コンテナパスが主表示に出ない、Unavailable/Offline が緑でない
2. スタック統合：実機 OK 後、#9→#19 を main にまとめて取り込む（和集合・落とさず・壊さず・build & smoke 検証）
3. 司令塔 Host 設定: `VEQRAL_PORTFOLIO_CODE_ROOTS` / `VEQRAL_PORTFOLIO_ENGAGEMENT_ROOTS` / registry repo / Discord webhook を実環境に入れて discover 精度と通知を確認。
4. push 再有効化：有料 Apple Developer Program 加入後（capability 戻す + flag ON + APNs `.p8`/Key ID/Team ID + Host の env: `VEQRAL_PUSH_ENABLED` 他）
5. UI 磨き：スクショ駆動で気になる画面をピンポイント改善（CC Pocket / Supabase の質感、AI くささ排除）
6. 組織化：worker → skills で精度 → PM を置く → 上に積む（段階的）

## 作業の型（毎回）

- 自律実行。新ブランチ + draft PR。main 直コミット/マージしない（ユーザー承認必須）。
- 既存の E2E/pairing/Run/WebSocket/Codex・Claude 直接/Hermes/履歴/Memory/メニューバー/承認/diff/日本語 を壊さない。
- スコープを Veqral に限定。指定外の P1/P2 は作らず列挙のみ。
- 検証：MacHost `swift build` / iOS Simulator build / Mac Catalyst build / `git diff --check` / redact grep / production grep（mock/stub/fake 等なし）/ 既存 smoke。
- 報告：やったこと / 触ったファイル+理由 / 検証結果 / 残課題 / 実機確認手順（iPhone・iPad 別）。
- 既定の「やらないこと」: MCP・自作共有メモリ / Mac mini 2台目 / Cron / Gateway / App Store / 内蔵 remote desktop / 設定画面の全面改修。

## このファイルの保守

大きな変更を入れたら、最後にこの AGENTS.md の「現状」「次の手番」を更新してから終えること（文脈の肥大化を防ぐため）。
