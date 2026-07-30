# AGENTS.md — Veqral Forge

## Product

Veqral Forgeは、iPhoneからMac上の複数AIをMission / Workstream / Task / Artifact / Handoffとして指揮するアプリ。20+ workerの個別chatや生ログを主画面に並べない。

## Canonical UI

トップレベルは次の3面だけ。

1. ミッション
2. One Human Attention Queue（要対応）
3. 接続 / pairing

旧Command Center、AgentSpace、Dashboard、Watch、Portfolio/Sales/Memory/Voice/Telemetry UIを再導入しない。

## Domain invariants

- ForgeがMission/Task/Artifact/Handoffのsource of truthを持つ。
- Hermes/Codex/Claudeは交換可能なruntime adapter。
- Task IDとRun/attempt IDを同一視しない。
- failed/cancelledを成功進捗へ加算しない。
- Artifact/Handoffを件数や成功状態から捏造しない。
- explicit approval、input、review、blocker、unsupportedを区別する。
- approval provenanceがない項目はapprove/reject不可。unknownはfail-closed。
- provider/model IDをiPhoneへhard-codeしない。Mac側resolverへ委任する。

## Security invariants

保持必須:

- pairing v2 ordered endpoints / signed proof
- HMAC-SHA256 auth v2
- nonce replay防止
- Keychain token storage
- explicit approval policy
- redaction
- Run、WebSocket、artifact transport

iPhoneへsudo/管理者/Keychain passwordを送らない。実ユーザーのKeychain、LaunchAgent、Hermes auth/configを自動テストで変更しない。テストは一時HOME/state/port/file secret storeでfail-closedする。

## Development

- テストを先に追加し、RED→GREEN→refactorで進める。
- Xcode source/target削除はSwift参照、PBXFileReference、PBXBuildFile、Sources phase、schemeを監査してから行う。
- `Veqral-multihost`や他worktreeの未commit差分を混入させない。
- mainへ直接merge/pushしない。Forge PRは最新mainを直接baseにし、別PRへのstacked依存を残さない。
- model download、credential、権限変更、deployは別途明示承認が必要。

## Required verification

```bash
swift test --package-path MacHost
python3 Scripts/check_test_isolation.py
python3 Scripts/smoke_host_security.py
Scripts/smoke_forge_client.sh
xcodebuild -project Veqral.xcodeproj -scheme Veqral -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing
xcodebuild -project Veqral.xcodeproj -scheme Veqral -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build
Scripts/run_forge_ui_tests.sh
Scripts/verify_pr_ready.sh
git diff --check
```

実Host smokeを報告するときは、稼働中Hostへ実際にpair/run/stream/approval/artifactを通した結果だけを成功として扱う。
