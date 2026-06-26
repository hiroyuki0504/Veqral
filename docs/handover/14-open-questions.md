# Open questions

確認時点: 2026-06-23 15:44:42 JST

Do not bury unresolved facts in prose. Treat this table as the active unknown queue.

| ID | 質問 | なぜ必要か | 現時点の仮説 | 確認方法 | 確認先 | 優先度 |
|---|---|---|---|---|---|---|
| OQ-001 | Current README should be updated to which Hermes/AI-Hub policy wording? | README is a first-stop doc and currently drifts | Use AI-Hub lane/policy wording and live Hermes v0.17.0 facts | compare README with live health and `AGENTS.md`, then patch README | repo docs + live Host | P1 |
| OQ-002 | Can Claude/Anthropic login become Hermes-readable for #A7? | stronger cross-vendor proof is blocked | user/Hermes environment needs re-auth or provider route repair | run #A7 preflight from `HERMES_CROSS_VENDOR_PR_A7.md` after auth work | Hermes auth setup | P1 |
| OQ-003 | Do real iPhone and iPad pass the 5 current Gate2 manual items? | simulator builds do not prove permission/network UX | likely mostly works, but not confirmed this turn | follow `DEVICE_ACCEPTANCE.md` on both devices | real devices | P1 |
| OQ-004 | Does real external Discord webhook receive all notification types? | local smoke validates payload shape, not external delivery | likely works if webhook env/Keychain is valid | configure webhook secret and trigger approval/run/down tests | Discord server/webhook owner | P1 |
| OQ-005 | What is the exact safe Host deploy/rollback sequence? | live Host is LaunchAgent-managed and user-facing | build/copy/ad-hoc sign/restart was used previously, but exact commands need source | inspect shell history or next deploy; document commands after executing | Mac Host operator | P1 |
| OQ-006 | Are GitHub branch protections, repo secrets, or Actions configured? | affects PR/merge/release safety | no workflows in checkout, but settings may exist | inspect GitHub repo Settings | GitHub web UI | P2 |
| OQ-007 | What is the canonical backup policy for AI-Hub vault and `~/.veqral-host`? | state loss recovery | local-only heavy archives, curated notes may sync, but exact backup path unconfirmed | inspect AI-Hub docs/settings and user backup setup | AI-Hub/vault owner | P2 |
| OQ-008 | Should the four untracked status/handoff files be imported into docs or archived? | they may contain useful context outside Git | probably generated from prior handoffs and not yet tracked | review file content and decide canonical placement | repo root files | P2 |
| OQ-009 | Does `Scripts/run_gate2_xcuitests.sh` default simulator IDs still exist on this machine? | script may fail without env overrides | current successful builds used different explicit simulator IDs | run `xcrun simctl list devices available` and compare; or pass env overrides | local Xcode | P2 |
| OQ-010 | What is the real Portfolio registry/root setup for production-like use? | Portfolio smoke used isolated sample acceptance | real roots/registry are not configured in this turn | set `VEQRAL_PORTFOLIO_*` and run discover/control | Host operator | P2 |
| OQ-011 | Should Sales Lab Google Places discovery be built, and under which ToS/quota/key constraints? | feature is intentionally disabled | wait until API/key/compliance policy is explicit | define Places API policy and secret handling, then separate PR | user/business owner | P2 |
| OQ-012 | Does Watch work on real hardware over Tailscale/cellular? | simulator build does not prove remote approval | scaffold likely compiles, runtime unknown | real Watch pairing, preset, approval tests | real Watch | P2 |
| OQ-013 | When should APNs push be re-enabled? | feature path exists but disabled | only after paid Apple Developer Program | verify Apple membership, entitlements, `.p8`, Host env | Apple Developer owner | P3 |
| OQ-014 | Are App Store/TestFlight distribution goals in scope? | affects signing, capabilities, release docs | current project is local-first, not App Store | ask user before adding distribution work | user | P3 |
| OQ-015 | Which docs should become canonical after this package merges? | avoid duplicate/stale handoff sprawl | `docs/handover/` should be transfer package, `AGENTS.md` should stay short operational handoff | repo review after PR | maintainers | P2 |
