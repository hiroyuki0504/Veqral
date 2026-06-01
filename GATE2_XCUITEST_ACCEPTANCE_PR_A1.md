# Gate2 XCUITest Acceptance PR A1

## Scope

Gate2 の 5 項目を、iPhone Mirroring や座標クリックではなく XCUITest で要素レベルに自動化した。

- 定型コマンド: 保存、chip 再投入、送信
- ホスト状態: CPU、メモリ、ディスク、熱状態の描画
- Hermes memory visibility: #0 smoke が実際に書いた Hermes native memory fact の表示
- Discord webhook: テスト通知ボタンから Host が 2xx を受けたことの表示
- voice input: 注入 transcript から raw/cleaned 表示、確認送信、高 severity 承認 Gate への投入

実音声そのものは XCUITest からマイクへ注入できないため、実マイクの一言確認は人手に残す。Discord の外部チャンネル到達確認も、エージェントは Discord を読めないため人手に残す。

## Automation

再実行コマンド:

```sh
Scripts/run_gate2_xcuitests.sh
```

シミュレータだけ確認する場合:

```sh
VEQRAL_GATE2_SKIP_DEVICES=1 Scripts/run_gate2_xcuitests.sh
```

実機を個別に確認する場合:

```sh
VEQRAL_GATE2_ONLY=iphone-device Scripts/run_gate2_xcuitests.sh
VEQRAL_GATE2_ONLY=ipad-device Scripts/run_gate2_xcuitests.sh
```

## Result

- Real Hermes #0 memory smoke: PASS (`openai-codex/gpt-5.5 -> openai-codex/gpt-5.4`, Hermes native memory only)
- iPhone Simulator XCUITest: PASS
- iPad Simulator XCUITest: PASS
- Local Discord 2xx sink: PASS
- iPhone device XCUITest: BLOCKED by local Xcode signing/account state
- iPad device XCUITest: BLOCKED by the same local Xcode signing/account state; the physical devices are also reported offline by `xcrun xctrace list devices`

The full run reached the physical-device phase only after both simulator runs passed. The physical iPhone retry with `-allowProvisioningUpdates` failed before test launch:

```text
No Accounts: Add a new account in Accounts settings.
No profiles for 'dev.hiroyuki.veqral.ui-tests.xctrunner' were found.
```

This Mac currently has no provisioning profiles under `~/Library/MobileDevice/Provisioning Profiles`, and the CLI cannot see an Apple account capable of creating the XCUITest runner profile. No product failure was observed in the simulator acceptance path.

## Human Residuals

- Discord: visually confirm the test notification appears in the real Discord channel when a real webhook is configured.
- Voice: speak one short phrase on iPhone/iPad to confirm the real microphone and Speech permission path.
- Physical XCUITest: reconnect devices and add/sign into an Apple account in Xcode Settings, then rerun `VEQRAL_GATE2_ONLY=iphone-device` and `VEQRAL_GATE2_ONLY=ipad-device`.

