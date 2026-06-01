# Cost Governance PR A3

## 目的

既存の Run usage（入力/出力 token、推論 token、概算/実費）を project 単位で集計し、予算上限・しきい値・停止/承認再開の流れを Veqral の操作面に入れる。

## 実装

- Mac Host
  - `GET /v1/budgets` で project 別の累積 token / cost / budget 状態を返す。
  - `POST /v1/budgets` で project 予算を保存する。保存先は Host config の `projectBudgets`。
  - 既存の run count budget guard に加えて、cost budget を `createRun` で判定する。
  - 上限超過または pause 中の project は high severity approval に止める。
  - Run 完了時に usage が上限を超えたら project budget を auto pause し、監査ログ/通知/stream event に残す。
- iOS / iPad / Mac Catalyst
  - Remote budget summary を取得して `projectCostSummaries` に保持。
  - Run 詳細に「コストガード」を表示。累積 token / 累積費用 / 上限 / しきい値状態 / 保存 / 再開を操作できる。
  - 司令塔 Asset 詳細にも同じ「コストガード」を表示。`linkedProjectId` または local path で project summary に紐づける。
  - Mac Host 未接続時は端末内にある Run usage から read-only の概算 summary を出す。

## 仕様メモ

- project key は Hermes Project がある場合 `project:<projectID>`、直接モードや Shell は `path:<workingDirectory>`。
- しきい値は default 80%。Host は 10%〜100% に clamp する。
- cost は actual があれば actual、なければ estimated を使う。provider が cost を出さない場合は token のみ集計し、budget 判定は cost なしとして扱う。
- 「再開」は budget pause を解除する設定操作。上限を超えたまま次の Run を作る場合は、既存 approval flow で個別承認になる。

## 検証

- `swift build --package-path MacHost`
- XcodeBuildMCP `build_sim`（iOS Simulator, `CODE_SIGNING_ALLOWED=NO`）
- `xcodebuild ... platform=macOS,variant=Mac Catalyst CODE_SIGNING_ALLOWED=NO build`
- `VeqralHost smoke-cost-governance`
- `VeqralHostSmoke verify-memory-inheritance`（`openai-codex/gpt-5.5 -> openai-codex/gpt-5.4` PASS）
- 既存 Host smoke: project-memory / Discord / telemetry / voice-cleanup / run-usage
- `git diff --check`
- Localizable lint + missing-key check
- source production grep + concrete secret grep

## 残課題

- 実 provider が cost を返さない run は token 集計のみになる。単価表の自前推定は、モデル価格変更に追従しづらいため A3 では入れていない。
- 複数端末から同じ Host を操作する場合、予算の真実は Mac Host config。端末内 local summary は未接続時の補助表示だけ。
