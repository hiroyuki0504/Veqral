# Veqral Forge security and operations

This document is the maintained security and operations contract for the current Forge client and Mac Host. Historical PR reports, device-specific notes, generated verification transcripts, and retired UI instructions are intentionally not canonical documentation.

## Trust boundary and secret storage

- A paired iPhone or iPad controls a Mac Host; it is not a privileged shell credential receiver.
- Device tokens are stored in Apple Keychain. Non-secret pairing metadata and UI preferences may use `UserDefaults`.
- Administrator passwords, Keychain passwords, Apple ID passwords, 2FA codes, device passcodes, and provider credentials must never be sent to, stored by, or typed through the iPhone client.
- Provider and model resolution stays on the Mac. The client exposes only the Hermes, Codex, and Claude runtime families and does not hard-code provider model IDs.
- Automated verification must use a temporary `VEQRAL_HOST_HOME`, an isolated workspace, and a file-backed test secret store. It must not alter the user's login/default/search Keychains, LaunchAgents, Hermes configuration, or production Host state.

## Pairing and request authentication

- Pairing uses ordered endpoint candidates and a signed v2 pairing proof. The Host verifies the proof before issuing a device token.
- Authenticated API requests use HMAC-SHA256 request authentication v2 over the canonical request components.
- Each request includes a timestamp and nonce. The Host enforces the acceptance window and persists nonce replay state so a restart does not reopen a previously consumed request.
- Authentication downgrade to request-auth v1 is not accepted by the Forge client/Host contract.
- Pairing codes and secrets rotate after successful pairing.

## Run, approval, and input safety

- The Host classifies Run risk and owns approval provenance. `waitingApproval` alone is not sufficient for the client to expose approve/reject; an explicit server-provided pending approval record is required.
- High-risk approval displays the request, changed files/diff context, and known artifacts before the final approval mutation.
- Questions and input requests are not generic approvals. The Host accepts terminal input only while an active server-side interaction exists; unsolicited PTY input is rejected.
- If an interaction supplies choices, the Host accepts only a listed choice value.
- Every client mutation sends the expected stable Task ID. Immediately before acting, the client refreshes the Run list and resolves the current attempt again. The Host independently and atomically rejects a stale attempt.
- Approval, input, review, blocker, and unsupported states remain distinct. Missing or unknown provenance/state fails closed rather than enabling an action.
- Completed, failed, and cancelled Runs are terminal. Failed/cancelled Runs do not count as successful Mission progress and are never used to synthesize a successful Handoff.

## Artifact and Handoff integrity

- Artifact paths are constrained to the Run workspace and content is redacted before display.
- A Handoff is a first-class Host record with stable Task and Run relationships; the client does not infer Handoff review state from a generic artifact type.
- Explicit handoff files use `handoff.md`, `handoff.json`, `handoff.txt`, or a `*.handoff.{md,json,txt}` suffix. The Host records only files updated after the originating attempt began.
- Handoff records are atomically persisted in Host state and survive Host restart and later attempts for the same Task.
- If a current attempt's recorded handoff file disappears, its record becomes blocked rather than silently disappearing.
- If Handoff scanning, decoding, or persistence is unavailable, the Run/attention refresh fails. The client keeps the queue unavailable/stale and does not present a safe empty state.

## Stream recovery and ordering

- WebSocket reconnect uses exponential backoff from 1 to 30 seconds.
- Before/after reconnect, the client resynchronizes a signed Run snapshot and ingests persisted Host replay.
- Host events have a stable event identity. Replayed copies of the same event are dropped, while different events with identical text remain distinct.
- Replay identity is retained for the stream lifetime; it is not evicted at an arbitrary event-count boundary.
- Snapshot `statusUpdatedAt`, event timestamps, and event `runStatus` prevent older replay from overwriting newer Run state or resurrecting a resolved input prompt.
- Terminal Runs are never resumed merely because the stream reconnects.
- Log and stream text passes through `VeqralRedactor` before UI presentation, audit output, or external notification.

## Notifications and external effects

- APNs registration and low-risk action support remain behind a feature flag and are disabled by default unless the required capability and Host configuration are present.
- Destructive or externally visible actions require their explicit approval path. A missing approval-backed implementation must fail closed rather than falling back to direct execution.
- No update is installed merely because a new Hermes target is discovered. Update installation remains user-initiated and requires its own canary, atomic promotion, and rollback implementation.

## Verification

Run the complete local gate from a clean test environment:

```bash
Scripts/verify_pr_ready.sh
```

The gate includes shared/Host tests, Host build, pairing/HMAC/nonce/replay/approval/input security smoke, Forge client transport/reconnect/Handoff smoke, iOS and Mac Catalyst builds, Forge UI tests, and the test-isolation policy check.

The memory-inheritance diagnostic never writes a default report into the repository. Pass `--report PATH` for a retained report; otherwise it writes a unique file under the operating system's temporary directory.

Physical-device acceptance remains manual: pair a real iPhone with a running Mac Host, start a long Run, interrupt/recover the network, verify the reconnect state and log continuity, exercise approval/input boundaries, and inspect a real Artifact/Handoff. Do not report physical-device acceptance from Simulator or unit-test evidence alone.
