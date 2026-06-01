# Veqral 実機受け入れチェックリスト

対象は iPhone / iPad の実機。どちらも同じ Mac Host に QR でペアリング済み、Mac Host は `100.96.40.99:7878`（Tailscale）で起動している前提。

## 事前確認

- iPhone / iPad の両方でアプリが起動する。
- Devices の Remote Mac Host が接続済みになり、接続ストリップが消える。
- Mac Host 側に Discord webhook を設定している場合は、`VEQRAL_DISCORD_WEBHOOK` または Keychain account `discord:webhook` に入れる。webhook URL は画面やログに表示しない。
- #0 の Hermes memory visibility を見る場合は、先に `verify-memory-inheritance` が real 2 model で pass していること。

## iPhone

### 1. 音声入力

操作:
1. 指令タブを開く。
2. composer 右側のマイクを押す。
3. 「えっと、この Run の失敗を直して。いや違う、ビルドエラーを直してテストして」と話す。
4. raw（聞き取り）と整形済み Command が出ることを確認する。
5. 送るを押す。
6. 「削除」「本番」「課金」「token」「.env」「main merge」「force push」「deploy」「Computer Use」を含む音声も一度試し、既存の承認 Gate で止まることを確認する。

期待結果:
- raw と整形済み Command が分かれて表示される。
- 整形済み Command は filler / 自己修正が反映されている。
- 確認後にだけ Run が作成される。
- high severity は承認待ちになる。

失敗時に見る所:
- iOS のマイク / Speech Recognition 権限。
- Mac Host 未接続メッセージ。
- 録音が短すぎる場合のエラー表示。
- Run detail のログと Approvals の queue。

### 2. ホスト状態

操作:
1. デバイスタブを開く。
2. Host Status を表示したまま 10 秒ほど待つ。
3. 必要なら Refresh Host を押す。

期待結果:
- CPU / メモリ / ディスク / 熱状態 / 稼働時間 / バッテリー / ネットワークが表示される。
- Updated 表示が進み、画面表示中に更新される。
- raw 温度 / fan など取れない値は `—`。
- 失敗時は Host Status 下部に理由が出る。

失敗時に見る所:
- Remote Mac Host の接続状態。
- Host Status 下部の失敗理由。
- Mac Host の `/v1/telemetry` が HMAC 認証下で応答しているか。

### 3. 定型コマンド

操作:
1. 指令タブの composer に「失敗した Run を直して、テストまで通して」と入力する。
2. 保存ボタンで定型に保存する。
3. composer を空にする。
4. 保存済み定型をタップする。
5. 送信する。

期待結果:
- 保存した定型が一覧に出る。
- タップで composer に再投入される。
- 送信すると通常の Run として作成される。

失敗時に見る所:
- 指令タブの saved command メッセージ。
- iCloud Documents が使えない場合でもローカル fallback に保存されるか。

### 4. Discord 実 webhook

操作:
1. Mac Host に webhook を設定する。
2. デバイスタブの Remote Mac Host で Discord テストを押す。
3. Discord 側にテスト通知が届くことを確認する。
4. high severity の承認待ちを作る。
5. Run 完了 / Run 失敗をそれぞれ発生させる。

期待結果:
- テスト通知が Discord に届く。
- 承認待ち / Run 完了 / Run 失敗で Discord 通知が届く。
- webhook URL や token はアプリ画面、Host ログ、監査ログに出ない。

失敗時に見る所:
- Remote Mac Host 下部の Discord テストメッセージ。
- Host の `VEQRAL_DISCORD_WEBHOOK` / Keychain `discord:webhook`。
- Discord チャンネル側の webhook 権限。

### 5. Hermes memory visibility

操作:
1. #0 の `verify-memory-inheritance` を real 2 model で pass させる。
2. プロジェクトタブで同じ Hermes Project を選ぶ。
3. Chat 1 で識別可能な事実を覚えさせる。
4. Memory 画面を開き、更新を押す。
5. Chat 2 でモデルを変えて同じ事実を聞く。

期待結果:
- Memory 画面に選択中 Project の source、memory file、最終取得時刻が出る。
- Chat 1 で書いた事実が native memory に見える。
- Chat 2 から同じ事実を参照できる。

失敗時に見る所:
- Memory 画面の読み込みメッセージ。
- `HERMES_MEMORY_INHERITANCE_PR0.md` の Chat A / Chat B transcript。
- Hermes source が Project ID と一致しているか。

## iPad

iPad は表示領域が広いので、同じ 5 項目を Split View / 3 ペイン表示で確認する。

### 1. 音声入力

操作と期待結果は iPhone と同じ。録音シートが横幅で崩れず、raw / 整形済み Command / 送る / 編集 / 録り直す / 破棄が同時に見やすいことを確認する。

失敗時に見る所:
- iPad の Speech Recognition 権限。
- 録音シートのボタンが画面外に出ていないか。

### 2. ホスト状態

操作と期待結果は iPhone と同じ。Host Status の各 metric がカード内で折り返し、文字が重ならないことを確認する。

失敗時に見る所:
- Host Status 下部の失敗理由。
- raw 温度 / fan が `—` の場合は正常。`thermalState` が主指標。

### 3. 定型コマンド

操作と期待結果は iPhone と同じ。定型一覧をタップしたとき composer に入ること、iPad の 3 ペインで選択状態がずれないことを確認する。

失敗時に見る所:
- saved command メッセージ。
- composer に古い draft が残っていないか。

### 4. Discord 実 webhook

操作と期待結果は iPhone と同じ。Discord テストボタンの結果メッセージが Remote Mac Host 内に出ることを確認する。

失敗時に見る所:
- Host の webhook 設定。
- Discord 側の受信履歴。

### 5. Hermes memory visibility

操作と期待結果は iPhone と同じ。Memory 画面で Project memory と Hermes memory files の両方が読め、最終取得時刻が見えることを確認する。

失敗時に見る所:
- Memory 画面の Project source。
- #0 smoke transcript。

## 判定

- 5項目すべてが iPhone / iPad で期待結果どおりなら Gate2 green。
- 落ちた項目は「端末 / 項目 / 操作 / 表示されたメッセージ / Run ID または Project 名」を添えて報告する。次の Draft PR でその項目だけ直す。
