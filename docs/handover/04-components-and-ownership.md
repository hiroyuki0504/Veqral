# Components and ownership

確認時点: 2026-06-23 15:44:42 JST

| コンポーネント | パス | 責務 | 入力 | 出力 | 依存先 | 依存される側 | 設定項目 | テスト | 既知の問題/注意 |
|---|---|---|---|---|---|---|---|---|---|
| Veqral iOS/iPad/Mac app | `Veqral/*.swift` | UI、状態、Host API client、local persistence | user command, pairing URL, voice text | Run UI, approvals, memory, Hermes control | Mac Host, Keychain, UserDefaults | user workflow | `VEQRAL_UI_TEST_*` | Xcode build, Gate2 XCUITest | 実機 Gate2 は今回未確認。 |
| App state/store | `Veqral/AppState.swift` | `CommandCenterStore`, `RemoteHostClient`, app state persistence | Host responses, user actions | `command-center-state.json`, Keychain token | `VeqralRedactor`, URLSession | all screens | app Keychain service `dev.hiroyuki.veqral.app` | iOS build | 大型ファイル。API route 変更時に同時更新。 |
| Command center UI | `Veqral/CommandCenterViews.swift` | primary command/runs/approvals layout | store state | responsive views | `AppState`, `Theme` | RootView | none | Xcode build | iPhone/iPad/Catalyst layout影響。 |
| Screens | `Veqral/Screens.swift` | Devices, Portfolio, Sales Lab, Memory, Hermes, Approvals | store state | SwiftUI screens | `AppState` | navigation | none | Xcode build | Sales Lab `mock` は domain wording。 |
| Navigation model | `Veqral/Models.swift` | tabs / groups / symbols | enum cases | UI navigation | RootView | App UI | none | Xcode build | 新画面追加時に更新。 |
| Mac Host app | `MacHost/Sources/VeqralHost/main.swift` | LaunchAgent app, HTTP server, HMAC auth, runs, smokes | HTTP requests, env, config, Keychain | JSON API, logs, state files | AppKit, Network, Security, CLIs | Veqral App/Watch | `VEQRAL_*`, `HERMES_HOME`, `CODEX_HOME`, `CLAUDE_*` | Swift build/test, 17 smokes | route と model が同居。編集時は blast radius 大。 |
| Host config | `HostConfig` in `main.swift` | Host defaults/env overrides | `config.json`, env | resolved config | Keychain, env | Host server | `VEQRAL_HOST_*`, portfolio, Discord, AI-Hub, APNs | Host smokes | default AI-Hub root は `~/Documents/AI-Hub/hermes-hub`。LaunchAgent は env で上書き。 |
| Host state | `HostState` in `main.swift` | runs/logs/devices/pairing/audit/processes | Run requests, events | `runs.json`, `logs/*`, `devices.json`, `audit.log` | `HostConfig.folder` | API routes | `VEQRAL_HOST_HOME` | many smokes | device tokenは Host Keychain。 |
| CLI runner/adapters | `AgentRunner`, adapters in `main.swift` | Hermes/Codex/Claude/Shell execution | prompt, cwd, engine, provider/model | process logs, session id, usage | `hermes`, `codex`, `claude`, `/bin/zsh` | Run API | CLI auth/config | build/smokes | real agent execution can cost/time. |
| Hermes control | `MacHost/Sources/VeqralHost/HermesControl.swift` | read/update Hermes config, load presets, decide vault approvals | HMAC API, `presets.md`, approval md | updated config, moved approval files | `~/.hermes/config.yaml`, AI-Hub resolver, vault | App/Watch Hermes screen | `VEQRAL_HERMES_CONFIG`, `VEQRAL_HERMES_VAULT`, `VEQRAL_AIHUB_ROOT` | `smoke-hermes-control` | line-based YAML edit; backup `.veqral-bak` created. |
| Hermes memory store | `HermesMemoryStore` in `main.swift` | list/read/diff/write Hermes memory files and project memory snapshot | memory API requests | memory file data, project sessions | `~/.hermes/memories`, `~/.hermes/state.db`, sqlite3 | Memory screen | `HERMES_HOME` | `smoke-project-memory` | project memory is read-only; general USER/MEMORY/skills editable via API. |
| History store | `HistoryStore` in `main.swift` | read Codex/Claude history without modifying | list/detail requests | redacted/truncated session turns | `~/.codex`, `~/.claude` | History UI | `CODEX_HOME`, `CLAUDE_CONFIG_DIR`, `CLAUDE_HOME` | build | read-only policy is critical. |
| AI-Hub digest bridge | `AIHubSessionDigestBridge` in `main.swift` | write completed non-shell runs to AI-Hub session-digest | HostRun/logs/config | Obsidian session digest note | `skills/session-digest/scripts/session_digest.py` | HostState finish | `VEQRAL_AIHUB_*`, `AI_HUB_CONFIG` | `smoke-aihub-digest-bridge` | shell runs intentionally excluded. |
| Portfolio store | `PortfolioStore` in `main.swift` | asset registry/discover/status/logs/control/promote | portfolio API requests | assets YAML, status/log summaries | git, local roots, gh, Discord | Portfolio screen, Sales promotion | `VEQRAL_PORTFOLIO_*` | `smoke-portfolio-real-data` | real roots currently unset in smoke. |
| Sales Lab store | `SalesLeadStore` in `main.swift` | local business leads, audit, redesign, proposal, outreach status | manual lead/CSV/official URL | JSON, HTML, SVG, PDF-ish artifacts | official website URL, file system | Sales Lab UI | Host home | 7 sales smokes | Google Places discovery disabled 501. No autosend. |
| Redactor | `MacHost/Sources/VeqralShared/VeqralRedactor.swift` | redact webhook/tokens/API keys | text | redacted text | Foundation regex | Host/App/tests | none | `swift test`, smoke redaction | Must update when adding new secret formats. |
| Watch app | `VeqralWatch/VeqralWatchApp.swift` | Watch approval/preset UI | paired Host config | approve/reject/preset API calls | Host HMAC endpoints | user Watch | Keychain token | Watch Simulator build | real Watch/APNs not confirmed. |
| Gate2 UI tests | `VeqralUITests/Gate2AcceptanceUITests.swift`, `Scripts/run_gate2_xcuitests.sh` | end-to-end acceptance | pairing URL, memory fact env | XCUITest pass/fail | Mac Host, Hermes, Discord sink | release gate | `VEQRAL_GATE2_*` | script | real LLM smoke included. |
| Xcode project | `Veqral.xcodeproj/project.pbxproj` | target/scheme/build settings | source files/settings | app/watch/ui test targets | Xcode | all Apple builds | bundle IDs, deployment targets | xcodebuild | pbxproj manual edits are risky. |
| LaunchAgent | `~/Library/LaunchAgents/dev.hiroyuki.veqral.host.plist` | login-time Host start/restart | launchd | running Host | binary, env | runtime | plist env | `launchctl print` | repo外。docs に値以外の key/path のみ記録。 |

## Component relationship notes

- `RemoteHostClient` methods in `Veqral/AppState.swift` map directly to `/v1/*` routes in `MacHost/Sources/VeqralHost/main.swift`.
- `HermesControl.swift` is intentionally file-based. It works even if Hermes Desktop is idle because it reads/writes config/vault files directly.
- `VeqralRedactor.swift` is included both in MacHost SwiftPM and Xcode app target.
- Host smoke commands live in `VeqralHostApp.main()` before normal app startup.
- `VeqralHostSmoke` is a separate executable for real Hermes memory inheritance, not the same as `VeqralHost smoke-*`.

根拠:
- `MacHost/Package.swift`
- `MacHost/Sources/VeqralHost/main.swift`
- `MacHost/Sources/VeqralHost/HermesControl.swift`
- `Veqral/AppState.swift`
- `Veqral.xcodeproj/project.pbxproj`
