# PR2 Portfolio Command Center

## Scope

- Added a first-class Portfolio / 司令塔 surface on top of PR1.
- Added Host-side portfolio registry APIs under existing HMAC authentication.
- Kept the source of truth in a dedicated registry repo at `assets/<id>.yaml`.
- Reused the existing Run approval flow for portfolio controls and local-only repo promotion.

## DoD

- [x] Asset model covers app / engagement / content, source refs, machine-local paths, health, logs, controls, Hermes Project link, backup state, and engagement fields.
- [x] Registry store reads/writes one YAML file per asset and commits/pushes changes when a registry remote is configured.
- [x] Discover merges GitHub repos, configured code roots, and configured engagement roots with GitHub/local dedup.
- [x] Status reports content as n/a, health checks via http/cmd, and fallback process CPU/RSS.
- [x] Logs tail file/cmd sources and redact lines before returning them.
- [x] Log summary runs local Ollama first and only falls back to Claude for difficult error/failure logs.
- [x] Start/stop/restart/deploy controls queue shell runs with high-severity approval.
- [x] Local-only private repo promotion queues `git init` + `gh repo create --private --push` behind approval.
- [x] Discord webhook notification is available for running -> stopped transitions when configured.
- [x] iOS/iPad/Mac Catalyst UI can list, filter, discover, add, edit, inspect, summarize, control, link Project, and promote assets.
- [x] Engagement UI includes client, phase, timeline, deliverables, related apps, and Project link.
- [x] Recent GitHub commits are fetched through Host and shown on the asset detail surface.

## Configuration

- Registry remote: `VEQRAL_PORTFOLIO_REGISTRY_REPO` or `portfolioRegistryRepo`
- Registry path: `VEQRAL_PORTFOLIO_REGISTRY_PATH` or `portfolioRegistryPath`
- Engagement roots: `VEQRAL_PORTFOLIO_ENGAGEMENT_ROOTS` or `portfolioEngagementRoots`
- Code roots: `VEQRAL_PORTFOLIO_CODE_ROOTS` or `portfolioCodeRoots`
- Discord webhook: `VEQRAL_DISCORD_WEBHOOK`, Keychain `portfolio:discord-webhook`, or `portfolioDiscordWebhook`

## Residuals

- iPhone/iPad real-device E2E still needs manual acceptance against the running Mac Host: discover -> edit control -> approval -> run log.
- Engagement/code roots are intentionally blank until configured on the Host.
- Asset log display is fetched through the portfolio logs endpoint; operation logs still stream through the existing Run WebSocket after approval.
- Promote queues repo creation/push, but the asset backup state is not automatically flipped until the asset is refreshed/edited after the run succeeds.
