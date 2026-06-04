# Direct Clients Reposition

## 方針

Veqral は Codex 直接 / Claude 直接のネイティブ iPhone・iPad・Watch クライアントへ絞る。Hermes のオーケストレーション、delegation、project memory は Hermes Desktop に委譲する。

この PR は `codex/chatgpt-mobile-ux-voice-fix` の上に stacked。#42 のモバイル動線と voice crash 修正を先に main へ入れてから、この reposition を main へ進める。

## 主面

- `Command` 主面を `Codex / Claude` として扱い、paired Mac Host が起動する direct runtime は Codex / Claude の 2択にした。
- モバイル主面の上部に Codex / Claude の app card を置き、各カードから最近の native history を開けるようにした。
- 下部 composer は #42 のまま維持し、選択中の Codex / Claude runtime で direct run を作る。
- mobile drawer / Mac sidebar は `Native Agents`、`Run Tools`、`System`、`Parked` に再編した。

## Hermes の扱い

- Hermes Project / Memory / Portfolio は破壊的削除せず、主面から `Parked` へ移動した。
- Run detail と phone run row から direct run の Hermes handoff CTA を外した。
- Device / diagnostics / inspector 文言は「Hermes Desktop = Delegated」に更新した。

## Keep / Park / Drop

- Keep: Codex direct, Claude direct, read-only history/detail/resume, direct run streaming, approvals, diff/artifacts, usage display, Watch approval scaffold, pairing/HMAC/WebSocket/Tailscale, #42 mobile layout.
- Park: Hermes Projects / Memory, Portfolio command center, live voice entry as secondary action, Discord notification surfaces.
- Drop or demote: in-app Hermes orchestration as a primary surface, direct-run-to-Hermes handoff CTAs, swarm #38-#41 as merge candidates for Veqral.

## Verification

- `swift build` in `MacHost` PASS.
- `swift run VeqralHost smoke-direct-clients` PASS: isolated Codex/Claude history, resume arguments, high-risk approval classification, and diff inspection.
- `swift run VeqralHost smoke-run-usage` PASS.
- `swift run VeqralHost smoke-discord-notifications` PASS.
- `swift run VeqralHost smoke-host-telemetry` PASS.
- `swift run VeqralHost smoke-voice-cleanup` PASS.
- iOS Simulator build PASS.
- Mac Catalyst build PASS.
- Gate2 XCUITest PASS on iPhone Simulator and iPad Simulator.
- Gate2 device leg stopped because the current Xcode destination list did not include the requested physical iPhone UDID.
- `git diff --check`, `plutil -lint`, Localizable missing-key check, and secret grep PASS.
