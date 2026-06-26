# Source index

確認時点: 2026-06-23 15:44:42 JST

信頼度:

- High: current command output or source file in this checkout.
- Medium: existing project handoff/PR doc, likely accurate but may drift.
- Low: memory/context note or inaccessible external state.

## Files read or inspected

| 種別 | 場所 | 何を確認したか | 信頼度 | 備考 |
|---|---|---|---|---|
| repo file | `AGENTS.md` | project role, rules, current state, next handoff | Medium | updated at end of this task |
| repo file | `README.md` | public project description, memory smoke instructions, drift candidates | Medium | some content conflicts with live state |
| repo file | `MacHost/Package.swift` | SwiftPM products/targets/test target | High | no external packages |
| repo file | `MacHost/Sources/VeqralHost/main.swift` | Host config, routes, smokes, state paths, Keychain, redaction, memory/history stores | High | large core file |
| repo file | `MacHost/Sources/VeqralHost/HermesControl.swift` | Hermes config/presets/approvals/AI-Hub policy resolver | High | current policy control source |
| repo file | `MacHost/Sources/VeqralHostSmoke/main.swift` | memory inheritance verifier env and auth behavior | High | test/smoke source |
| repo file | `MacHost/Sources/VeqralShared/VeqralRedactor.swift` | secret redaction patterns | High | covered by tests |
| repo file | `MacHost/Tests/VeqralSharedTests/VeqralRedactorTests.swift` | redaction test scope | High | 2 tests passed |
| repo file | `Veqral/AppState.swift` | app state, API client, Keychain, saved commands, persistence | High | current app data/control source |
| repo file | `Veqral/Screens.swift` | app screens and Sales Lab UI wording | High | inspected through search |
| repo file | `Veqral/CommandCenterViews.swift` | command composer, voice env hooks | High | inspected through search |
| repo file | `Veqral/RootView.swift` | UI test environment behavior | High | inspected through search |
| repo file | `Veqral/Info.plist` | permissions, URL scheme, ATS | High | lint passed |
| repo file | `Veqral/Veqral.entitlements` | push entitlement placeholder/path | High | lint passed |
| repo file | `Veqral/en.lproj/Localizable.strings` | localization validity | High | lint/key parity passed |
| repo file | `Veqral/ja.lproj/Localizable.strings` | localization validity | High | lint/key parity passed |
| repo file | `VeqralWatch/VeqralWatchApp.swift` | Watch scaffold | High | simulator build passed |
| repo file | `VeqralUITests/Gate2AcceptanceUITests.swift` | Gate2 UI test target | High | not executed this turn |
| repo file | `Scripts/run_gate2_xcuitests.sh` | Gate2 env, isolated Host, simulator/device flow | High | not executed this turn |
| repo file | `DEVICE_ACCEPTANCE.md` | real-device manual checklist | Medium | not executed this turn |
| repo file | `HERMES_MEMORY_INHERITANCE_PR0.md` | Gate1 memory inheritance transcript/status | Medium | prior result, not rerun |
| repo file | `HERMES_CROSS_VENDOR_PR_A7.md` | cross-vendor blocked proof and no fake pass policy | Medium | prior result, not rerun |
| repo file | `HERMES_REMOTE_CONTROL_PR.md` | Hermes remote control phase notes and drift candidate | Medium | title/wording drifts after #47 |
| repo file | `SALES_LAB_PR.md` | Sales Lab safety/no-autosend/disabled discovery | Medium | smokes rerun |
| repo file | `WATCH_APPROVAL_PR_A6.md` | Watch partial status | Medium | simulator build now passes |
| repo file | `PORTFOLIO_REAL_DATA_PR_A4.md` | portfolio sample/real roots status | Medium | sample smoke rerun |
| repo file | `PROGRESS.md` | concise prior progress including #A7 | Medium | can drift |
| repo file | root PR docs such as `*_PR*.md`, `AUDIT.md`, `IMPLEMENTATION_AUDIT.md` | historical feature status | Medium | not every line revalidated |
| untracked file | `CURRENT_APP_HANDOFF_20260621.md` | existence only in source index/current-state | Low | not imported; review open |
| untracked file | `CURRENT_IMPLEMENTATION_STATUS_20260606.md` | existence/search hits only | Low | not imported; review open |
| untracked file | `CURRENT_IMPLEMENTATION_STATUS_20260607.md` | existence/search hits only | Low | not imported; review open |
| untracked file | `VEQRAL_AI_HANDOFF_TEXTBOX.md` | existence/search hits only | Low | not imported; review open |
| memory | `/Users/hiroyuki/.codex/memories/MEMORY.md` | prior Veqral/AI-Hub/Hermes preferences and cautions | Low to Medium | used as context, not as live fact |

## Commands executed

| 種別 | 場所 | 何を確認したか | 信頼度 | 備考 |
|---|---|---|---|---|
| command | `pwd` | repo root | High | `/Users/hiroyuki/Documents/Veqral` |
| command | `git status --short --branch` | branch, untracked files, local main drift | High | current branch created from `origin/main` |
| command | `git fetch origin` | remote refs | High | ran before branch creation |
| command | `git log -1 --oneline --decorate` | latest commit | High | `a73d87f` |
| command | `git remote -v` | GitHub remote | High | public repo checked via `gh` |
| command | `gh repo view ...` | repo visibility/default branch | High | GitHub app/CLI authenticated |
| command | `gh issue list ...` | open issues | High | none returned |
| command | `gh pr list ...` | PR list | High | #47 merged, #46/#45 draft open |
| command | `find . -maxdepth 3 -type f` | file layout and absence of `.github`/Docker/k8s files | High | generated `.build` existence also seen |
| command | `rg --files` / `rg -n ...` | source/config/TODO/env scans | High | used instead of broad full text reading |
| command | `swift --version` | Swift version | High | Apple Swift 6.3.2 |
| command | `xcodebuild -version` | Xcode version | High | Xcode 26.5 |
| command | `xcodebuild -project Veqral.xcodeproj -list` | schemes/targets | High | `Veqral`, `VeqralWatch` |
| MCP | XcodeBuildMCP `session_show_defaults` | missing session defaults | High | direct MCP build blocked |
| MCP | XcodeBuildMCP `list_schemes` | schemes | High | confirmed |
| MCP | XcodeBuildMCP `list_sims` | simulator availability | High | iOS/watchOS 26.5 sims |
| MCP | XcodeBuildMCP `build_sim` | attempted MCP build | High | failed due missing defaults; `xcodebuild` used instead |
| command | `swift build --package-path MacHost` | Host build | High | PASS |
| command | `swift test --package-path MacHost` | Host tests | High | PASS, 2 tests |
| command | 17 `swift run --package-path MacHost VeqralHost smoke-*` commands | Host smoke coverage | High | all PASS |
| command | `xcodebuild ... iOS Simulator ... build` | iOS simulator app build | High | PASS |
| command | `xcodebuild ... Mac Catalyst ... build` | Mac Catalyst build | High | PASS |
| command | `xcodebuild ... VeqralWatch ... watchOS Simulator ... build` | Watch simulator build | High | PASS |
| command | `curl -fsS http://127.0.0.1:7878/v1/health` | live Host health/tools | High | PASS |
| command | `launchctl print gui/$(id -u)/dev.hiroyuki.veqral.host` | live LaunchAgent state | High | running |
| command | `ls -l ~/.veqral-host/bin/VeqralHost ~/Library/LaunchAgents/dev.hiroyuki.veqral.host.plist` | live binary/plist existence | High | present |
| command | `ps ... ollama/hermes/VeqralHost` | local runtime processes | High | observed |
| command | `devicectl list devices` | physical device availability | High | devices listed; IDs not recorded in docs |
| command | `xctrace list devices` | device/simulator availability | High | iPhone connected, iPad/Watch offline |
| command | `plutil -lint ...` | plist/localization validity | High | PASS |
| command | localization key parity script | en/ja key parity | High | no diff output |
| command | `git diff --check` | whitespace before docs completion | High | PASS |
| command | secret grep | secret leakage scan | High | known dummy/placeholder hits only |
| command | production marker grep | TODO/mock/stub/fake marker scan | High | Sales Lab domain wording only |

## URLs / external locations

| 種別 | 場所 | 何を確認したか | 信頼度 | 備考 |
|---|---|---|---|---|
| URL | `https://github.com/hiroyuki0504/Veqral` | repo identity via remote/gh | High | no web browsing needed |
| local URL | `http://127.0.0.1:7878/v1/health` | live Host health | High | curl checked |
| local/Tailscale | `100.96.40.99:7878` | live Host advertised remote endpoint | High | health/AGENTS |

## Sources not accessed or not fully verified

| 種別 | 場所 | 何を確認したか | 信頼度 | 備考 |
|---|---|---|---|---|
| external settings | GitHub repo Settings / branch protection / secrets | not accessed | Low | needs web/admin check |
| external portal | Apple Developer account / APNs key | not accessed | Low | secrets/certs intentionally not inspected |
| external service | Tailscale admin console | not accessed | Low | only local advertised IP checked |
| external service | Discord real webhook destination | not accessed | Low | local payload smoke only |
| device | real iPhone app flows | not exercised | Low | device connected but not operated |
| device | real iPad app flows | not exercised | Low | xctrace showed offline |
| device | real Watch app flows | not exercised | Low | xctrace showed offline |
| external repo/folder | AI-Hub internals beyond paths/health references | not fully inspected | Low | resolver behavior inferred from source/docs/smoke |
