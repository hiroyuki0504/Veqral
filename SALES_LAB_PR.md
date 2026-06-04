# Sales Lab PR

## 目的

Veqral の主面は Codex Direct / Claude Direct のネイティブクライアントのまま維持しつつ、Portfolio / More 配下に「営業ラボ」を追加した。これは Web 改善営業の案件生成ツールで、手動登録したローカル店舗・事業者リードに対して、公式サイト監査、スマホ改善案、提案書、連絡文案、Portfolio 昇格、Hermes Desktop 引き継ぎを行う。

## MVP 範囲

- 手動リード登録と CSV import
- `~/.veqral-host/local-business-leads/` 配下の JSON repository
- リード一覧、状態管理、詳細表示
- 公式 URL のみを対象にした Web audit
- mobile viewport `390x844` の監査画像 artifact
- 既存サイトをコピーしないオリジナルのスマホ改善 HTML
- 提案書 HTML / PDF / 画像 artifact
- メール、DM、電話スクリプトの生成とコピー UI
- proposal approval status と contacted / won / lost / do_not_contact の状態管理
- won lead の Portfolio asset 昇格
- Hermes Desktop に貼る handoff note 作成

## Safety / Legal

- Google Maps / Places の非公式 scraping は実装していない。
- `/v1/sales/leads/discover` は `501 Not Implemented` で無効化している。
- `googlePlaceID` と `googleMapsURL` は手動入力フィールドとして保持するが、Google 由来のレビュー本文、写真、店舗情報の wholesale persistence は行わない。
- 連絡は自動送信しない。Veqral は文案生成と clipboard copy までで、人間が確認して外部ツールから送る。
- 公式サイト audit は登録済み URL のみを低頻度で読み、`robots.txt` が対象 path を disallow する場合は取得せず findings に記録する。
- 生成物とログは既存 `Redactor` を通す。

## Data Model

- `SalesLead`: businessName / category / area / officialWebsiteURL / googleMapsURL / googlePlaceID / phone / email / status / notes / latestAudit / latestRedesignMock / latestProposal / outreachLogs
- `WebsiteAudit`: score / findings / businessImpacts / screenshotPath / lighthouseSummaryPath
- `RedesignMock`: headline / subheadline / cta / htmlPath / screenshotPath
- `Proposal`: htmlPath / pdfPath / imagePath / pricing / emailDraft / dmDraft / phoneScript / approvalStatus
- `OutreachLog`: channel / note / createdAt

## Host API

- `GET /v1/sales/leads`
- `POST /v1/sales/leads`
- `PATCH /v1/sales/leads/{id}`
- `POST /v1/sales/leads/import-csv`
- `POST /v1/sales/leads/{id}/audit`
- `POST /v1/sales/leads/{id}/generate-mock`
- `POST /v1/sales/leads/{id}/generate-proposal`
- `POST /v1/sales/leads/{id}/approve-proposal`
- `POST /v1/sales/leads/{id}/mark-contacted`
- `GET /v1/sales/leads/{id}/assets`
- `POST /v1/sales/leads/{id}/promote-to-portfolio`
- `POST /v1/sales/leads/{id}/create-hermes-handoff`
- `POST /v1/sales/leads/discover` returns `501`

## UI

- Sales Lab は主タブではなく More の運用グループに配置。
- リード KPI、status filter、lead cards、manual add、CSV import を追加。
- 詳細は basic info、公式サイト/地図リンク、audit、スマホ改善案、proposal、生成物、Portfolio 昇格、Hermes Desktop handoff を同一画面に整理。
- 価格は `改善案作成: 3万円`、`LP / トップ改善: 15〜30万円`、`月次改善: 5〜15万円`。
- 連絡文は copy button のみ。外部送信 API はない。

## Smoke Results

```text
PASS: smoke-sales-lead-repository
PASS: smoke-sales-import-csv
PASS: smoke-sales-audit
PASS: smoke-sales-mock
PASS: smoke-sales-proposal
PASS: smoke-sales-no-autosend
PASS: smoke-sales-redact
```

## Validation

```text
PASS: swift build --package-path MacHost
PASS: iOS Simulator build (CODE_SIGNING_ALLOWED=NO)
PASS: Mac Catalyst build (CODE_SIGNING_ALLOWED=NO)
PASS: watchOS generic build
PASS: Gate2 XCUITest iPhone Simulator
PASS: Gate2 XCUITest iPad Simulator
PASS: git diff --check
PASS: Localizable key parity / plist lint
PASS: scoped production wording grep
PASS: secret grep
```

実機 iPhone / iPad は `devicectl` 上で unavailable のため、この PR では Simulator / Catalyst / watchOS generic まで。Apple Watch 実機は `devicectl` 上では paired として見えるが、Xcode destination では `known architecture` 不明で ineligible。Sales Lab は Watch UI を変更していない。

## 実行手順

```sh
swift run --package-path MacHost VeqralHost smoke-sales-lead-repository
swift run --package-path MacHost VeqralHost smoke-sales-import-csv
swift run --package-path MacHost VeqralHost smoke-sales-audit
swift run --package-path MacHost VeqralHost smoke-sales-mock
swift run --package-path MacHost VeqralHost smoke-sales-proposal
swift run --package-path MacHost VeqralHost smoke-sales-no-autosend
swift run --package-path MacHost VeqralHost smoke-sales-redact
VEQRAL_GATE2_SKIP_DEVICES=1 VEQRAL_GATE2_ONLY=ipad-simulator Scripts/run_gate2_xcuitests.sh
```

## 未完了

- Google Places API を使った discovery は未実装。次 PR で公式 API key / quota / terms を確認してから追加する。
- 実ブラウザの full screenshot は best-effort browser CLI がある環境で強化余地あり。現 MVP は audit artifact として 390x844 SVG preview を保存する。
- Proposal の PDF は lightweight PDF。営業資料の視覚品質は次 PR でテンプレートを整える。
- Hermes Desktop への直接書き込みはしない。handoff note を作り、Hermes Desktop 側へ委譲する。

## 次 PR 候補

- Places API official discovery
- Playwright / WebKit を使った real mobile screenshot capture
- 提案書テンプレート改善
- Lead status の bulk update
- Portfolio asset との双方向リンク表示
