# Veqral Forge

Veqral Forgeは、iPhone/iPadからMac上の複数AI runtimeを、個別chatの集合ではなく**Mission / Workstream / Task / Artifact / Handoff**として指揮するSwiftUIアプリです。

## UI

トップレベルは3面だけです。

1. **ミッション** — Mission、Workstream、Task、成功進捗、critical task、Artifact/Handoff
2. **要対応** — approval、input、review、blocker、unsupportedを分離したOne Human Attention Queue
3. **接続** — `veqral://pair`リンク、Mac Host health、Hermes/Codex/Claude runtime状態

workerごとのchatや生ログは主画面に置きません。ログ、差分、ArtifactはTask詳細で必要なときだけ表示します。

## Domain契約

`MacHost/Sources/VeqralShared/VeqralForgeDomain.swift`がForge側の共有Domainです。

- ForgeのTask IDは安定しており、複数のruntime Run/attemptを関連付けられます。
- failed/cancelledはterminalですが、成功進捗には加算しません。
- failed Taskは未解決blockerとしてcritical候補に残ります。
- ArtifactとHandoffはIDと関連情報を持つfirst-class objectです。HandoffはHost repositoryへ永続化され、clientはgeneric artifactからreview状態を推測しません。
- Run成功だけでHandoffを自動生成しません。
- 明示approvalだけがapprove/reject可能です。
- input/question、review、blocker、unknown/unsupportedはgeneric approvalへ変換しません。

## Runtime adapter

Mac Hostは交換可能なruntime adapterです。iPhone側が表示するruntime名は次の3つだけです。

- Hermes
- Codex
- Claude

provider/modelはoptionalで、iPhone側へmodel IDをhard-codeしません。実際の解決はMac側設定へ委任します。

## 保持しているtransport/security

- ordered endpoint pairing v2とsigned pairing proof
- Keychainに保存するdevice token（UserDefaultsには保存しない）
- HMAC-SHA256 request auth v2
- requestごとのnonceとHost側replay防止
- Run create/list/snapshot/cancel/resume
- explicit approval/rejectとinput送信
- server-side interactionがないRunへのterminal input拒否
- WebSocket stream（指数backoff再接続、persisted log replayの重複排除、snapshot再同期）
- logs/diff/artifacts/content
- APNs登録・low approval action基盤（feature flagは既定OFF）
- credential-like textのredaction

iPhoneへsudo/管理者/Keychain passwordを送信・保存・入力させません。

完全なsecurity／operations contractは[`docs/SECURITY_AND_OPERATIONS.md`](docs/SECURITY_AND_OPERATIONS.md)を参照してください。

## 構成

```text
Veqral/                         iOS/iPadOS/Mac Catalyst Forge shellとremote adapter
MacHost/Sources/VeqralShared/ shared Domain/security/redaction
MacHost/Sources/VeqralHost/   Mac Host runtime/API
MacHost/Tests/                 Domain/security tests
VeqralUITests/                 3面shellとapproval/input境界のUI tests
Scripts/                       isolation、security smoke、PR verification
```

Watch target、AgentSpace、Command Center、旧Dashboard、Portfolio/Sales/Memory/Voice/Telemetry UIはForge shellから削除済みです。Hostの既存APIは互換性と将来adapterのため、このUI整理だけでは削除していません。

## Build / Test

```bash
swift test --package-path MacHost

xcodebuild \
  -project Veqral.xcodeproj \
  -scheme Veqral \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/Veqral-iOS \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing

xcodebuild \
  -project Veqral.xcodeproj \
  -scheme Veqral \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath /tmp/Veqral-Catalyst \
  CODE_SIGNING_ALLOWED=NO \
  build

Scripts/run_forge_ui_tests.sh
Scripts/smoke_forge_client.sh
Scripts/verify_pr_ready.sh
```

## Run Mac Host

```bash
swift run --package-path MacHost VeqralHost
```

Macのメニューバーからpairing link/QRを表示し、Veqralの**接続**画面で読み込みます。

## 検証安全性

自動テストは必ず一時`VEQRAL_HOST_HOME`とfile-backed test secret storeを使います。実ユーザーのlogin/default/search Keychain、LaunchAgents、Hermes設定・認証情報を変更しません。実Keychain統合確認は使い捨てmacOSユーザーまたはVMでのみ行います。

## 現在の境界

- APNsは有料capability/Host設定が揃うまでfeature flag OFFです。
- Hermes更新の通知・staging・canary・atomic promotion・rollback UIは別実装です。更新は必ずユーザー開始とし、自動昇格しません。
- 実機pairing/Run/stream/approval/artifactの最終受け入れには、稼働中のMac Hostと物理iPhoneが必要です。
