# Veqral handover package

確認時点: 2026-06-23 15:44:42 JST

このドキュメント群は、Veqral を次の人間・別 AI・未来の自分がこの会話なしで引き継ぐための入口です。単なる要約ではなく、リポジトリ、実行環境、検証結果、未確認事項、AI 固有の文脈を外部化した引き継ぎパッケージです。

## 読むべき人

- Veqral の実装を続ける開発者
- iPhone/iPad/Watch 実機受け入れを行う担当者
- Hermes / AI-Hub / Obsidian 連携を保守する担当者
- Draft PR や GitHub 状態を引き継ぐ AI エージェント

## 推奨の読む順番

1. `00-executive-summary.md`
2. `02-current-state.md`
3. `17-next-actions.md`
4. `14-open-questions.md`
5. `15-ai-context-export.md`
6. 必要に応じて `03-architecture.md` から `13-known-issues-and-risks.md`

## 最重要ファイル

| パス | 役割 | 注意 |
|---|---|---|
| `AGENTS.md` | Veqral の確定原則、過去 PR、作業型 | 最新作業で更新されるべき正本。AI 固有の方針も多い。 |
| `README.md` | 既存の概要と起動/ビルド手順 | 一部は現在の実態と矛盾あり。詳細は `18-documentation-drift.md`。 |
| `MacHost/Sources/VeqralHost/main.swift` | Mac Host の HTTP API、Run 管理、保存先、smoke | 8,980 行の中心ファイル。編集時は API 影響範囲を必ず確認。 |
| `MacHost/Sources/VeqralHost/HermesControl.swift` | Hermes config / AI-Hub policy / vault approval 操作 | `VEQRAL_HERMES_VAULT` と `VEQRAL_AIHUB_ROOT` に依存。 |
| `Veqral/AppState.swift` | SwiftUI アプリの状態、RemoteHostClient、永続化 | App 側 API caller と Keychain 保存の正本。 |
| `Veqral/Screens.swift` | 主要画面、Sales Lab、Memory、Hermes 操作、Approvals | UI の大半がここに集約。 |
| `Scripts/run_gate2_xcuitests.sh` | Gate2 XCUITest + real Hermes memory smoke runner | real LLM 実走を含むため、実行判断が必要。 |
| `DEVICE_ACCEPTANCE.md` | iPhone/iPad 実機受け入れ手順 | 実機 Gate2 の正本。 |
| `docs/handover/15-ai-context-export.md` | AI の頭の中に残りやすい文脈の外部化 | 次 AI が最初に読むべきファイルの一つ。 |
| `docs/handover/18-documentation-drift.md` | 既存 docs と実装/実環境の矛盾表 | 指定構成外だが、矛盾を本文に混ぜないため追加。 |

## 現在のプロジェクト状態

- 作業ブランチ: `codex/handover-package-20260623`
- ベース: `origin/main` の `a73d87f` (`Merge pull request #47 from hiroyuki0504/codex/aihub-local-runtime-cleanup`)
- ローカル `main`: `origin/main` より 7 commit behind のまま。作業は `origin/main` から新ブランチを切って実施。
- 作成前から未追跡だった資料: `CURRENT_APP_HANDOFF_20260621.md`, `CURRENT_IMPLEMENTATION_STATUS_20260606.md`, `CURRENT_IMPLEMENTATION_STATUS_20260607.md`, `VEQRAL_AI_HANDOFF_TEXTBOX.md`
- このパッケージ作成で追加/更新する範囲: `docs/handover/` と `AGENTS.md` の文脈追記のみ。機能コードは変更しない。

根拠:
- command: `pwd`
- command: `git branch --show-current`
- command: `git status --short --branch`
- command: `git log -1 --oneline --decorate`
- command: `git fetch origin --prune`
- command: `git log --oneline --decorate --left-right main...origin/main`
- command: `git switch -c codex/handover-package-20260623 origin/main`
- command: `git status --short --branch`

## 未確認事項

未確認事項は本文に散らさず、`14-open-questions.md` に集約した。特に重要なのは次の通り。

- iPhone/iPad 実機 Gate2 5 項目はこの turn では実操作していない。
- real Hermes memory inheritance XCUITest runner は real LLM 実走を含むため、この turn では再実行していない。
- 外部 Discord 実 webhook 配信はこの turn では送信していない。
- App Store / TestFlight / 有料 Apple Developer Program / APNs 本番運用は未確認。
- GitHub Actions / CI はこの checkout には存在しない。

## 最短で作業再開する手順

1. `git status --short --branch`
2. `sed -n '1,220p' docs/handover/02-current-state.md`
3. `sed -n '1,220p' docs/handover/17-next-actions.md`
4. `swift build --package-path MacHost`
5. `swift test --package-path MacHost`
6. `swift run --package-path MacHost VeqralHost smoke-hermes-control`
7. iPhone/iPad 実機を触る場合は `DEVICE_ACCEPTANCE.md` と `docs/handover/08-testing-and-verification.md` を先に読む。

## 構成

| ファイル | 内容 |
|---|---|
| `00-executive-summary.md` | 非技術者向け概要 |
| `01-project-map.md` | ディレクトリと正本の地図 |
| `02-current-state.md` | git 状態、検証結果、作業中断点 |
| `03-architecture.md` | 全体構造、依存、Mermaid 図 |
| `04-components-and-ownership.md` | コンポーネント別責務 |
| `05-data-and-state.md` | データ、保存先、破壊リスク |
| `06-runtime-and-operations.md` | 起動、常駐、health、障害対応 |
| `07-development-workflow.md` | 開発手順とブランチ/PR 運用 |
| `08-testing-and-verification.md` | テスト構成と今回の実行結果 |
| `09-deployment-and-infrastructure.md` | deploy/infra/rollback の確認状況 |
| `10-integrations-and-external-services.md` | 外部連携 |
| `11-secrets-and-credentials-map.md` | secret の場所と参照箇所。値は書かない |
| `12-decision-log.md` | 設計判断 |
| `13-known-issues-and-risks.md` | 既知リスク |
| `14-open-questions.md` | 未解決事項 |
| `15-ai-context-export.md` | AI 固有文脈の外部化 |
| `16-source-index.md` | 根拠ソース索引 |
| `17-next-actions.md` | 次の担当者がそのまま動ける作業 |
| `18-documentation-drift.md` | 既存 docs と実態の矛盾。指定外追加ファイル。 |
