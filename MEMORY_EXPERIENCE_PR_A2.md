# Memory Experience PR A2

## 目的

Hermes 記憶を「表示できる」だけでなく、選択中 Project の native memory / session をそのまま使って「聞ける」「別 Chat / 別モデルへ引き継げる」体験にする。

## 実装

- Memory 画面の「Hermes プロジェクト記憶」に問い合わせ欄を追加。
  - 入力例: 「先週このプロジェクトで何をしていた？」「未解決の論点は？」「次に触るべきファイルは？」
  - 送信時は同じ Hermes Project に新しい Chat を作り、既存の `submitHermesProjectCommand` 経路で Hermes を実行する。
  - Project memory 表示は read-only のまま。保存や継承は Hermes native memory / session に任せる。
- Run 詳細に「Project 記憶へ引き継ぐ」アクションを追加。
  - Codex / Claude / Shell の直接モード Run から、元の指令・直近ログ・差分統計・usage を要約して Hermes Project に送る。
  - 送信前に app 側でも token / secret / Authorization 風の文字列を簡易 redact する。
  - Hermes には「別 memory store や MCP を作らず、native memory / session の範囲で整理する」と明示する。

## Hermes-native 遵守

- 自作の共有 memory store は追加していない。
- Mac Host の memory API は既存の `POST /v1/memory/project` read-only 表示だけを継続使用。
- 問い合わせと引き継ぎは、既存の Hermes Run 作成経路に乗せるだけ。Project の `--source veqral-<projectID>` と Hermes native memory/session が継承の土台。
- `~/.codex` / `~/.claude` は参照・編集していない。

## 受け入れ

- Chat で覚えた事実は既存 #0 smoke と Memory visibility で `MEMORY.md` / session に出る。
- Memory 画面から同じ Project の新 Chat に質問できる。
- Run 詳細から直接モードの文脈を Hermes Project に渡せる。
- 別モデルへの実際の継承は、Projects で Hermes Chat の provider/model を切り替えてから問い合わせまたは引き継ぎ Run を実行して確認する。

## 検証

- `swift build --package-path MacHost`
- XcodeBuildMCP `build_sim`（iOS Simulator, `CODE_SIGNING_ALLOWED=NO`）
- `xcodebuild ... platform=macOS,variant=Mac Catalyst CODE_SIGNING_ALLOWED=NO build`
- `VeqralHost smoke-project-memory`
- `VeqralHostSmoke verify-memory-inheritance`（`openai-codex/gpt-5.5 -> openai-codex/gpt-5.4` PASS）
- 既存 Host smoke: Discord / telemetry / voice-cleanup / run-usage
- `git diff --check`
- Localizable lint + missing-key check
- source production grep + concrete secret grep

## 残課題

- Claude login が Hermes から使える状態になったら、#A7 で Claude→GPT のクロスベンダー #0 を再実走する。
- A2 の UI は実機で Memory 画面から質問→Run 作成、直接モード Run から引き継ぎ→Run 作成をタップ確認する。
