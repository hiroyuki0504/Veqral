# Hermes Cross-Vendor Memory Inheritance PR A7

This is the #A7 Claude-to-GPT rerun attempt. It is intentionally testing subscription/login auth, not an API-key fallback.

Draft PR: #37

- Source: `veqral-memtest-20260601-153016-940e3af3`
- Hermes home: isolated temporary home (`hermes-home`)
- Chat A: `anthropic/claude-haiku-4-5`
- Chat B: `openai-codex/gpt-5.5`
- Chat A credential source: Claude Code / Hermes Anthropic login (no API key)
- Chat B credential source: Hermes ChatGPT subscription login (`auth.json`)
- Code name: `Tachibana-7-0A9961F8`

## Backend Capability Check

- `openai-codex`: Hermes ChatGPT subscription login auth was available for this isolated run; selected route: `anthropic/claude-haiku-4-5 -> openai-codex/gpt-5.5`.
- `anthropic`: Hermes reports Claude/Anthropic login as unavailable on this Mac; use `claude /login` or `claude setup-token` before choosing this route.
- Local Ollama custom endpoint: supported through `provider=custom` + `base_url`, but `127.0.0.1:11434` is not reachable right now.
- Login auth bridge: `auth.json` linked from `~/.hermes` into isolated `HERMES_HOME`

## Credential / Provider Preflight

- Chat A uses `anthropic`, but Hermes reports Anthropic login as unavailable. Claude Code is logged in on this Mac, but Hermes needs readable Claude Code OAuth/setup-token credentials; run `claude /login` or `claude setup-token` if using a supported Claude Max + extra credits route.

## Result

FAIL: Hermes memory inheritance was not run because at least one real provider/model route is not ready. 偽 pass は作っていません。

## Verification

- PASS: `swift build --package-path MacHost`
- PASS: XcodeBuildMCP iOS Simulator build for `Veqral` with `CODE_SIGNING_ALLOWED=NO`
- PASS: `xcodebuild -project Veqral.xcodeproj -scheme Veqral -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build`
- PASS: `swift run --package-path MacHost VeqralHost smoke-project-memory`
- PASS: `swift run --package-path MacHost VeqralHost smoke-discord-notifications`
- PASS: `swift run --package-path MacHost VeqralHost smoke-host-telemetry`
- PASS: `swift run --package-path MacHost VeqralHost smoke-run-usage`
- PASS: `swift run --package-path MacHost VeqralHost smoke-voice-cleanup`
- PASS: baseline `swift run --package-path MacHost VeqralHostSmoke verify-memory-inheritance --report /tmp/veqral-a7-default-memory.md`
- BLOCKED as expected: cross-vendor `VEQRAL_MEMTEST_PROVIDER_A=anthropic VEQRAL_MEMTEST_MODEL_A=claude-haiku-4-5 VEQRAL_MEMTEST_PROVIDER_B=openai-codex VEQRAL_MEMTEST_MODEL_B=gpt-5.5 swift run --package-path MacHost VeqralHostSmoke verify-memory-inheritance --report HERMES_CROSS_VENDOR_PR_A7.md`
- PASS: `git diff --check`
- PASS: source production grep (`mock|stub|fake|demo|not implemented`) returned no matches in Swift sources.
- PASS: concrete secret assignment grep returned no matches in Swift sources.
- PASS: `plutil -lint` for both `Localizable.strings` files.
- PASS: Localizable missing-key check returned no differences.
