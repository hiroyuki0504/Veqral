import XCTest
@testable import VeqralShared

final class VeqralRedactorTests: XCTestCase {
    func testMasksMessagingAndGitHubSecretsUsedInHandoffText() {
        let samples = [
            "Authorization: bearer veqraltestsecret",
            "token=token-should-hide",
            "password=password-should-hide",
            "VEQRAL_DISCORD_WEBHOOK=https://discord.com/api/webhooks/123456789/discord-webhook-should-hide",
            "https://discordapp.com/api/webhooks/123456789/discord-webhook-should-hide",
            "xoxb-slack-token-should-hide",
            "sk-or-openrouter-key-should-hide",
            "sk-1234567890abcdefghijklmnop",
            "ghp_githubtokenshouldhide",
            "github_pat_11AAAgithubtokenshouldhide"
        ]

        let redacted = VeqralRedactor.redact(samples.joined(separator: "\n"))

        XCTAssertFalse(redacted.contains("veqraltestsecret"))
        XCTAssertFalse(redacted.contains("token-should-hide"))
        XCTAssertFalse(redacted.contains("password-should-hide"))
        XCTAssertFalse(redacted.contains("discord-webhook-should-hide"))
        XCTAssertFalse(redacted.contains("slack-token-should-hide"))
        XCTAssertFalse(redacted.contains("openrouter-key-should-hide"))
        XCTAssertFalse(redacted.contains("1234567890abcdefghijklmnop"))
        XCTAssertFalse(redacted.contains("githubtokenshouldhide"))
        XCTAssertTrue(redacted.contains("[REDACTED_DISCORD_WEBHOOK]") || redacted.contains("VEQRAL_DISCORD_WEBHOOK=[REDACTED]"))
        XCTAssertTrue(redacted.contains("[REDACTED_SLACK_TOKEN]"))
        XCTAssertTrue(redacted.contains("[REDACTED_GITHUB_TOKEN]"))
    }

    func testLimitIsAppliedAfterRedaction() {
        let redacted = VeqralRedactor.redact("token=token-should-hide abcdef", limit: 10)

        XCTAssertFalse(redacted.contains("token-should-hide"))
        XCTAssertTrue(redacted.hasSuffix("\n...（省略）"))
    }
}
