# Known issues and risks

確認時点: 2026-06-23 15:44:42 JST

Priority scale:

- P0: blocks safe use or core claim.
- P1: important before wider use/merge.
- P2: should be fixed or documented soon.
- P3: lower urgency.

| ID | Category | Risk | Impact | 発生条件 | 根拠 | 対応案 | 優先度 |
|---|---|---|---|---|---|---|---|
| RISK-001 | correctness | README and some older docs drift from live Hermes/AI-Hub policy state | next maintainer may follow stale model/runtime assumptions | maintainer reads README only | `README.md`, live `/v1/health`, `AGENTS.md`, `18-documentation-drift.md` | update README after handover package review | P1 |
| RISK-002 | AI handoff | Cross-vendor Hermes memory proof remains blocked | core differentiator is proven same-provider but not stronger cross-vendor route | Claude/Anthropic login is not Hermes-readable | `HERMES_CROSS_VENDOR_PR_A7.md`, `AGENTS.md` | restore login/subscription auth and rerun #A7 without API-key fake pass | P1 |
| RISK-003 | UX | Real iPhone/iPad Gate2 items not reverified in this handover turn | simulator PASS may miss permissions/network/device UX issues | voice, telemetry, saved commands, Discord, Memory visibility on devices | `DEVICE_ACCEPTANCE.md`, this verification log | run manual device checklist before wider release | P1 |
| RISK-004 | deployment | Live Host binary replacement/rollback procedure is not fully documented | risky manual deploy or hard rollback | Host binary update needed | `launchctl print`, `AGENTS.md` | document exact build/copy/sign/restart/backup sequence after next deploy | P1 |
| RISK-005 | security | Webhook/API/token values can leak through logs or docs if copied manually | credential compromise | operator pastes raw logs or env output | Redactor tests, `11-secrets-and-credentials-map.md` | continue redaction tests; never use commands that print secrets in docs | P0 |
| RISK-006 | data loss | Editing/deleting `~/.codex`, `~/.claude`, or `~/.hermes/state.db` can break native histories | lost resume/history/memory | manual cleanup or misguided migration | `AGENTS.md`, `HistoryStore`, `HermesMemoryStore` | keep read-only rule; backup before any state work | P0 |
| RISK-007 | operational | Host file state and Keychain token state can diverge | paired devices fail auth | partial restore/delete of `devices.json` or Keychain | `HostState`, `AppState` | re-pair devices; document backup/restore includes Keychain separately | P1 |
| RISK-008 | dependency | AI-Hub resolver/policy availability is external to this repo | Hermes preset apply can fail while app builds pass | AI-Hub root moved, resolver missing, Ollama model unavailable | `HermesControl.swift`, `AGENTS.md` | healthcheck AI-Hub before claiming remote control ready | P1 |
| RISK-009 | deployment | APNs code path exists but current signing/team does not support push | false expectation of push notifications | user expects background push | `AGENTS.md`, entitlements, APNs env map | keep feature flag off; enable only after paid Apple setup | P2 |
| RISK-010 | privacy | Sales Lab may contain business/contact data and generated outreach artifacts | privacy/compliance issue if shared or auto-sent | exporting `~/.veqral-host/local-business-leads` | `SALES_LAB_PR.md`, Host paths | keep no-autosend smoke; redact before sharing artifacts | P1 |
| RISK-011 | correctness | Portfolio real roots/registry are not configured in this handover check | command center may show sample/limited data | operator assumes real discover is active | `PORTFOLIO_REAL_DATA_PR_A4.md`, `smoke-portfolio-real-data` | configure roots/registry and run discover/control smoke | P2 |
| RISK-012 | maintainability | Host `main.swift` is large and owns many domains | future changes can have broad blast radius | editing Host API, state, smokes in one file | line count and code inspection | add focused tests before behavior changes; refactor only with narrow scope | P2 |
| RISK-013 | correctness | Gate2 script has hard-coded default simulator/device destinations | defaults may drift across machines | running script without env overrides | `Scripts/run_gate2_xcuitests.sh`, current build used explicit available IDs | pass destination env vars from current `xcrun simctl list` | P2 |
| RISK-014 | documentation | Four untracked handoff/status files exist outside docs package | important context may remain outside canonical docs | maintainer ignores untracked files | `git status --short --branch` | decide whether to archive/import/delete after review; do not delete silently | P2 |
| RISK-015 | operational | Watch simulator build PASS does not prove real Watch connectivity/cellular | Watch approval may fail in real use | real Watch/Tailscale/cellular/APNs path | `WATCH_APPROVAL_PR_A6.md`, Watch build result | run real Watch checklist | P2 |
| RISK-016 | scalability | Local JSON state files may grow or conflict under concurrent operations | performance/corruption risk under high run volume | many runs/logs/devices/sales artifacts | Host state file design | consider compaction/locking tests if usage grows | P3 |
| RISK-017 | privacy | AI-Hub session digest writes curated run notes into Obsidian | sensitive run summary could sync/share unexpectedly | vault sync enabled or note includes sensitive detail | `AIHubSessionDigestBridge`, `AGENTS.md` | keep redaction; document vault sync policy | P1 |
| RISK-018 | AI handoff | Future agent may over-index on model IDs instead of policy lanes | brittle runtime advice and wrong fixes | reading old README/status notes | user/AGENTS preference, #47 | use policy names and resolver, not hard-coded IDs, unless verifying a specific transcript | P2 |

## Residual risk after this handover

This package reduces AI-only context risk, but it does not complete live real-device acceptance, APNs setup, cross-vendor proof, or deployment procedure hardening. Those are intentionally listed in `14-open-questions.md` and `17-next-actions.md`.
