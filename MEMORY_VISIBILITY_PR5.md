# Memory Visibility PR5

## 実装

- Mac Host に `POST /v1/memory/project` を追加し、選択中 Hermes Project の `source` に対応する session 一覧を `~/.hermes/state.db` から読み取り専用で返す。
- 同じ response に Hermes native `~/.hermes/memories/MEMORY.md` の内容を含め、token/secret/password などは `Redactor.redact` 済みにした。
- Project 用の memory file record は `isEditable=false`。自作 memory store は作らず、Hermes の native memory/session を読むだけ。
- iOS/iPad/Mac の Memory 画面に「Hermes プロジェクト記憶」パネルを追加し、Project 名、Hermes source、MEMORY.md、session 一覧を read-only 表示する。
- 既存の Hermes Memory Files editor は残し、Project 表示とは分けた。

## Smoke

```sh
swift run --package-path MacHost VeqralHost smoke-project-memory
```

この smoke は `HermesMemoryStore.projectMemory` を直接呼び、source 解決、read-only record、session DB 読み取り経路が落ちないことを確認する。

## 受け入れ確認

1. iPhone/iPad で Mac Host とペアリングする。
2. Projects で Hermes Project を選択し、Chat で「覚えて」と事実を書かせる。
3. Memory 画面を開き、「Hermes プロジェクト記憶」に MEMORY.md の内容と session 一覧が出ることを確認する。
4. モデルを変えた Chat でも同じ Project source の session が増え、記憶表示から同じ事実を目視できることを確認する。

## 残る実機確認

- #0 の実 LLM 継承は credentials/license が通らず FAIL のまま。#5 は可視化導線を実装したが、実モデル 2 系統での継承 pass は未証明。
- 実 webhook や実機タップ確認と同じく、paired Host 上で Chat を実行した後の Memory 画面確認が必要。
