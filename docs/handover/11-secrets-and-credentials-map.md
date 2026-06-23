# Secrets and credentials map

確認時点: 2026-06-23 15:44:42 JST

No secret values are recorded in this file. This file records only key names, locations, expected formats, and failure behavior.

## Secret storage principles

| Principle | Meaning | 根拠 |
|---|---|---|
| No secret values in repo docs | Document names/locations only | user instruction, `AGENTS.md` |
| Device tokens in Keychain | App and Host store pairing auth material outside JSON docs | `Veqral/AppState.swift`, `MacHost/Sources/VeqralHost/main.swift` |
| Logs must redact | Host/shared redactor masks webhook/API/token-looking strings | `VeqralRedactor.swift`, Redactor tests |
| Codex/Claude history read-only | Native auth/history is not edited by Veqral | `AGENTS.md`, `HistoryStore` |
| Cross-vendor proof cannot use API-key fallback | avoid fake pass; login/subscription auth required | `AGENTS.md`, `HERMES_CROSS_VENDOR_PR_A7.md` |

## Runtime secrets and credential references

| Key / account | Used by | Expected format | Set in | Dev/prod difference | Rotation impact | Unset behavior | Owner/place to confirm |
|---|---|---|---|---|---|---|---|
| App Keychain service `dev.hiroyuki.veqral.app`, account `remote-host:<deviceID>` | Veqral app remote Host auth | device token string | iOS/macOS Keychain | per device | device must re-pair | Host API calls fail auth | app device / Keychain |
| Host Keychain service `dev.hiroyuki.veqral.host`, account `device:<deviceID>` | Host HMAC auth | device token string | Mac Keychain | per paired device | device must re-pair | app auth fails | Mac Keychain |
| `VEQRAL_DISCORD_WEBHOOK` | Host Discord notifications | Discord webhook URL | LaunchAgent env or shell env | same mechanism | notifications fail until updated | Discord notifications absent | Mac Host operator |
| `VEQRAL_PORTFOLIO_DISCORD_WEBHOOK` | legacy Portfolio Discord fallback | Discord webhook URL | env | legacy fallback | Portfolio notifications fail | falls back to other webhook sources | Mac Host operator |
| Keychain account `discord:webhook` | Discord webhook fallback | Discord webhook URL | Host Keychain | local | notifications fail until updated | falls back to config or absent | Mac Keychain |
| Keychain account `portfolio:discord-webhook` | legacy Portfolio webhook fallback | Discord webhook URL | Host Keychain | local | Portfolio notifications fail | falls back to config or absent | Mac Keychain |
| `VEQRAL_APNS_KEY_ID` | APNs sender | Apple key id | env/config/Keychain | future paid setup | push breaks until updated | APNs sender unavailable | Apple Developer owner |
| `VEQRAL_APNS_TEAM_ID` | APNs sender | Apple Team ID | env/config/Keychain | future paid setup | push breaks until updated | APNs sender unavailable | Apple Developer owner |
| `VEQRAL_APNS_KEY_PATH` | APNs sender | local `.p8` key path | env/config/Keychain | future paid setup | push breaks until path updated | APNs sender unavailable | Apple Developer owner |
| `VEQRAL_APNS_BUNDLE_ID` | APNs sender | app bundle id | env/config/Keychain | future paid setup | push targets wrong app if stale | APNs sender unavailable | Apple Developer owner |
| `VEQRAL_APNS_ENVIRONMENT` | APNs sender | `development` or production env | env/config/Keychain | dev/prod differs | wrong APNs endpoint | defaults to development if absent | Apple Developer owner |
| `VEQRAL_PUSH_ENABLED` | Host push feature flag | boolean-like string | env/config | disabled by default/current policy | push on/off | false/off if absent | Host operator |
| `VEQRAL_HERMES_LOCAL_TOKEN` | local Hermes API token check | token string | env | local only | local Hermes API auth changes | fallback to env file if configured | Host operator |
| `VEQRAL_HERMES_LOCAL_ENV` | local env file path for Hermes token | file path | env | local only | token lookup changes | no local token from file | Host operator |
| `~/.hermes/auth.json` | Hermes providers/login | provider auth JSON | Hermes home | per user/Mac | Hermes provider auth may fail | memory/model smokes fail | Hermes owner |
| `VEQRAL_MEMTEST_API_KEY_A/B` | memory verifier custom endpoints | API key string | env for smoke only | test-only | smoke route affected | custom endpoint smoke blocked | test runner |
| `VEQRAL_MEMTEST_API_KEY_ACCOUNT_A/B` | memory verifier Keychain lookup | Keychain account name | env | test-only | smoke route affected | custom endpoint smoke blocked | test runner |
| `VEQRAL_MEMTEST_KEYCHAIN_SERVICE` | memory verifier Keychain service override | service name | env | test-only | key lookup changes | default Host service used | test runner |
| `VEQRAL_MEMTEST_OPENROUTER_KEY_ACCOUNT` | memory verifier OpenRouter account | Keychain account name | env | test-only | OpenRouter smoke route affected | fallback account used | test runner |
| `VEQRAL_MEMTEST_ANTHROPIC_KEY_ACCOUNT` | memory verifier Anthropic account | Keychain account name | env | test-only | Anthropic API-key route affected | fallback account used | test runner |
| `OPENAI_API_KEY` | memory verifier non-local custom route or placeholder for local Ollama | API key or local placeholder | env only | dev/local differs | custom smoke affected | non-local custom route blocked | provider owner |
| `ANTHROPIC_API_KEY` | memory verifier preflight detection | API key string | env only | should not be used for fake #A7 pass | smoke route affected | Anthropic API-key route unavailable | provider owner |
| GitHub CLI token | `gh` and GitHub-backed Portfolio features | OAuth/token in gh credential store | outside repo | per user | `gh`/GitHub calls fail | GitHub inspection/features fail | GitHub owner |
| Apple signing credentials | real device/app/watch builds | Xcode account/cert/profile | Xcode/Keychain | dev/prod differ | device builds fail | simulator builds still possible | Apple Developer owner |
| Tailscale identity | device-to-Mac network | Tailscale account/device auth | Tailscale app/account | local network-specific | remote reachability fails | local loopback health still works | Tailscale owner |

## Non-secret but operationally important environment variables

| Env | Purpose | Default / behavior | 根拠 |
|---|---|---|---|
| `VEQRAL_HOST_HOME` | Host state folder | default `~/.veqral-host` | `HostConfig.folder` |
| `VEQRAL_HOST_PORT` | Host API port | default config/7878 path | `HostConfig` |
| `VEQRAL_HOST_WORKING_DIRECTORY` | default run cwd | env override | `HostConfig` |
| `VEQRAL_DISABLE_DISCORD_WEBHOOK` | disable webhook lookup | true disables | `HostConfig.discordWebhookURL` |
| `VEQRAL_PORTFOLIO_REGISTRY_REPO` | Portfolio registry repo | optional | `HostConfig` |
| `VEQRAL_PORTFOLIO_REGISTRY_PATH` | Portfolio registry local path | optional | `HostConfig` |
| `VEQRAL_PORTFOLIO_CODE_ROOTS` | Portfolio code discovery roots | optional list | `HostConfig` |
| `VEQRAL_PORTFOLIO_ENGAGEMENT_ROOTS` | Portfolio engagement roots | optional list | `HostConfig` |
| `VEQRAL_AIHUB_ROOT` | AI-Hub root | default `~/Documents/AI-Hub/hermes-hub` in Hermes control | `HostConfig`, `HermesControl.swift` |
| `VEQRAL_AIHUB_CONFIG` | AI-Hub digest config | optional | `AIHubSessionDigestBridge` |
| `AI_HUB_CONFIG` | fallback AI-Hub config | optional | `AIHubSessionDigestBridge` |
| `VEQRAL_AIHUB_DIGEST_ENABLED` | digest bridge force enable | boolean-like | `HostConfig.aiHubDigestEnabled` |
| `VEQRAL_AIHUB_DIGEST_DISABLED` | digest bridge disable | boolean-like | `HostConfig.aiHubDigestEnabled` |
| `VEQRAL_HERMES_CONFIG` | Hermes config path | default `~/.hermes/config.yaml` | `HermesControl.swift` |
| `VEQRAL_HERMES_VAULT` | vault root for presets/approvals | unset disables vault features | `HermesControl.swift` |
| `HERMES_HOME` | Hermes home override | default `~/.hermes` | `HermesMemoryStore` |
| `CODEX_HOME` | Codex history override | default `~/.codex` | `HistoryStore` |
| `CLAUDE_CONFIG_DIR` | Claude config/history override | precedence before `CLAUDE_HOME` | `HistoryStore` |
| `CLAUDE_HOME` | Claude home override | default `~/.claude` | `HistoryStore` |
| `VEQRAL_UI_TESTING` | app UI test behavior | enables injected state | `Veqral/AppState.swift`, `Veqral/RootView.swift` |
| `VEQRAL_UI_TEST_*` | XCUITest pairing/runtime/project/voice injection | test only | `Scripts/run_gate2_xcuitests.sh`, app code |
| `VEQRAL_GATE2_*` | Gate2 script destinations/ports/project | test only | `Scripts/run_gate2_xcuitests.sh` |
| `VEQRAL_MEMTEST_*` | memory verifier provider/model/auth settings | test only | `VeqralHostSmoke/main.swift` |
| `HERMES_EXECUTABLE` | memory verifier Hermes binary override | optional | `VeqralHostSmoke/main.swift` |

## Leakage risk notes

| Risk | Why | Mitigation |
|---|---|---|
| Webhook URL in logs/docs | Discord webhook is a bearer credential | redactor tests, never paste value in docs |
| Device token mismatch | pairing auth spans file state and Keychain | re-pair instead of hand-editing tokens |
| Provider API keys in smoke env | env can leak via shell history/process inspection | prefer login auth or Keychain; do not record values |
| Hermes auth file exposure | may contain provider auth | do not copy into docs; only symlink in isolated smoke as code does |
| APNs key path/key exposure | `.p8` is production-like credential | keep outside repo and rotate via Apple Developer if leaked |

## Confirmation commands

Use these only to confirm presence, not to print secret values:

```bash
security find-generic-password -s dev.hiroyuki.veqral.host -a 'device:<deviceID>'
security find-generic-password -s dev.hiroyuki.veqral.app -a 'remote-host:<deviceID>'
```

Do not run commands with `-w` unless the user explicitly asks to retrieve a value for a secure rotation task.
