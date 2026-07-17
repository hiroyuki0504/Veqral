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

    func testInteractionDetectorFindsNumberedChoices() {
        let text = """
        Which deployment target?
        1) staging
        2) production
        Enter choice:
        """

        let interaction = VeqralInteractionDetector.detect(in: text)

        XCTAssertEqual(interaction?.kind, .choice)
        XCTAssertEqual(interaction?.prompt, "Which deployment target?")
        XCTAssertEqual(interaction?.choices.map(\.value), ["1", "2"])
        XCTAssertEqual(interaction?.choices.map(\.label), ["staging", "production"])
    }

    func testInteractionDetectorFindsFreeformMessagePrompt() {
        let text = "Need more details before continuing. Please type your answer:"

        let interaction = VeqralInteractionDetector.detect(in: text)

        XCTAssertEqual(interaction?.kind, .message)
        XCTAssertEqual(interaction?.prompt, "Need more details before continuing. Please type your answer:")
        XCTAssertEqual(interaction?.choices, [])
    }

    func testGenericApprovalPolicyRejectsExplicitInteractionWithoutRemoteMapping() {
        XCTAssertTrue(VeqralRunControlPolicy.canUseGenericApproval(hasInteraction: false))
        XCTAssertFalse(VeqralRunControlPolicy.canUseGenericApproval(hasInteraction: true))
    }

    func testRunControlPolicyBlocksApprovalBypassAndDuplicateStarts() {
        for status in ["queued", "running", "waitingApproval"] {
            XCTAssertFalse(VeqralRunControlPolicy.canResume(status: status), "resume must reject \(status)")
        }
        for status in ["queued", "running", "cancelled", "failed", "complete", "needsAttention"] {
            XCTAssertFalse(VeqralRunControlPolicy.canApprove(status: status), "approve must reject \(status)")
        }
        XCTAssertTrue(VeqralRunControlPolicy.canApprove(status: "waitingApproval"))
        for status in ["cancelled", "failed", "complete", "needsAttention"] {
            XCTAssertTrue(VeqralRunControlPolicy.canResume(status: status), "resume should allow \(status)")
            XCTAssertFalse(
                VeqralRunControlPolicy.canResume(status: status, approvalState: .pending),
                "pending provenance must block resume from \(status)"
            )
            XCTAssertTrue(VeqralRunControlPolicy.canResume(status: status, approvalState: .granted))
            XCTAssertTrue(VeqralRunControlPolicy.canResume(status: status, approvalState: .legacyGranted))
        }
        XCTAssertFalse(VeqralRunControlPolicy.canStart(status: "queued", approvalState: .pending))
        XCTAssertTrue(VeqralRunControlPolicy.canStart(status: "queued", approvalState: .notRequired))
        XCTAssertTrue(VeqralRunControlPolicy.canStart(status: "queued", approvalState: .granted))
        XCTAssertFalse(VeqralRunControlPolicy.canStart(status: "running", approvalState: .granted))
    }

    func testApprovalProvenanceRoundTripPreservesGrantActorAndTime() throws {
        let grantedAt = Date(timeIntervalSince1970: 12_345)
        let original = VeqralRunApprovalProvenance(
            state: .granted,
            grantedAt: grantedAt,
            grantedByDeviceID: "device-a"
        )
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(VeqralRunApprovalProvenance.self, from: data)
        XCTAssertEqual(restored, original)
    }

    func testPairingPolicyRequiresLocalStatusAccessAndSignedProof() {
        XCTAssertTrue(VeqralPairingAccessPolicy.canReadStatus(isLoopback: true))
        XCTAssertFalse(VeqralPairingAccessPolicy.canReadStatus(isLoopback: false))

        XCTAssertFalse(VeqralPairingAccessPolicy.hasSignedProof(endpoint: nil, signature: nil))
        XCTAssertFalse(VeqralPairingAccessPolicy.hasSignedProof(endpoint: "http://mac.local:7878", signature: nil))
        XCTAssertFalse(VeqralPairingAccessPolicy.hasSignedProof(endpoint: nil, signature: "signature"))
        XCTAssertFalse(VeqralPairingAccessPolicy.hasSignedProof(endpoint: "   ", signature: "signature"))
        XCTAssertFalse(VeqralPairingAccessPolicy.hasSignedProof(endpoint: "http://mac.local:7878", signature: "   "))
        XCTAssertTrue(VeqralPairingAccessPolicy.hasSignedProof(endpoint: "http://mac.local:7878", signature: "signature"))
    }

    func testPairingEndpointsIncludePrivateAndWiredLinkLocalFallbacks() {
        let endpoints = VeqralPairingEndpointPolicy.endpoints(
            hostname: "samuraimacbookpro.local",
            tailscaleIP: "100.96.40.99",
            interfaceIPv4: ["192.168.100.34", "169.254.240.44", "127.0.0.1", "8.8.8.8", "192.168.100.34"],
            port: 18778
        )

        XCTAssertEqual(endpoints, [
            "http://samuraimacbookpro.local:18778",
            "http://100.96.40.99:18778",
            "http://192.168.100.34:18778",
            "http://169.254.240.44:18778"
        ])
    }

    func testRequestAuthPolicyRequiresV2ForEveryAuthenticatedRequest() {
        XCTAssertEqual(VeqralRequestAuthPolicy.minimumVersion(method: "GET", deviceMinimum: 1), 2)
        XCTAssertEqual(VeqralRequestAuthPolicy.minimumVersion(method: "GET", deviceMinimum: 2), 2)
        for method in ["POST", "PUT", "PATCH", "DELETE"] {
            XCTAssertEqual(VeqralRequestAuthPolicy.minimumVersion(method: method, deviceMinimum: 1), 2)
        }
    }

    func testReplayPolicyRequiresNonceForMutationsAndRejectsReuseWithinWindow() {
        XCTAssertFalse(VeqralRequestAuthPolicy.requiresNonce(method: "GET"))
        XCTAssertFalse(VeqralRequestAuthPolicy.requiresNonce(method: "HEAD"))
        for method in ["POST", "PUT", "PATCH", "DELETE"] {
            XCTAssertTrue(VeqralRequestAuthPolicy.requiresNonce(method: method))
        }

        let start = Date(timeIntervalSince1970: 1_000)
        var replayWindow = VeqralReplayWindow(validityInterval: 300)
        XCTAssertTrue(replayWindow.accept(deviceID: "device-a", nonce: "nonce-1", now: start))
        XCTAssertFalse(replayWindow.accept(deviceID: "device-a", nonce: "nonce-1", now: start.addingTimeInterval(10)))
        XCTAssertTrue(replayWindow.accept(deviceID: "device-b", nonce: "nonce-1", now: start.addingTimeInterval(10)))
        XCTAssertTrue(replayWindow.accept(deviceID: "device-a", nonce: "nonce-1", now: start.addingTimeInterval(301)))
    }

    func testReplayWindowSurvivesSerializationAndPrunesExpiredEntries() throws {
        let start = Date(timeIntervalSince1970: 2_000)
        var original = VeqralReplayWindow(validityInterval: 300)
        XCTAssertTrue(original.accept(deviceID: "device-a", nonce: "durable-nonce", now: start))

        let data = try JSONEncoder().encode(original)
        var restored = try JSONDecoder().decode(VeqralReplayWindow.self, from: data)
        XCTAssertFalse(restored.accept(deviceID: "device-a", nonce: "durable-nonce", now: start.addingTimeInterval(10)))
        restored.prune(now: start.addingTimeInterval(301))
        XCTAssertEqual(restored.acceptedCount, 0)
        XCTAssertTrue(restored.accept(deviceID: "device-a", nonce: "durable-nonce", now: start.addingTimeInterval(301)))
    }

    func testReplayExpiryCoversFutureDatedSignatureAndValidatesNonce() {
        let start = Date(timeIntervalSince1970: 5_000)
        let futureSignedAt = start.addingTimeInterval(299)
        let nonce = "01234567-89ab-cdef-0123-456789abcdef"
        var window = VeqralReplayWindow(validityInterval: 300, maximumEntries: 1)

        XCTAssertEqual(
            window.consume(deviceID: "device-a", nonce: nonce, signedAt: futureSignedAt, now: start),
            .accepted
        )
        XCTAssertEqual(
            window.consume(deviceID: "device-a", nonce: nonce, signedAt: futureSignedAt, now: start.addingTimeInterval(301)),
            .replayed
        )
        XCTAssertEqual(
            window.consume(deviceID: "device-b", nonce: "short", signedAt: start, now: start),
            .invalidNonce
        )
        XCTAssertEqual(
            window.consume(deviceID: "device-b", nonce: "abcdef01-2345-6789-abcd-ef0123456789", signedAt: start, now: start),
            .capacityUnavailable
        )
    }

    func testSecretStorePolicyUsesSystemKeychainOnlyOutsideTestMode() {
        XCTAssertEqual(
            VeqralSecretStoreIsolationPolicy.resolve(environment: [:], temporaryRoots: [URL(fileURLWithPath: "/tmp")]),
            .systemKeychain
        )

        let invalid = VeqralSecretStoreIsolationPolicy.resolve(
            environment: [VeqralSecretStoreIsolationPolicy.testModeKey: "1"],
            temporaryRoots: [URL(fileURLWithPath: "/tmp")]
        )
        guard case .invalid(let message) = invalid else {
            return XCTFail("test mode without an isolated store must fail closed")
        }
        XCTAssertTrue(message.contains(VeqralSecretStoreIsolationPolicy.secretStorePathKey))
    }

    func testSecretStorePolicyRejectsMainEnvironmentAndPathEscape() {
        let roots = [URL(fileURLWithPath: "/private/tmp", isDirectory: true)]
        let mainHome = VeqralSecretStoreIsolationPolicy.resolve(
            environment: [
                VeqralSecretStoreIsolationPolicy.testModeKey: "1",
                VeqralSecretStoreIsolationPolicy.hostHomeKey: NSHomeDirectory() + "/.veqral-host-test",
                VeqralSecretStoreIsolationPolicy.secretStorePathKey: NSHomeDirectory() + "/.veqral-host-test/secrets.json"
            ],
            temporaryRoots: roots
        )
        guard case .invalid = mainHome else {
            return XCTFail("test Host home outside temporary storage must be rejected")
        }

        let escapedStore = VeqralSecretStoreIsolationPolicy.resolve(
            environment: [
                VeqralSecretStoreIsolationPolicy.testModeKey: "1",
                VeqralSecretStoreIsolationPolicy.hostHomeKey: "/private/tmp/veqral-host",
                VeqralSecretStoreIsolationPolicy.secretStorePathKey: "/private/tmp/outside.json"
            ],
            temporaryRoots: roots
        )
        guard case .invalid = escapedStore else {
            return XCTFail("secret store path outside Host home must be rejected")
        }
    }

    func testIsolatedFileSecretStoreRoundTripAndPermissions() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("veqral-secret-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let hostHome = root.appendingPathComponent("host", isDirectory: true)
        let storeURL = hostHome.appendingPathComponent("test-secrets.json")
        let backend = VeqralSecretStoreIsolationPolicy.resolve(
            environment: [
                VeqralSecretStoreIsolationPolicy.testModeKey: "1",
                VeqralSecretStoreIsolationPolicy.hostHomeKey: hostHome.path,
                VeqralSecretStoreIsolationPolicy.secretStorePathKey: storeURL.path
            ],
            temporaryRoots: VeqralSecretStoreIsolationPolicy.systemTemporaryRoots()
        )
        guard case .isolatedFile(let resolvedURL) = backend else {
            return XCTFail("valid temporary test configuration must use the isolated file backend")
        }

        let store = try VeqralIsolatedFileSecretStore(url: resolvedURL)
        try store.set("value-a", account: "device:a")
        XCTAssertEqual(try store.get(account: "device:a"), "value-a")
        try store.delete(account: "device:a")
        XCTAssertNil(try store.get(account: "device:a"))

        let attributes = try FileManager.default.attributesOfItem(atPath: resolvedURL.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }
}
