# Veqral #A0 Code Audit

Date: 2026-06-01
Branch: `codex/a0-code-audit`
Base: `main` `4aca6f2`

## Scope

Clean main の実コードを対象に、Mac Host、SwiftUI app、smoke、履歴/Memory/承認/通知/司令塔/音声/usage/telemetry の配線を確認した。`~/.codex` と `~/.claude` は読み取り専用前提で、履歴 reader と Hermes native memory の扱いだけを監査し、秘密値は本文に記録していない。

確認コマンド:

- `rg --files`
- `rg -n "TODO|FIXME|stub|mock|fake|demo|not implemented|fatalError|preconditionFailure"`
- Host/App の route、HMAC、redact、approval、Memory、History、Portfolio、Discord、telemetry、voice、usage 周辺の実装確認

## Summary

- 実配線は概ね本物。Mac Host の Run/stream/approval/resume、History read-only、Hermes project memory read-only、Discord、usage、telemetry、voice cleanup、Portfolio control は既存基盤に接続されている。
- Hermes memory は native `MEMORY.md` / `state.db` を読む実装で、自作共有メモリ/MCP は混入していない。
- `~/.codex` / `~/.claude` は履歴 viewer が read-only に走査するのみで、編集/削除経路は見つからなかった。
- smoke 緑の裏で、通知 2xx 判定、テスト隔離、redact、delete safety に明確な穴があったため、この PR で fail-closed / 実判定に修正した。

## Fixed In This PR

### High: Portfolio DELETE bypassed the high-severity approval policy

`DELETE /v1/portfolio/assets/{id}` が認証後に registry の asset file を直接削除し、git commit/push まで進める経路だった。ユーザー方針では delete は高 severity で approval gate 必須なので、approval-backed delete flow が実装されるまで 409 approval-required で fail closed にした。

影響: 既存 UI には delete 呼び出しがないため通常操作は変わらない。外部 API からの直接 delete は安全側に止まる。

### Medium: Discord test notification could report success without a 2xx response

`/v1/notifications/discord/test` は webhook POST の HTTP status を見ずに `ok: true` を返していた。Gate2 の Discord 自動受け入れでは Host 側 send 2xx を assert する必要があるため、Discord sender が Bool を返し、非 2xx/通信失敗は 400 として返すようにした。

### Medium: Host and Hermes state were not isolatable for automated acceptance

Host は常に `~/.veqral-host`、Hermes memory reader は常に `~/.hermes` を読んでいた。Gate2 XCUITest や #0 reuse で使い捨て Host/Hermes state を使うときに実環境を汚すリスクがあるため、`VEQRAL_HOST_HOME` / `VEQRAL_HOST_PORT` / `VEQRAL_HOST_WORKING_DIRECTORY` / `HERMES_HOME` を尊重するようにした。

### Medium: Redactor did not cover common webhook/token forms

既存 redactor は bearer/token/key/secret/password/GitHub token の基本形は隠していたが、Discord webhook URL、Slack `xox*` token、OpenRouter `sk-or-*` の形が抜けていた。ログ、監査、通知、Portfolio summary を横断して同じ redactor を使うため、ここに追加した。

## Feature Audit

### Pairing / HMAC

QR pairing URL は pairing code + pairing secret HMAC 付き。通常 API は device token を Keychain に保存し、`X-Veqral-Device` / timestamp / HMAC signature で認証する。timestamp は 5 分以内で検証。手動 code fallback は残っているが、code は pairing 後に rotate される。

Residual risk: 手動 fallback は QR signature より弱いが、既存方針で維持されている。

### Run / WebSocket / Approval

Run create は Host 側 risk classifier で high/low approval を設定し、waitingApproval の run は approve 後に runner が起動する。WebSocket stream は app 側で snapshot/log replay を取り込み、terminal run は resume しない安全策がある。承認 UI は high risk で command/diff context を見せる。

Residual risk: 実ネットワーク断の manual smoke はまだ必要。#A1 の XCUITest では切断復帰までは対象外。

### Codex / Claude Direct History

Host の `AgentHistoryStore` は `~/.codex` / `~/.claude` 配下の JSONL を走査し、line reader で上限付き read-only に読む。write/delete はない。resume identifier はファイル名/パス由来で、直接モードの siloed 方針に沿っている。

Residual risk: JSONL schema 変更時は raw turn fallback になる。adapter 更新耐性はあるが、完全な意味復元ではない。

### Hermes Memory

Project memory は source `veqral-<projectID>` と Hermes native `MEMORY.md` / `state.db` sessions を read-only 表示する。自作 memory store はない。今回 `HERMES_HOME` override を追加し、#0 の隔離 test project と UI/Host visibility を同じ Hermes home に向けられるようにした。

Residual risk: `MEMORY.md` は project source ごとの区分ファイルではなく Hermes native の集約ファイルなので、表示側は source/session と併記して誤読を避ける必要がある。

### Discord / Push

Discord は env/Keychain/config から webhook を解決し、承認待ち/完了/失敗/Portfolio down を redact 済みで送る。今回 test endpoint を 2xx 実判定にした。APNs は flag 裏で、free team では休眠が正しい。

Residual risk: Discord チャンネル到達そのものは外部サービス目視が必要。

### Host Telemetry

CPU/per-core/load、memory pressure、disk、thermalState、uptime、OS/model、battery、network、top processes は公開 API / shell で best-effort 収集。raw 温度/fan は未取得なら `—` で嘘をつかない。

Residual risk: process/top や network は OS 出力依存なので、壊れても主 telemetry は空欄/`—` で degrade する設計。

### Voice Input

iOS Speech + local rule cleanup + Host LLM cleanup。raw audio は保存しない。送信は確認後で、high severity 語は既存 approval gate に乗る。Mac Catalyst は非対応表示。

Residual risk: 実マイク音声は XCUITest で注入できないため、#A1 では transcript injection と人手一言確認に分けるのが妥当。

### Run Usage

Claude stream JSON、Codex usage JSON、usage text、Hermes `state.db` usage を read-only に解析し、Run 詳細へ表示する。列差分は `NULL` fallback で吸収する。

Residual risk: provider が usage を出さない run は空表示になる。概算コストは価格表連動ではなく provider 出力優先。

### Saved Commands

Saved command drafts は local snapshot と iCloud Documents best-effort cache。iCloud が無い場合は local fallback。保存/削除は app 内 state に閉じる。

Residual risk: iCloud conflict resolution は key merge のみで、編集競合 UI はない。

### Portfolio Command Center

Registry repo、discover、status/logs/log-summary、commits、control/promote は Host HMAC 下にある。control/promote は approval run を作る。今回 direct DELETE は fail-closed にした。

Residual risk: discover roots/registry repo/controls が未設定の場合はサンプル/空状態に留まる。#A4 で実 path を入れて検証が必要。

## Code Health Notes

- Production source の `TODO` / `FIXME` / `stub` / `mock` / `fake` / `demo` / `not implemented` は実装 marker としては見つからなかった。
- `fatalError("init(coder:) has not been implemented")` は SwiftUI/AppKit bridge の storyboard 非対応 initializer で、production flow から呼ばれない標準形。
- 大型ファイルは `MacHost/Sources/VeqralHost/main.swift` と `Veqral/AppState.swift` に集中している。今後 #A2〜#A7 で触る場合は feature slice 単位の smoke を先に足してから分割するのが安全。

## Remaining Findings

1. High: Portfolio metadata delete の本実行経路は未実装。今回 fail-closed にしたため危険な直 delete は消えたが、将来 delete UI/API が必要なら approval-backed delete run を実装する。
2. Medium: WebSocket reconnect は実装済みだが、実機でのネットワーク瞬断 smoke は未自動化。
3. Medium: Cross-vendor Hermes #0 は Claude login が Hermes から見える状態になるまで未実施。同一 provider 別 model の #0 は PASS 済み。
4. Medium: Watch/APNs は free team のままでは実通知まで通せない。#A6 で partial を正直に切る必要がある。
5. Low: Run usage cost は provider 出力依存。プロジェクト別予算/累積は #A3 で追加が必要。
