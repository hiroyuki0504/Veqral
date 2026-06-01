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

- `main` = clean baseline（#9〜#29 と #A0〜#A7 をそれぞれ 1 回の union integration で統合済み）
  - #9〜#29 退避 branch: `pre-portfolio-main-20260601-061622`、統合 branch: `codex/main-stack-integration-20260601`
  - #A0〜#A7 退避 branch/tag: `pre-a-diff-main-20260602-004405`、統合 branch: `codex/final-a-union-20260602`
- 旧スタック #9〜#29 と Draft PR #30〜#37 は `main` に包含済み。以後の新規作業は clean `main` からブランチを切る。
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
- #20 (`codex/backlog-3-websocket-resume`): Backlog #3。Remote Run WebSocket stream を指数バックオフで再接続し、再接続前に run snapshot/replayed logs を同期・重複排除、terminal 状態では resume しない安全策を追加。接続ストリップに connecting/streaming/reconnecting/disconnected を表示。`WEBSOCKET_RECONNECT_PR3.md` に manual smoke 手順を記録。
- #21 (`codex/backlog-4-discord-notifications`): Backlog #4。Mac Host の Discord webhook 通知を承認待ち/Run 完了/Run 失敗/司令塔 Asset down に拡張。URL は `VEQRAL_DISCORD_WEBHOOK` / legacy portfolio env / Keychain / Host config で解決、本文は redact + Run ID 短縮 + 作業場所名のみ。APNs は feature flag OFF のまま温存。`VeqralHost smoke-discord-notifications` でローカル 4 payload + redact smoke 通過。
- #22 (`codex/backlog-5-memory-visibility`): Backlog #5。Memory 画面に「Hermes プロジェクト記憶」を追加し、選択中 Project の Hermes source、redact 済み `MEMORY.md`、`~/.hermes/state.db` の session 一覧を read-only 表示。Host は `POST /v1/memory/project` と `VeqralHost smoke-project-memory` を追加。自作 memory store は追加していない。
- #23 (`codex/backlog-6-run-usage`): Backlog #6。Mac Host の `HostRun` に usage を追加し、Claude stream JSON / Codex usage JSON / usage テキストから redacted 後に token/cost を抽出。Hermes は `~/.hermes/state.db` の session usage を read-only 補完（列差分は `NULL` で吸収）。Run list/snapshot で iPhone/iPad に同期し、Run 詳細ヘッダーに入力/出力/推論/cache/合計/費用を表示。`VeqralHost smoke-run-usage` 通過。
- #24 (`codex/backlog-7-approval-context`): Backlog #7。高リスク承認の Approve は即送信せず、確認シートで実行コマンド/指示本文、影響ファイル、差分統計、patch 冒頭を表示してから承認する。Run 詳細 callout と Approvals 一覧にも同じ `ApprovalImpactPreview` を表示。中リスク one-tap は維持。
- #25 (`codex/backlog-8-saved-commands`): Backlog #8。Command composer に「定型コマンド」バーを追加し、現在の指令を保存、chip タップで再投入、menu から削除できるようにした。保存時の runtime も復元。`CommandCenterSnapshot` に加えて、iCloud Documents が使える端末では `Veqral/saved-command-drafts.json` へ best-effort 同期キャッシュ、使えない環境はローカル fallback。`SAVED_COMMANDS_PR8.md` に受け入れを記録。
- #26 (`codex/backlog-9-host-telemetry`): Backlog #9。Mac Host に authenticated `GET /v1/telemetry` を追加し、`/v1/health` に初回 telemetry を同梱。CPU/per-core/load、memory/pressure、disk、`ProcessInfo.thermalState`、uptime/OS/model、battery/AC、network throughput(best-effort)、上位 process を収集。Devices 画面の「ホスト状態」で表示中だけ 5 秒間隔更新。raw 温度/fan/SMART は取得不可なら `—`。`VeqralHost smoke-host-telemetry` 通過。
- #27 (`codex/backlog-10-voice-input`): Backlog #10。Command composer に mic ボタンを追加し、iPhone/iPad で Speech + AVFoundation の日本語 dictation → ローカル filler/自己修正 cleanup → Host `POST /v1/voice/cleanup` の短い LLM cleanup → raw/cleaned 確認 → `submitDraft()` 送信。Mac Catalyst は sheet で非対応表示。Host cleanup は Hermes 優先、選択中 Codex/Claude fallback、失敗時は rule cleanup。raw audio 非保存。`VeqralHost smoke-voice-cleanup` 通過。
- #28 (`codex/backlog-12-main-integration-plan`): Backlog #12。`MAIN_INTEGRATION_PLAN_PR12.md` に #9→#29 を clean main へ統合した退避点、検証、findings を記録。force-push/deploy は未実行。
- #29 (`codex/gates-hermes-device-acceptance`): Gate1/Gate2。`VeqralHostSmoke verify-memory-inheritance` を月額ログイン優先へ更新し、隔離 `HERMES_HOME` に `~/.hermes/auth.json` を symlink して `openai-codex/gpt-5.5 -> openai-codex/gpt-5.4` で実走 PASS。Chat A が使い捨て code name を Hermes native `MEMORY.md` に書き、Chat B が同じ値を返した。最新 transcript は `HERMES_MEMORY_INHERITANCE_PR0.md`。Claude/Anthropic は Hermes からは未ログイン扱い、Ollama は未起動。`DEVICE_ACCEPTANCE.md` に iPhone/iPad の voice / telemetry / saved command / Discord webhook / Memory visibility 手順を追加し、Discord テスト通知ボタン、telemetry 失敗理由、Memory 最終取得時刻を追加。
- #30 (`codex/a0-code-audit`): #A0。`AUDIT.md` で clean main を機能別に実査し、Discord test 2xx、Host state isolation、Hermes `HERMES_HOME`、redactor、portfolio DELETE fail-closed を修正。
- #31 (`codex/a1-gate2-xcuitest`): #A1。Gate2 の XCUITest target/scheme と `Scripts/run_gate2_xcuitests.sh` を追加。
- #32 (`codex/a2-memory-experience`): #A2。Hermes native memory の問い合わせ導線と、direct run 文脈を Hermes Project に引き継ぐ handoff を追加。
- #33 (`codex/a3-cost-governance`): #A3。Project token/cost budget、Host `/v1/budgets`、Run/司令塔の予算表示、超過 pause/承認再開を追加。
- #34 (`codex/a4-portfolio-real-data`): #A4。実ルート未設定時の isolated portfolio sample acceptance、`VEQRAL_HOST_HOME`、`includeGitHub`、Discord webhook disable を追加。実資産 roots/registry は未設定。
- #35 (`codex/a5-auth-onboarding`): #A5。Host auth onboarding API、Devices の認証オンボーディング panel、Keychain readiness marker、`smoke-auth-onboarding` を追加。
- #36 (`codex/a6-watch-approval`): #A6。Apple Watch 承認 scaffold。`VeqralWatch` target/scheme、Watch HMAC client、Keychain token、approve/reject UI、一言コマンド、complication 用 status view を追加。watchOS 26.5 platform 未インストールのため Watch build/実機/cellular/APNs は partial として `WATCH_APPROVAL_PR_A6.md` に明記。
- #37 (`codex/a7-cross-vendor-memory`): #A7。Claude→GPT の cross-vendor #0 を `anthropic/claude-haiku-4-5 -> openai-codex/gpt-5.5` で試行。Claude 側は subscription/login auth のみを許可し、API key fallback では通していない。Hermes-readable Claude/Anthropic login が未復旧のため preflight で停止し、`HERMES_CROSS_VENDOR_PR_A7.md` と `HERMES_MEMORY_INHERITANCE_PR0.md` に未到達理由を記録。
- Final A integration (`codex/final-a-union-20260602`): #A0〜#A7 を 1 回の union integration で clean `main` に統合。pre-merge / integration / post-main で MacHost build、iOS Simulator build、Mac Catalyst build、Host smokes、#0 verify-memory-inheritance、Gate2 XCUITest、grep/l10n を確認。Gate2 は iPhone Simulator / iPad Simulator とも PASS。Watch build は watchOS 26.5 platform 未インストールのため partial のまま。

## 未完了・次の手番

1. #A7 follow-up: Claude/Anthropic を Hermes-readable な subscription/login として復旧した後、`HERMES_CROSS_VENDOR_PR_A7.md` のコマンドで再実走する。API key fallback で偽 pass を作らない。
2. Gate1: #0 Hermes 記憶継承は `openai-codex/gpt-5.5 -> openai-codex/gpt-5.4` の real 2 model で PASS 済み。`HERMES_MEMORY_INHERITANCE_PR0.md` に実トランスクリプトあり。自作 memory は足していない。
   - より強いクロスベンダー証明は、Hermes から Claude/Anthropic login が使える状態になった後で再実行する。
3. Gate2（継続）: #A1 XCUITest は iPhone Simulator / iPad Simulator で PASS 済み。実機では `DEVICE_ACCEPTANCE.md` に沿って iPhone/iPad 5項目を確認。
   - 対象: voice input / host telemetry / saved command / Discord 実 webhook / Hermes memory visibility。
   - ユーザーが落ちた項目を報告したら、その項目だけ Draft PR で修正。
4. #A6 Watch（環境待ち）: Xcode に watchOS 26.5 platform を入れた後、`VeqralWatch` を build し、iOS target への embed、実 Watch/Tailscale/WebSocket/cellular reachability、APNs capability を順に検証する。現 free team では push は不可。
5. 実機検証（継続）
   - QR ペアリング（ユーザー報告ではカメラ認識→connected 済み。#18 端末配布後に念のため再確認）
   - Hermes memory visibility。同 Project で Chat①(モデル A)に記憶→Chat②(モデル B)が継承され、Memory 画面で同じ事実が見えること（Gate1 smoke は PASS 済み）
   - 使いやすさ機能（承認ボタンは Approvals/Run detail/phone run row で見えること、Devices に自分自身が出ないこと）
   - 司令塔 E2E: discover → Asset 編集（health/controls/案件）→ control が承認待ちに積まれる → 承認後 Run ログで結果確認 → log-summary → local-only promote
   - #20 WebSocket reconnect: 長い remote run 中にネットワークを一瞬切り、strip が再接続表示になってログが復帰すること（実機 manual smoke 未実施）
   - #21 Discord: 実 webhook URL を設定し、承認待ち/Run 完了/Run 失敗/司令塔 down が外部 Discord に届くこと（ローカル smoke は通過済み）
   - #22 Memory: paired Host で Hermes Project Chat を実行し、Memory 画面に `MEMORY.md` の事実と同 source の session 一覧が出ること（Host smoke は通過済み）
   - #23 Run usage: 実際の Codex/Claude/Hermes run 完了後、Run 詳細ヘッダーに token/cost が出ること（Host parser smoke は通過済み。provider が usage を出さない場合は空表示）
   - #24 Approval context: 高リスク Run を作成し、Approve タップで確認シートが出て、コマンドと差分/ファイルが承認前に見えること
   - #25 Saved command drafts: 指令欄に入力→保存→chip 表示→tap で composer に戻ること。iCloud 同期は iCloud Documents が有効な端末同士で確認（未有効時はローカル fallback）。
   - #26 Host telemetry: Devices→ホスト状態で CPU/メモリ/ディスク/熱状態/稼働時間/バッテリー/ネットワークが表示され、画面表示中に約 5 秒間隔で更新されること。raw 温度/fan は `—` でよい。
   - #27 Voice input: iPhone/iPad で mic→権限許可→日本語発話→Stop→raw/cleaned 表示→編集→送信。Host に cleanup LLM credentials が無い場合は rule cleanup fallback 表示でよい。高リスク語は送信後に既存承認 Gate に乗ること。
   - UI 受け入れ確認: 日本語のみ、赤い 0 バッジなし、未ペアリング strip が細い、UUID/コンテナパスが主表示に出ない、Unavailable/Offline が緑でない
6. 司令塔 Host 設定: `VEQRAL_PORTFOLIO_CODE_ROOTS` / `VEQRAL_PORTFOLIO_ENGAGEMENT_ROOTS` / registry repo / Discord webhook を実環境に入れて discover 精度と通知を確認。
7. push 再有効化：有料 Apple Developer Program 加入後（capability 戻す + flag ON + APNs `.p8`/Key ID/Team ID + Host の env: `VEQRAL_PUSH_ENABLED` 他）
8. UI 磨き：スクショ駆動で気になる画面をピンポイント改善（CC Pocket / Supabase の質感、AI くささ排除）
9. 組織化：worker → skills で精度 → PM を置く → 上に積む（段階的）

## 作業の型（毎回）

- 自律実行。新ブランチ + draft PR。main 直コミット/マージしない（ユーザー承認必須）。
- 既存の E2E/pairing/Run/WebSocket/Codex・Claude 直接/Hermes/履歴/Memory/メニューバー/承認/diff/日本語 を壊さない。
- スコープを Veqral に限定。指定外の P1/P2 は作らず列挙のみ。
- 検証：MacHost `swift build` / iOS Simulator build / Mac Catalyst build / `git diff --check` / redact grep / production grep（mock/stub/fake 等なし）/ 既存 smoke。
- 報告：やったこと / 触ったファイル+理由 / 検証結果 / 残課題 / 実機確認手順（iPhone・iPad 別）。
- 既定の「やらないこと」: MCP・自作共有メモリ / Mac mini 2台目 / Cron / Gateway / App Store / 内蔵 remote desktop / 設定画面の全面改修。

## このファイルの保守

大きな変更を入れたら、最後にこの AGENTS.md の「現状」「次の手番」を更新してから終えること（文脈の肥大化を防ぐため）。
