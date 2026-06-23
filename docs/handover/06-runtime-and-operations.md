# Runtime and operations

確認時点: 2026-06-23 15:44:42 JST

## Runtime overview

| 実行単位 | 役割 | 起動方法 | 確認済み状態 | 根拠 |
|---|---|---|---|---|
| Veqral iOS/iPadOS app | iPhone/iPad から Host を操作する UI | Xcode build/install | Simulator build PASS。実機 UI 操作は今回未確認。 | command: `xcodebuild ... -scheme Veqral ... iOS Simulator ... build` |
| Mac Catalyst app | Mac 上で同じ UI を使う | Xcode Mac Catalyst build | build PASS | command: `xcodebuild ... platform=macOS,variant=Mac Catalyst ... build` |
| VeqralWatch | Watch 承認 UI | Xcode Watch Simulator build | Watch Simulator build PASS。実機は未確認。 | command: `xcodebuild ... -scheme VeqralWatch ... watchOS Simulator ... build` |
| VeqralHost | Mac Host API / Run orchestrator | LaunchAgent or direct Swift run | live LaunchAgent running, `/v1/health` ok | command: `launchctl print ...`, `curl .../v1/health` |
| VeqralHostSmoke | Host smoke/verifier CLI | `swift run --package-path MacHost VeqralHostSmoke ...` | `verify-memory-inheritance` は今回未実行 | `MacHost/Sources/VeqralHostSmoke/main.swift` |
| Hermes Agent | Project memory and model orchestration | external `hermes` CLI | live health reports Hermes v0.17.0 | command: `curl .../v1/health` |
| Codex CLI | direct Codex runtime | external `codex` CLI | live health reports `codex-cli 0.130.0` | command: `curl .../v1/health` |
| Claude Code CLI | direct Claude runtime | external `claude` CLI | live health reports `2.1.170` | command: `curl .../v1/health` |
| Ollama | local OpenAI-compatible model backend | external `ollama serve` | process observed running; real model use not tested in this turn | command: `ps ... ollama` |

## Local launch

### Mac Host direct run

```bash
swift run --package-path MacHost VeqralHost
```

確認状態: build and smoke commands were executed, but a long-lived direct Host run was not started because the live LaunchAgent was already running.

根拠:
- `MacHost/Package.swift`
- command: `swift build --package-path MacHost`
- command: `launchctl print gui/$(id -u)/dev.hiroyuki.veqral.host`

### Live LaunchAgent

Live Host is managed by a user LaunchAgent:

| 項目 | 現在値/状態 | 根拠 |
|---|---|---|
| label | `dev.hiroyuki.veqral.host` | command: `launchctl print gui/$(id -u)/dev.hiroyuki.veqral.host` |
| program | `~/.veqral-host/bin/VeqralHost` | command: `launchctl print ...` |
| stdout log | `~/Library/Logs/VeqralHost.out.log` | command: `launchctl print ...` |
| stderr log | `~/Library/Logs/VeqralHost.err.log` | command: `launchctl print ...` |
| port | `7878` | command: `curl -fsS http://127.0.0.1:7878/v1/health` |
| Tailscale IP | `100.96.40.99` | command: `curl -fsS http://127.0.0.1:7878/v1/health` |
| KeepAlive / RunAtLoad | enabled | command: `launchctl print ...` |

Restart command, not executed in this handover turn because it would interrupt the live Host:

```bash
launchctl kickstart -k gui/$(id -u)/dev.hiroyuki.veqral.host
```

Stop command, not executed in this handover turn:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/dev.hiroyuki.veqral.host.plist
```

## Health check

```bash
curl -fsS http://127.0.0.1:7878/v1/health
```

直近結果:

| Field | Result |
|---|---|
| `status` | `ok` |
| `port` | `7878` |
| `tailscaleIP` | `100.96.40.99` |
| `hermesVersion` | Hermes Agent v0.17.0, upstream bb7ff7dc |
| `codex` | `codex-cli 0.130.0` |
| `claude` | `2.1.170 (Claude Code)` |
| `shell` | `zsh 5.9 (arm64-apple-darwin25.0)` |

根拠:
- command: `curl -fsS http://127.0.0.1:7878/v1/health`

## Ports and network

| Port / endpoint | 用途 | 認証 | 根拠 |
|---|---|---|---|
| `127.0.0.1:7878` | local Host API | health is unauthenticated; app routes use HMAC/device token | `MacHost/Sources/VeqralHost/main.swift`, curl health |
| `100.96.40.99:7878` | Tailscale経由の mobile access | HMAC/device token after pairing | `AGENTS.md`, health response |
| Gate2 temp host port | XCUITest isolated Host | pairing URL injected by env | `Scripts/run_gate2_xcuitests.sh` |
| Gate2 temp webhook port | local Discord webhook receiver for tests | local-only test | `Scripts/run_gate2_xcuitests.sh` |

## Logs

| Log | Location | 内容 | 注意 |
|---|---|---|---|
| LaunchAgent stdout | `~/Library/Logs/VeqralHost.out.log` | Host stdout | secret values must be redacted before sharing |
| LaunchAgent stderr | `~/Library/Logs/VeqralHost.err.log` | Host stderr/errors | secret values must be redacted before sharing |
| Host run logs | `~/.veqral-host/logs/` | per-run replay logs | paired users may see redacted excerpts |
| Host audit log | `~/.veqral-host/audit.log` | pairing/approval/run audit | preserve before destructive debugging |
| AI-Hub session notes | `<vault>/90_Org/Sessions/` | curated run digest | not a raw source of truth |

根拠:
- `MacHost/Sources/VeqralHost/main.swift`
- command: `launchctl print gui/$(id -u)/dev.hiroyuki.veqral.host`

## Failure triage order

1. Confirm Host process:

```bash
launchctl print gui/$(id -u)/dev.hiroyuki.veqral.host
```

2. Confirm local health:

```bash
curl -fsS http://127.0.0.1:7878/v1/health
```

3. Confirm Tailscale reachability from the device network. 未実行 in this turn.

4. Check logs:

```bash
tail -200 ~/Library/Logs/VeqralHost.err.log
tail -200 ~/Library/Logs/VeqralHost.out.log
```

5. Check app pairing/device token state:

- App Keychain service: `dev.hiroyuki.veqral.app`
- Host Keychain service: `dev.hiroyuki.veqral.host`
- Host paired devices file: `~/.veqral-host/devices.json`

6. For Hermes-specific failures, check:

- `VEQRAL_HERMES_CONFIG`
- `VEQRAL_HERMES_VAULT`
- `VEQRAL_AIHUB_ROOT`
- `~/.hermes/auth.json`
- `~/.hermes/state.db`
- AI-Hub resolver script `scripts/hermes-monthly-switch`

7. For direct Codex/Claude history/resume failures, check read-only history roots:

- `~/.codex`
- `~/.claude`

Do not edit those roots from Veqral.

## Common failures

| Symptom | Likely cause | Check | Fix / next action |
|---|---|---|---|
| Device cannot connect after QR pairing | Host unreachable over Tailscale/local network or token mismatch | health from Mac, app connection strip, `devices.json` | re-pair device; do not hand-edit Keychain values |
| `/v1/health` local fails | LaunchAgent stopped or binary missing | `launchctl print ...`, log files | rebuild Host, then restart LaunchAgent |
| Hermes preset list empty | `VEQRAL_HERMES_VAULT` unset or missing `90_Org/presets.md` | `/v1/hermes/control` | set vault env in LaunchAgent and restart |
| Hermes policy apply fails | AI-Hub resolver missing, Ollama/model/provider unavailable | Host log, `scripts/hermes-monthly-switch resolve/apply` | fix AI-Hub config or installed model/provider |
| Discord notifications absent | webhook unset/disabled or redacted invalid URL | Host config/env, smoke-discord-notifications | set webhook via env/Keychain/config, then test |
| APNs push absent | push feature/capability intentionally disabled for free team | entitlements, Host env | requires paid Apple Developer setup |
| Sales discovery returns unavailable | Google Places discovery intentionally 501-disabled | `SALES_LAB_PR.md`, route behavior | build a separate PR after ToS/quota/key design |

## Scheduler / cron / daemons

確認できた常駐要素は user LaunchAgent `dev.hiroyuki.veqral.host`。リポジトリ内に cron, systemd, Docker Compose, Kubernetes manifests are not present in this checkout.

根拠:
- command: `find . -maxdepth 3 -type f`
- command: `launchctl print gui/$(id -u)/dev.hiroyuki.veqral.host`
