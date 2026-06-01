# PR #9: Mac ホストテレメトリ

## 目的

Devices 画面から、ペアリング済み Mac Host の稼働状態を低頻度で確認できるようにした。生温度やファン回転数は公開 API で確実に取れないため、P0 は `ProcessInfo.thermalState` を主指標にし、取れない値は `—` 表示にする。

## 実装

- Mac Host に authenticated `GET /v1/telemetry` を追加。
- `GET /v1/health` に初回表示用の `telemetry` を同梱。
- Host が次を収集:
  - CPU 全体使用率、per-core 使用率、load average
  - メモリ total/used/free、memory pressure
  - 起動ボリュームの total/free/used%
  - 熱状態（`ProcessInfo.thermalState`）
  - uptime、OS、host、machine model
  - バッテリー/AC 電源（`pmset` best-effort）
  - Tailscale IP、interface throughput（取れる場合）
  - CPU 上位プロセス（best-effort）
- Devices 画面に「ホスト状態」セクションを追加し、表示中だけ 5 秒間隔で telemetry を更新。
- raw 温度、fan、SMART は取得できない環境では `—` を表示し、嘘の数値を出さない。

## Smoke

- `VeqralHost smoke-host-telemetry` で CPU/load/memory/disk/thermal/uptime/process sample を確認。
- 既存 `smoke-run-usage` / `smoke-project-memory` / `smoke-discord-notifications` も通過。

## 残課題

- 実機で Devices 画面を開き、5 秒間隔で CPU/メモリ/熱状態が更新されることを確認する。
- 生温度・fan・SMART は対応環境が見つかった場合だけ best-effort で拡張する。
