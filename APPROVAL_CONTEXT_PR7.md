# 承認前コンテキスト表示 PR7

## 目的

高リスク承認で、Approve を押す前に「何が実行されるか」と「どの差分/ファイルに関係するか」を確認できるようにする。

## 実装

- `CommandApproval.requiresPreApprovalReview` を追加し、高リスク（赤/高）の Approve では即実行せず確認シートを表示。
- 確認シートに実行コマンド/指示本文、影響ファイル、差分統計、patch 冒頭を表示。
- Run 詳細の承認 callout と Approvals 一覧にも同じ `ApprovalImpactPreview` を表示。
- 既存の `approve/reject`、remote approve/reject、diff 同期、redact 経路は変更していない。

## 受け入れ

- 高リスク承認では、承認前にコマンド実体と差分/ファイルを確認できる。
- 差分がまだ無い承認では、空状態として「差分未取得」を表示し、偽の差分は作らない。
- 中リスク承認の one-tap 操作は維持する。

## 残課題

- 実機で、危険語を含む Run を作成し、Approve タップで確認シートが出ることを確認する。
