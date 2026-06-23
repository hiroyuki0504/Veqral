# Next actions

確認時点: 2026-06-23 15:44:42 JST

The next maintainer should be able to move using this file alone. Do not start with broad refactors.

## Top priority sequence

| Order | Task | Touch files | Commands | Expected result | Verification | Done when | Dependencies / blockers |
|---|---|---|---|---|---|---|---|
| 1 | Review and merge handover package PR | `docs/handover/*`, `AGENTS.md` | `git diff --stat`, review docs | transfer package accepted | docs render and links/paths make sense | PR merged or requested edits addressed | none |
| 2 | Fix README drift from live Hermes/AI-Hub state | `README.md`, maybe `docs/handover/18-documentation-drift.md` | `curl -fsS http://127.0.0.1:7878/v1/health` | README no longer says stale Hermes/local model facts | compare with health and AGENTS | drift row marked resolved | must avoid hard-coded model fixation |
| 3 | Run real iPhone Gate2 manual checklist | no code unless failures | follow `DEVICE_ACCEPTANCE.md` | voice, telemetry, saved commands, Discord, Memory visibility observed | screen/log evidence | each iPhone item marked pass/fail | real device/user time |
| 4 | Run real iPad Gate2 manual checklist | no code unless failures | follow `DEVICE_ACCEPTANCE.md` | same 5 items observed on iPad | screen/log evidence | each iPad item marked pass/fail | iPad online/trusted |
| 5 | Restore Hermes-readable Claude/Anthropic login and rerun #A7 | likely external Hermes auth, docs after result | commands in `HERMES_CROSS_VENDOR_PR_A7.md` | either real cross-vendor PASS or clear new blocker | transcript appended | no API-key fake pass | Hermes/provider auth |

## 2-5 minute concrete tasks

| ID | Task | File / place | Command | Expected result | Completion condition |
|---|---|---|---|---|---|
| NA-001 | Confirm current branch before touching code | repo root | `git status --short --branch` | clean or expected docs branch | no surprise dirty files |
| NA-002 | List handover docs | `docs/handover/` | `find docs/handover -maxdepth 1 -type f | sort` | files `README.md`, `00`-`18` present | no missing required file |
| NA-003 | Check live Host health | local Host | `curl -fsS http://127.0.0.1:7878/v1/health` | JSON with `status=ok` | health saved in notes if changed |
| NA-004 | Confirm LaunchAgent | macOS launchd | `launchctl print gui/$(id -u)/dev.hiroyuki.veqral.host` | running service | logs/path match docs |
| NA-005 | Run docs-only whitespace check | repo root | `git diff --check` | no output/errors | safe to stage docs |
| NA-006 | Review untracked root files | repo root | `git status --short` | four known untracked handoff files visible unless already handled | decide import/archive/ignore |
| NA-007 | Check README drift rows | `docs/handover/18-documentation-drift.md` | read rows DRIFT-001.. | know exact docs to patch | create small README-only branch/commit |
| NA-008 | Confirm simulator IDs before Gate2 | local Xcode | `xcrun simctl list devices available` | available iOS/iPad/watch IDs | pass env overrides to script if defaults stale |
| NA-009 | Run one Host smoke after Host edit | MacHost | `swift run --package-path MacHost VeqralHost smoke-<area>` | PASS | smoke result recorded |
| NA-010 | Run redactor tests after logging/secrets edit | MacHost | `swift test --package-path MacHost` | PASS | no new secret leak regression |

## Feature-specific next tasks

### README drift fix

1. Open `README.md`.
2. Replace stale Hermes version wording with a version-neutral command-based check, or update with the live confirmed version and date.
3. Replace cloud-only/local fallback removal wording with AI-Hub policy/lane wording.
4. Keep memory smoke instructions clear: Hermes native memory, no custom memory, login route preferred.
5. Run:

```bash
git diff --check
swift build --package-path MacHost
```

6. Done when `docs/handover/18-documentation-drift.md` rows DRIFT-001 and DRIFT-002 can be marked resolved or moved to history.

### Real device acceptance

1. Start from `DEVICE_ACCEPTANCE.md`.
2. Use the currently running Host unless the test requires isolated Host.
3. On iPhone, verify:
   - QR pairing/connection strip.
   - voice input raw/cleaned/submit.
   - Devices telemetry refresh.
   - saved command chip save/restore.
   - Hermes memory visibility for a paired Project.
   - Discord test notification if webhook is configured.
4. Repeat on iPad.
5. Record pass/fail and screenshot/log evidence in a small follow-up doc.
6. If a feature fails, create a targeted Draft PR for only that item.

### Cross-vendor memory #A7

1. Restore or confirm Hermes-readable Claude/Anthropic subscription/login auth.
2. Run the exact preflight/verification path from `HERMES_CROSS_VENDOR_PR_A7.md`.
3. Do not set an API-key route just to pass.
4. If PASS, append transcript to `HERMES_MEMORY_INHERITANCE_PR0.md` and update `AGENTS.md`.
5. If FAIL, record the exact blocker and stop.

### Host deploy procedure hardening

1. Before next Host deploy, record current binary metadata:

```bash
ls -l ~/.veqral-host/bin/VeqralHost
codesign -dv ~/.veqral-host/bin/VeqralHost
```

2. Build release:

```bash
swift build --package-path MacHost -c release
```

3. Decide and document backup path before copy.
4. Copy/sign/restart only after user-visible Runs are safe to interrupt.
5. Confirm:

```bash
curl -fsS http://127.0.0.1:7878/v1/health
launchctl print gui/$(id -u)/dev.hiroyuki.veqral.host
```

6. Add exact commands to `docs/handover/09-deployment-and-infrastructure.md`.

## Blockers

| Blocker | Blocks | How to unblock |
|---|---|---|
| Hermes-readable Claude/Anthropic auth unavailable | cross-vendor memory proof | restore login/subscription auth in Hermes |
| iPad/Watch offline in `xctrace` | real iPad/Watch acceptance | connect/trust/enable Developer Mode |
| Paid Apple Developer not configured | APNs push | enroll/configure APNs key/capabilities |
| GitHub settings inaccessible from repo | CI/protection certainty | inspect GitHub web settings |
| real Discord webhook not configured or not shareable | external notification proof | set webhook secret in env/Keychain and test |
