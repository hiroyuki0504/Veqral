# PR #10: 音声入力 P0

## 目的

Command composer から日本語で指令を話し、聞き取り → ルール整形 → 短い LLM cleanup → 確認 → 既存 `submitDraft()` 送信へ進める P0 を追加した。送信は必ず確認後で、削除/本番/課金/token/.env/main merge/force push/deploy/Computer Use などは既存 Approval Gate に乗る。

## 実装

- composer 右側にマイクボタンを追加（iPhone/iPad/Mac Catalyst で表示。録音実行は iPhone/iPad）。
- `Speech` + `AVFoundation` で日本語 dictation を取得。
- ローカル rule cleanup:
  - フィラー除去（えー/あー/えっと/うーん/なんか/まあ/その）
  - 自己修正マーカー（やっぱなし/今のなし/さっきのなし/いや違う/じゃなくて/取り消し/戻して）以降を採用
  - 空白/句読点を整形
- Mac Host に authenticated `POST /v1/voice/cleanup` を追加。
  - Hermes を優先し、選択中 runtime が Codex/Claude の場合は fallback 候補に入れる。
  - cleanup prompt は「整形済み本文だけ」を要求し、高リスク語を弱めない。
  - LLM cleanup 失敗時は rule cleanup のまま Ready にする。
- 音声シートは raw（聞き取り）と cleaned command を上下に表示し、編集/録り直し/破棄/送信が可能。
- raw audio は保存しない。保存されるのは送信された cleaned command の通常 Run 履歴のみ。
- `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription` を追加。

## Smoke

- `VeqralHost smoke-voice-cleanup` で cleanup prompt と出力 sanitizing を検証。
- iOS Simulator build / Mac Catalyst build は通過。

## 残課題

- 実機でマイク権限と Speech 権限を許可し、録音 → Stop → cleaned 表示 → 編集 → 送信まで確認する。
- 実 Host に Hermes/Codex/Claude の cleanup 実モデル credentials が無い場合、LLM cleanup は rule cleanup fallback になる。
