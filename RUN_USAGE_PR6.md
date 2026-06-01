# Run コスト/トークン表示 PR6

## 目的

Run 詳細で、Codex / Claude / Hermes の実行使用量を確認できるようにする。表示対象は入力/出力トークン、推論トークン、cache read/write、合計、概算/実コスト。

## 実装

- Mac Host の `HostRun` に `usage` を追加。
- PTY ログから Claude stream JSON / Codex usage JSON / usage テキストを redacted 後に抽出。
- Hermes run 完了時は `~/.hermes/state.db` の `sessions` を read-only で参照し、session ID に紐づく usage を補完。
- Run list / Run snapshot の既存 API に `usage` を同梱。新規通信路は追加していない。
- iPhone / iPad / Mac Catalyst 側は `RemoteRunRecord.usage` を `CommandRun.usage` に同期し、Run 詳細ヘッダーに使用量チップを表示。

## Smoke

`swift run --package-path MacHost VeqralHost smoke-run-usage`

Claude stream JSON、Codex usage JSON、テキスト usage の 3 パターンを parser smoke で検証する。

## 残課題

- 実機では、実際の Codex / Claude / Hermes run 完了後に Run 詳細へ usage が出ることを確認する。
- Hermes の概算/実コストは Hermes `state.db` に値が入るモデル/provider のみ表示される。
