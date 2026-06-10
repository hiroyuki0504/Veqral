# Hermes リモート操作 + ローカルAI削除（HERMES_REMOTE_CONTROL_PR）

ブランチ: `claude/hermes-remote-control`
目的: Hermes×Obsidian 統合基盤の Phase 6–7 を Veqral に実装する。①vault 承認キューの iPhone/Watch 承認、②モデル/思考深度（reasoning_effort）のスマホ・Watch 切替、③ローカルAI（Ollama）経路の削除。

## やったこと

1. **Mac Host: Hermes 制御 API（HMAC 認証下、4 endpoint）**
   - `GET /v1/hermes/control` — `~/.hermes/config.yaml` から現在の provider / model / reasoning_effort を読み、vault の `90_Org/presets.md`（Markdown 表）をプリセットとして返す。
   - `POST /v1/hermes/control` — `{presetID}` または `{model, provider, reasoning}` を受け、config.yaml を**対象キーのみ行単位で書換**（`model.default` / `model.provider` / `agent.reasoning_effort`。他行はバイト単位で温存、書換前に `config.yaml.veqral-bak` へバックアップ、fresh-install の `model: ""` スカラー形式も mapping へ昇格）。reasoning は `none/minimal/low/medium/high/xhigh` のみ受理。適用は新セッションから（実行中チャットは `/model`・`/reasoning`）。
   - `GET /v1/hermes/approvals` — vault `90_Org/Approvals/pending/*.md` を一覧（title は frontmatter/H1、summary は冒頭 12 行・800 字上限・Redactor 通過）。
   - `POST /v1/hermes/approvals/decide` — `{id, decision: approve|reject, note?}`。pending → approved/rejected へ移動し、decision footer（decided_at / decided_via: veqral / note）を追記。ID はパス遮断検証あり。
   - 設定: `VEQRAL_HERMES_VAULT`（vault ルート、必須）/ `VEQRAL_HERMES_CONFIG`（既定 `~/.hermes/config.yaml`）。シェル実行なし・ファイル直読みなので Hermes 停止中でも動く。
2. **iPhone/iPad: 「Hermes 操作」画面（More→Operations 先頭）**
   - 現在のモデル/プロバイダ/思考深度の表示、プリセット 3 ボタン、手動設定（モデル・プロバイダ・思考深度 6 段階）+ 適用、vault 承認の一覧/承認/却下。
   - Approvals タブにも「Hermes 承認（vault）」セクションを追加（Run 承認と並列表示）。
3. **Apple Watch**
   - Hermes セクション追加: 現在モデル/思考深度、プリセット 3 ボタン（タップで適用）、vault 承認カード（承認/却下）。既存の phone-review キーワード（削除/本番/secret 等）に該当する案件は Watch では承認不可・iPhone 誘導。コンプリケーションの承認件数に Hermes 分を加算。
4. **ローカルAI（Ollama）削除**
   - 司令塔ログ要約の `ollama run llama3.2` 先行経路を削除し、`claude --print` を一次（失敗時は既存ルール要約）に変更。
   - README の「Free local fallback (Ollama)」節を削除し cloud-only ポリシーを明記。

## 触ったファイル + 理由

- `MacHost/Sources/VeqralHost/HermesControl.swift` **新規** — store/wire/YAML 行編集/presets 表パーサ/承認ファイル操作。SwiftPM target は自動取り込みのため pbxproj 変更不要。
- `MacHost/Sources/VeqralHost/main.swift` — store 登録、dispatch へ 4 endpoint 追加（`/v1/devices` の直前）、logSummary の Ollama 経路削除。
- `Veqral/AppState.swift` — `RemoteHostClient` に署名付き 4 メソッド追加（private request を使うためクラス内）、末尾に wire モデルと `CommandCenterStore` extension を追記。
- `Veqral/Screens.swift` — `HermesControlView` / `HermesApprovalsSection` / 行コンポーネントを追記、`ApprovalsView` に 1 行挿入。
- `Veqral/Models.swift` / `Veqral/RootView.swift` — `AppSection.hermes`（タイトル/シンボル/operationGroup）と `sectionDestination` の分岐。
- `VeqralWatch/VeqralWatchApp.swift` — wire/クライアント 4 メソッド/store 状態/UI セクション/カード/コンプリケーション加算。
- `README.md` — Ollama fallback 節を cloud-only 注記に置換。
- 既存ファイルへの追記方針は、pbxproj が明示ファイル登録（PBXFileSystemSynchronizedRootGroup 不使用）のため。新規 .swift をアプリ target に足すと project 編集が必要になり、手書き編集はリスクが高い。

## 検証結果

- **未実施（この環境は Linux コンテナで Xcode/macOS SDK なし）。** Mac で以下を順に:
  1. `swift build --package-path MacHost`
  2. iOS Simulator build / Mac Catalyst build（既存 scheme）
  3. `git diff --check` / redact grep / production grep（mock/stub なし）
  4. Host 起動後の手動 smoke:
     ```sh
     export VEQRAL_HERMES_VAULT="$HOME/Obsidian/vault"   # 実パスに置換
     # GET control / approvals は iPhone の Hermes 操作画面から確認が早い
     ```
  5. vault 側に `90_Org/Approvals/pending/test.md` と `90_Org/presets.md` を置いて、iPhone→一覧表示→承認→approved/ へ移動 + footer 追記を確認。
  6. `POST /v1/hermes/control` 適用後、`~/.hermes/config.yaml` の該当キーのみ差分になっていること（`diff config.yaml config.yaml.veqral-bak`）。

## 残課題

1. VeqralHostSmoke の Ollama フォールバック（`isLocalOllamaBaseURL` 一式、main.swift:410/468/541/583/600 付近）削除 — smoke の Gate1 動作を Mac で検証しながら別コミットで。
2. 新 endpoint の smoke（`smoke-hermes-control`）追加と Gate2 XCUITest への「Hermes 操作」シナリオ追加（pbxproj 編集を伴うため Mac 上の Xcode で）。
3. 承認決定の Discord webhook 通知（既存 Notifier 流用、任意）。
4. presets の `{{ }}` プレースホルダを実モデル slug へ（vault 側作業）。
5. アクティブセッションへの `/model`・`/reasoning` 注入は Hermes 側 API 待ち。現状は新セッション適用のみ（マスタープロンプト Decisions 記録対象）。

## 実機確認手順

- **iPhone/iPad**: ペアリング済み状態で More→Hermes 操作。現在値表示→プリセット 1 つ適用→「新しいセッションから適用」の結果文言→config.yaml 反映を Mac で確認。Approvals タブに vault pending が出る→承認→Obsidian（iPhone アプリでも可）で approved/ へ移動と footer を確認。
- **Watch**（watchOS platform 導入後）: Hermes セクションにプリセット 3 ボタン→「軽」適用→message 表示。pending カードの承認/却下。phone-review 該当（タイトルに「削除」等）のカードは承認ボタンが無効で iPhone 誘導文言が出ること。
