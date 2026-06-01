# Discord Notifications PR4

## 実装

- Mac Host の通知経路に Discord webhook を追加。
- 対象イベントは承認待ち、Run 完了、Run 失敗、司令塔 Asset の running から down への遷移。
- APNs の feature flag は変更せず、休眠状態のまま温存。
- Discord webhook URL は `VEQRAL_DISCORD_WEBHOOK`、`VEQRAL_PORTFOLIO_DISCORD_WEBHOOK`、Keychain `discord:webhook`、Keychain `portfolio:discord-webhook`、Host config の順に解決。
- 送信本文は `Redactor.redact` を通し、Run ID は短縮、作業場所はディレクトリ名だけにして生パスを主表示にしない。

## 受け入れ確認

自動 smoke:

```sh
swift run --package-path MacHost VeqralHost smoke-discord-notifications
```

この smoke はローカル受信口を立て、承認待ち、Run 完了、Run 失敗、司令塔 down の 4 payload が届き、token/password/bearer が本文から redaction されることを確認する。

実 webhook での確認:

1. Mac Host に Discord webhook URL を設定する。
2. 承認が必要な Run を作成し、Discord に `Veqral 承認待ち` が届くことを確認する。
3. 承認後、成功 Run で `Veqral Run 完了`、失敗 Run で `Veqral Run 失敗` が届くことを確認する。
4. 司令塔 Asset が running から stopped へ変わった時に、`司令塔: <名前> が停止しました。` が届くことを確認する。

## 残る実機確認

- この環境には実 webhook URL を設定していないため、外部 Discord への到達確認は未実施。
- 設定後の iPhone/iPad 受け入れでは、承認待ち発生、Run 完了、Run 失敗の 3 通知を目視確認する。
