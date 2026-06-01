# Apple Watch Approval PR A6

Branch: `codex/a6-watch-approval`
Draft PR: pending

## Scope

- Added a standalone `VeqralWatch` watchOS target and scheme to `Veqral.xcodeproj`.
- Added a watchOS SwiftUI command surface in `VeqralWatch/VeqralWatchApp.swift`.
- Reused the existing Host HMAC contract (`X-Veqral-Device`, `X-Veqral-Timestamp`, `X-Veqral-Signature`) instead of adding a new transport.
- Added Watch-side Keychain storage for the Host token. Endpoint and device ID stay in Watch `UserDefaults`.
- Added a compact approvals list with approve/reject actions against `/v1/runs/{id}/approve` and `/v1/runs/{id}/reject`.
- Added a one-line command composer for Apple Watch dictation/text input. It creates a Hermes run through `/v1/runs`.
- Added a small execution-status view that can be lifted into a WidgetKit complication extension later.

## Safety

- High-risk Watch approval is intentionally constrained. Runs whose prompt or approval reason mentions deletion, production, `main merge`, `force push`, deploy, `.env`, token/secret, billing, or Computer Use are shown on Watch but require iPhone review.
- The Watch app does not store credentials in source, does not print tokens, and does not touch `~/.codex` or `~/.claude`.
- Push notification code remains dormant. APNs is still gated by Apple Developer Program capability and is not claimed as working under the current free-team setup.

## Partial / Environment Limits

- This Mac does not currently have watchOS 26.5 installed, so `VeqralWatch` cannot be compiled here. Xcode reports `watchOS 26.5 is not installed`.
- The Watch target is not embedded into the iOS target yet. Embedding it caused the existing iOS Simulator build to require the missing watchOS platform, so this PR keeps the main app build green and leaves embedding/distribution for the watchOS-capable environment.
- No WidgetKit complication target is included yet; only the reusable status view is scaffolded.
- No real Apple Watch, cellular, or Tailscale reachability test was completed in this environment.
- APNs/watch notifications remain partial until the paid Apple Developer Program capability and push credentials are available.

## Verification

- PASS: `swift build --package-path MacHost`
- PASS: XcodeBuildMCP iOS Simulator build for `Veqral` with `CODE_SIGNING_ALLOWED=NO`
- PASS: `xcodebuild -project Veqral.xcodeproj -scheme Veqral -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build`
- PASS: `xcodebuild -list -project Veqral.xcodeproj` shows `VeqralWatch` target and scheme.
- BLOCKED: `xcodebuild -project Veqral.xcodeproj -scheme VeqralWatch -configuration Debug -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO build` fails because watchOS 26.5 is not installed.
- PASS: `swift run --package-path MacHost VeqralHost smoke-project-memory`
- PASS: `swift run --package-path MacHost VeqralHost smoke-discord-notifications`
- PASS: `swift run --package-path MacHost VeqralHost smoke-host-telemetry`
- PASS: `swift run --package-path MacHost VeqralHost smoke-run-usage`
- PASS: `swift run --package-path MacHost VeqralHost smoke-voice-cleanup`
- PASS: `swift run --package-path MacHost VeqralHostSmoke verify-memory-inheritance`
- PASS: `git diff --check`
- PASS: source production grep (`mock|stub|fake|demo|not implemented`) returned no matches in Swift sources.
- PASS: concrete secret assignment grep returned no matches in Swift sources.
- PASS: `plutil -lint` for both `Localizable.strings` files.
- PASS: Localizable missing-key check returned no differences.

## Next

- Install the matching watchOS platform in Xcode and build `VeqralWatch`.
- Add the Watch app embed phase to the iOS target once the watchOS platform is installed.
- Add a real WidgetKit complication extension if the status view proves useful on device.
- Re-test real Apple Watch connectivity over Tailscale/WebSocket and document whether cellular-only reachability works.
- Enable APNs only after the Apple Developer Program capability and server credentials are available.
