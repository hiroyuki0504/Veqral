import Combine
import Foundation

enum ForgeStoreError: Error, LocalizedError, Sendable {
    case invalidPairingResponse
    case unsupportedHostProtocol(String)
    case pairingFailed([String])
    case approvalNotAllowed
    case inputNotAllowed
    case fixtureReadOnly
    case attemptChanged

    var errorDescription: String? {
        switch self {
        case .invalidPairingResponse:
            "The Host returned an invalid pairing response."
        case .unsupportedHostProtocol(let detail):
            detail
        case .pairingFailed(let failures):
            "All ordered pairing endpoints failed. \(failures.joined(separator: " / "))"
        case .approvalNotAllowed:
            "This attention item is not an explicit approval request."
        case .inputNotAllowed:
            "This attention item is not an explicit input request."
        case .fixtureReadOnly:
            "The deterministic UI test fixture is read-only."
        case .attemptChanged:
            "The current Run attempt changed. Refresh before acting."
        }
    }
}

/// Minimal, real-Host-backed state for the Forge Mission/Workstream/Task UI.
/// Host metadata is persisted in UserDefaults; device tokens never leave Keychain.
@MainActor
final class ForgeStore: ObservableObject {
    @Published private(set) var host: ForgeHostConfiguration?
    @Published private(set) var health: RemoteHealthResponse?
    @Published private(set) var runs: [RemoteRunRecord]
    @Published private(set) var projection: ForgeSnapshot
    @Published private(set) var isRefreshing: Bool
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var lastRunsRefreshAt: Date?
    @Published private(set) var runsRefreshErrorMessage: String?

    private static let hostDefaultsKey = "dev.hiroyuki.veqral.forge.host.v1"
    private static let stableClientIDAccount = "client-stable-id"
    private let defaults: UserDefaults
    private var artifactsByRunID: [String: [RemoteArtifactRecord]]
    private var handoffs: [RemoteHandoffRecord]

    #if DEBUG
    private let isUsingFixture: Bool
    #endif

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.host = Self.loadHost(from: defaults)
        self.health = nil
        self.runs = []
        self.projection = ForgeProjection.snapshot(from: [])
        self.isRefreshing = false
        self.lastErrorMessage = nil
        self.lastRunsRefreshAt = nil
        self.runsRefreshErrorMessage = nil
        self.artifactsByRunID = [:]
        self.handoffs = []

        #if DEBUG
        self.isUsingFixture = ProcessInfo.processInfo.environment["VEQRAL_UI_TEST_FIXTURE"] == "1"
        if isUsingFixture {
            let fixtureRuns = Self.fixtureRuns
            host = Self.fixtureHost
            health = Self.fixtureHealth
            runs = fixtureRuns
            handoffs = [Self.fixtureHandoff]
            projection = ForgeRemoteProjection.snapshot(
                from: fixtureRuns,
                artifactsByRunID: ["completed-run": [Self.fixtureArtifact]],
                handoffs: handoffs,
                generatedAt: Self.fixtureNow
            )
            lastRunsRefreshAt = Date()
            if ProcessInfo.processInfo.environment["VEQRAL_UI_TEST_STALE_ATTENTION"] == "1" {
                lastRunsRefreshAt = Date().addingTimeInterval(-120)
                runsRefreshErrorMessage = "The fixture Host is unavailable."
            }
        }
        #endif
    }

    var isPaired: Bool {
        #if DEBUG
        if isUsingFixture { return host?.isConfigured == true }
        #endif
        guard let host, host.isConfigured else { return false }
        return Self.token(for: host.deviceID) != nil
    }

    func isAttentionStateStale(at date: Date = Date()) -> Bool {
        guard runsRefreshErrorMessage == nil, let lastRunsRefreshAt else { return true }
        return date.timeIntervalSince(lastRunsRefreshAt) > 60
    }

    @discardableResult
    func pair(using pairingURL: URL, deviceName: String) async throws -> ForgeHostConfiguration {
        #if DEBUG
        guard !isUsingFixture else { throw ForgeStoreError.fixtureReadOnly }
        #endif

        let pairingLink: RemotePairingLink
        do {
            pairingLink = try RemotePairingLink(url: pairingURL)
        } catch {
            record(error)
            throw error
        }

        let stableClientID: String
        do {
            stableClientID = try Self.stableClientID()
        } catch {
            record(error)
            throw error
        }

        let cleanDeviceName = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        var failures: [String] = []
        var selectedEndpoint: String?
        var pairResponse: RemotePairResponse?

        // RemotePairingLink has already validated uniqueness and order. Do not sort or
        // reconstruct these endpoints: the order is covered by the pairing v2 proof.
        for endpoint in pairingLink.endpoints {
            do {
                let response = try await RemoteHostClient.pair(
                    endpoint: endpoint,
                    deviceName: cleanDeviceName.isEmpty ? "Veqral iOS" : cleanDeviceName,
                    pairingCode: pairingLink.pairingCode,
                    pairingSignature: pairingLink.legacySignature,
                    signedEndpoint: pairingLink.signedEndpoint,
                    clientStableID: stableClientID,
                    pairingLink: pairingLink
                )
                selectedEndpoint = endpoint
                pairResponse = response
                break
            } catch {
                failures.append("\(endpoint): \(error.localizedDescription)")
            }
        }

        guard let selectedEndpoint, let pairResponse else {
            let error = ForgeStoreError.pairingFailed(failures)
            record(error)
            throw error
        }

        do {
            try Self.validate(pairResponse, for: pairingLink)
            guard let deviceID = Self.normalized(pairResponse.deviceID),
                  let token = Self.normalized(pairResponse.token) else {
                throw ForgeStoreError.invalidPairingResponse
            }

            try AppKeychainStore.set(token, account: Self.tokenAccount(deviceID: deviceID))
            let configuration = ForgeHostConfiguration(
                endpoint: selectedEndpoint,
                deviceID: deviceID,
                name: "Mac Host",
                apiProtocolVersion: pairResponse.apiProtocolVersion,
                minimumAuthVersion: pairResponse.minimumAuthVersion
            )
            try persist(configuration)
            host = configuration
            health = nil
            runs = []
            artifactsByRunID = [:]
            rebuildProjection()
            lastErrorMessage = nil
            lastRunsRefreshAt = nil
            runsRefreshErrorMessage = nil
            return configuration
        } catch {
            record(error)
            throw error
        }
    }

    @discardableResult
    func pair(using pairingURL: String, deviceName: String) async throws -> ForgeHostConfiguration {
        guard let url = URL(string: pairingURL) else {
            let error = RemotePairingLinkError.invalid("Pairing URL was not recognized.")
            record(error)
            throw error
        }
        return try await pair(using: url, deviceName: deviceName)
    }

    func refresh() async throws {
        #if DEBUG
        if isUsingFixture { return }
        #endif

        let client = try makeClient()
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            async let nextHealth = client.health()
            async let nextRuns = client.runList()
            let (healthResponse, runResponse) = try await (nextHealth, nextRuns)
            health = healthResponse
            runs = runResponse.runs
            handoffs = runResponse.handoffs
            retainArtifacts(for: runResponse.runs)
            updateHostName(healthResponse.host)
            rebuildProjection()
            lastErrorMessage = nil
            lastRunsRefreshAt = Date()
            runsRefreshErrorMessage = nil
        } catch {
            record(error)
            recordRunsRefreshFailure(error)
            throw error
        }
    }

    func refreshHealth() async throws {
        #if DEBUG
        if isUsingFixture { return }
        #endif

        do {
            let response = try await makeClient().health()
            health = response
            updateHostName(response.host)
            lastErrorMessage = nil
        } catch {
            record(error)
            throw error
        }
    }

    func refreshRuns() async throws {
        #if DEBUG
        if isUsingFixture { return }
        #endif

        do {
            let response = try await makeClient().runList()
            runs = response.runs
            handoffs = response.handoffs
            retainArtifacts(for: response.runs)
            rebuildProjection()
            lastErrorMessage = nil
            lastRunsRefreshAt = Date()
            runsRefreshErrorMessage = nil
        } catch {
            record(error)
            recordRunsRefreshFailure(error)
            throw error
        }
    }

    @discardableResult
    func createRun(_ request: ForgeRunRequest) async throws -> RemoteCreateRunResponse {
        try requireWritableHost()
        do {
            let response = try await makeClient().createRun(request)
            await refreshRunsAfterMutation()
            return response
        } catch {
            record(error)
            throw error
        }
    }

    func cancel(runID: String) async throws {
        try requireWritableHost()
        do {
            let (client, taskID) = try await requireFreshCurrentAttempt(runID: runID)
            try await client.cancel(remoteRunID: runID, expectedTaskID: taskID)
            await refreshRunsAfterMutation()
        } catch {
            record(error)
            throw error
        }
    }

    func resume(runID: String) async throws {
        try requireWritableHost()
        do {
            let (client, taskID) = try await requireFreshCurrentAttempt(runID: runID)
            try await client.resume(remoteRunID: runID, expectedTaskID: taskID)
            await refreshRunsAfterMutation()
        } catch {
            record(error)
            throw error
        }
    }

    func approve(runID: String) async throws {
        try requireExplicitApproval(runID: runID)
        do {
            let (client, taskID) = try await requireFreshExplicitApproval(runID: runID)
            try await client.approve(remoteRunID: runID, expectedTaskID: taskID)
            await refreshRunsAfterMutation()
        } catch {
            record(error)
            throw error
        }
    }

    func reject(runID: String) async throws {
        try requireExplicitApproval(runID: runID)
        do {
            let (client, taskID) = try await requireFreshExplicitApproval(runID: runID)
            try await client.reject(remoteRunID: runID, expectedTaskID: taskID)
            await refreshRunsAfterMutation()
        } catch {
            record(error)
            throw error
        }
    }

    func submitInput(_ text: String, runID: String, submit: Bool = true) async throws {
        try requireExplicitInput(runID: runID)
        try requireWritableHost()
        do {
            let (client, taskID) = try await requireFreshCurrentAttempt(runID: runID)
            try requireExplicitInput(runID: runID)
            try await client.submitInput(
                remoteRunID: runID,
                expectedTaskID: taskID,
                text: text,
                submit: submit
            )
            await refreshRunsAfterMutation()
        } catch {
            record(error)
            throw error
        }
    }

    func submitInput(runID: String, text: String, submit: Bool = true) async throws {
        try await submitInput(text, runID: runID, submit: submit)
    }

    func snapshot(runID: String) async throws -> RemoteRunSnapshotResponse {
        #if DEBUG
        if isUsingFixture { return try fixtureSnapshot(runID: runID) }
        #endif

        do {
            let response = try await makeClient().runSnapshot(remoteRunID: runID)
            replaceRun(response.run)
            artifactsByRunID[runID] = response.artifacts
            replaceHandoffs(for: runID, with: response.handoffs)
            rebuildProjection()
            lastErrorMessage = nil
            return response
        } catch {
            record(error)
            throw error
        }
    }

    func artifacts(runID: String) async throws -> RemoteArtifactListResponse {
        #if DEBUG
        if isUsingFixture {
            return RemoteArtifactListResponse(artifacts: runID == "completed-run" ? [Self.fixtureArtifact] : [])
        }
        #endif

        do {
            let response = try await makeClient().runArtifacts(remoteRunID: runID)
            artifactsByRunID[runID] = response.artifacts
            rebuildProjection()
            lastErrorMessage = nil
            return response
        } catch {
            record(error)
            throw error
        }
    }

    func artifact(runID: String, artifactID: String) async throws -> RemoteArtifactContentResponse {
        #if DEBUG
        if isUsingFixture, runID == "completed-run", artifactID == Self.fixtureArtifact.id {
            return RemoteArtifactContentResponse(
                artifactID: artifactID,
                mimeType: "text/markdown",
                data: Data("# Deterministic fixture\n".utf8)
            )
        }
        #endif

        do {
            let response = try await makeClient().artifactContent(remoteRunID: runID, artifactID: artifactID)
            lastErrorMessage = nil
            return response
        } catch {
            record(error)
            throw error
        }
    }

    func diff(runID: String) async throws -> RemoteGitDiffResponse {
        #if DEBUG
        if isUsingFixture { return RemoteGitDiffResponse(files: []) }
        #endif

        do {
            let response = try await makeClient().runDiff(remoteRunID: runID)
            lastErrorMessage = nil
            return response
        } catch {
            record(error)
            throw error
        }
    }

    func logs(runID: String) async throws -> RemoteRunLogResponse {
        #if DEBUG
        if isUsingFixture { return RemoteRunLogResponse(logs: Self.fixtureLogs(for: runID)) }
        #endif

        do {
            let response = try await makeClient().runLogs(remoteRunID: runID)
            lastErrorMessage = nil
            return response
        } catch {
            record(error)
            throw error
        }
    }

    func stream(runID: String) throws -> AsyncThrowingStream<RemoteHostLogEvent, Error> {
        #if DEBUG
        if isUsingFixture {
            let events = Self.fixtureLogs(for: runID)
            return AsyncThrowingStream<RemoteHostLogEvent, Error>(bufferingPolicy: .unbounded) { continuation in
                for event in events {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
        #endif
        let client = try makeClient()
        return client.stream(
            remoteRunID: runID,
            onResync: { [weak self] snapshot in
                await self?.ingestStreamSnapshot(snapshot)
            }
        )
    }

    private func ingestStreamSnapshot(_ response: RemoteRunSnapshotResponse) {
        replaceRun(response.run)
        artifactsByRunID[response.run.id] = response.artifacts
        replaceHandoffs(for: response.run.id, with: response.handoffs)
        rebuildProjection(generatedAt: response.run.statusUpdatedAt ?? Date())
    }

    func ingestStreamEvent(_ event: RemoteHostLogEvent) {
        guard let index = runs.firstIndex(where: { $0.id == event.runID }) else { return }
        guard RemoteRunStreamReducer.apply(event, to: &runs[index]) else { return }
        rebuildProjection(generatedAt: event.createdAt)
    }

    func registerPushToken(_ token: String, environment: String, bundleID: String, locale: String) async {
        guard !token.isEmpty, host != nil else { return }
        do {
            _ = try await makeClient().registerPushToken(
                deviceToken: token,
                environment: environment,
                bundleID: bundleID,
                locale: locale
            )
        } catch {
            record(error)
        }
    }

    func handlePushApproval(actionIdentifier: String, category: String, runID: String) async {
        guard category == VeqralPushAction.lowApprovalCategory else { return }
        do {
            try requireExplicitApproval(runID: runID, allowHighRisk: false)
            let (client, taskID) = try await requireFreshExplicitApproval(runID: runID, allowHighRisk: false)
            switch actionIdentifier {
            case VeqralPushAction.approve:
                try await client.approve(remoteRunID: runID, expectedTaskID: taskID)
            case VeqralPushAction.reject:
                try await client.reject(remoteRunID: runID, expectedTaskID: taskID)
            default:
                return
            }
            try await refreshRuns()
        } catch {
            record(error)
        }
    }

    private func makeClient() throws -> RemoteHostClient {
        guard let host, host.isConfigured,
              let token = Self.token(for: host.deviceID) else {
            throw RemoteHostError.invalidConfiguration
        }
        if let minimumAuthVersion = host.minimumAuthVersion, minimumAuthVersion > 2 {
            throw ForgeStoreError.unsupportedHostProtocol(
                "Host request authentication v\(minimumAuthVersion) is not supported."
            )
        }
        return RemoteHostClient(configuration: RemoteHostConfiguration(
            isEnabled: true,
            endpoint: host.endpoint,
            deviceID: host.deviceID,
            token: token,
            name: host.name,
            minimumAuthVersion: host.minimumAuthVersion
        ))
    }

    private func requireWritableHost() throws {
        #if DEBUG
        if isUsingFixture { throw ForgeStoreError.fixtureReadOnly }
        #endif
        _ = try makeClient()
    }

    private func requireExplicitApproval(runID: String, allowHighRisk: Bool = true) throws {
        guard let item = projection.attention.first(where: {
            $0.runID == runID && $0.allowsApproval
        }), allowHighRisk || item.approvalSeverity != .high else {
            throw ForgeStoreError.approvalNotAllowed
        }
    }

    private func requireExplicitInput(runID: String) throws {
        guard projection.attention.contains(where: {
            $0.runID == runID && $0.kind == .input
        }) else {
            throw ForgeStoreError.inputNotAllowed
        }
    }

    private func requireFreshExplicitApproval(
        runID: String,
        allowHighRisk: Bool = true
    ) async throws -> (RemoteHostClient, String) {
        let (client, taskID) = try await requireFreshCurrentAttempt(runID: runID)
        let response = try await client.runSnapshot(remoteRunID: runID)
        replaceRun(response.run)
        artifactsByRunID[runID] = response.artifacts
        replaceHandoffs(for: runID, with: response.handoffs)
        rebuildProjection()
        try requireCurrentAttempt(taskID: taskID, runID: runID)
        try requireExplicitApproval(runID: runID, allowHighRisk: allowHighRisk)
        return (client, taskID)
    }

    private func requireFreshCurrentAttempt(
        runID: String
    ) async throws -> (RemoteHostClient, String) {
        guard let taskID = taskID(containing: runID) else {
            throw ForgeStoreError.attemptChanged
        }
        let client = try makeClient()
        let response = try await client.runList()
        runs = response.runs
        handoffs = response.handoffs
        retainArtifacts(for: response.runs)
        rebuildProjection()
        try requireCurrentAttempt(taskID: taskID, runID: runID)
        return (client, taskID)
    }

    private func requireCurrentAttempt(taskID: String, runID: String) throws {
        guard projection.missions
            .flatMap(\.tasks)
            .first(where: { $0.id == taskID })?
            .currentAttemptID == runID else {
            throw ForgeStoreError.attemptChanged
        }
    }

    private func taskID(containing runID: String) -> String? {
        projection.missions
            .flatMap(\.tasks)
            .first(where: { $0.attemptIDs.contains(runID) })?
            .id
    }

    private func requireClient() throws -> RemoteHostClient {
        try requireWritableHost()
        return try makeClient()
    }

    private func persist(_ configuration: ForgeHostConfiguration) throws {
        let data = try JSONEncoder().encode(configuration)
        defaults.set(data, forKey: Self.hostDefaultsKey)
        guard Self.loadHost(from: defaults) == configuration else {
            throw RemoteHostError.server("Host configuration could not be persisted.")
        }
    }

    private static func loadHost(from defaults: UserDefaults) -> ForgeHostConfiguration? {
        guard let data = defaults.data(forKey: hostDefaultsKey),
              let configuration = try? JSONDecoder().decode(ForgeHostConfiguration.self, from: data),
              configuration.isConfigured else {
            return nil
        }
        return configuration
    }

    private func updateHostName(_ name: String) {
        guard var configuration = host,
              let cleanName = Self.normalized(name),
              configuration.name != cleanName else {
            return
        }
        configuration.name = cleanName
        do {
            try persist(configuration)
            host = configuration
        } catch {
            record(error)
        }
    }

    private func replaceRun(_ run: RemoteRunRecord) {
        runs.removeAll { $0.id == run.id }
        runs.append(run)
    }

    private func retainArtifacts(for currentRuns: [RemoteRunRecord]) {
        let runIDs = Set(currentRuns.map(\.id))
        artifactsByRunID = artifactsByRunID.filter { runIDs.contains($0.key) }
    }

    private func replaceHandoffs(for runID: String, with replacements: [RemoteHandoffRecord]) {
        handoffs.removeAll { $0.runID == runID }
        handoffs.append(contentsOf: replacements)
    }

    private func rebuildProjection(generatedAt: Date = Date()) {
        projection = ForgeRemoteProjection.snapshot(
            from: runs,
            artifactsByRunID: artifactsByRunID,
            handoffs: handoffs,
            generatedAt: generatedAt
        )
    }

    private func refreshRunsAfterMutation() async {
        do {
            try await refreshRuns()
        } catch {
            // The mutation already succeeded. Keep its result distinct from a follow-up
            // refresh failure; refreshRuns has recorded the latter for the UI.
        }
    }

    private func record(_ error: Error) {
        lastErrorMessage = error.localizedDescription
    }

    private func recordRunsRefreshFailure(_ error: Error) {
        runsRefreshErrorMessage = VeqralRedactor.redact(error.localizedDescription, limit: 1_000)
    }

    private static func validate(_ response: RemotePairResponse, for link: RemotePairingLink) throws {
        guard normalized(response.deviceID) != nil, normalized(response.token) != nil else {
            throw ForgeStoreError.invalidPairingResponse
        }
        if link.pairingProtocolVersion == 2 {
            guard response.apiProtocolVersion == 2, response.minimumAuthVersion == 2 else {
                throw ForgeStoreError.unsupportedHostProtocol(
                    "Pairing v2 requires Host API v2 and request authentication v2."
                )
            }
        }
        if let minimumAuthVersion = response.minimumAuthVersion, minimumAuthVersion > 2 {
            throw ForgeStoreError.unsupportedHostProtocol(
                "Host request authentication v\(minimumAuthVersion) is not supported."
            )
        }
    }

    private static func stableClientID() throws -> String {
        if let existing = normalized(AppKeychainStore.get(account: stableClientIDAccount)) {
            return existing
        }
        let value = UUID().uuidString.lowercased()
        try AppKeychainStore.set(value, account: stableClientIDAccount)
        return value
    }

    private static func tokenAccount(deviceID: String) -> String {
        "remote-host:\(deviceID)"
    }

    private static func token(for deviceID: String) -> String? {
        normalized(AppKeychainStore.get(account: tokenAccount(deviceID: deviceID)))
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    #if DEBUG
    private static let fixtureNow = Date(timeIntervalSince1970: 1_735_689_600)

    private static let fixtureHost = ForgeHostConfiguration(
        endpoint: "http://127.0.0.1:7878",
        deviceID: "ui-test-device",
        name: "UI Test Mac",
        apiProtocolVersion: 2,
        minimumAuthVersion: 2
    )

    private static let fixtureHealth = RemoteHealthResponse(
        status: "ok",
        host: "UI Test Mac",
        tailscaleIP: nil,
        port: 7878,
        hermesVersion: "fixture",
        toolStatuses: [
            fixtureTool(engine: "hermes", title: "Hermes"),
            fixtureTool(engine: "codex", title: "Codex"),
            fixtureTool(engine: "claude", title: "Claude"),
            fixtureTool(engine: "shell", title: "Shell")
        ]
    )

    private static func fixtureTool(engine: String, title: String) -> RemoteCLIToolStatus {
        RemoteCLIToolStatus(
            engine: engine,
            title: title,
            executablePath: nil,
            version: "fixture",
            adapter: "fixture",
            commandShape: nil,
            isInstalled: true,
            isKnownCompatible: true,
            compatibilityNote: ""
        )
    }

    private static let fixtureRuns: [RemoteRunRecord] = [
        RemoteRunRecord(
            id: "active-run",
            prompt: "Implement the Forge mission surface",
            workingDirectory: "/Users/fixture/Veqral",
            sessionID: nil,
            status: "running",
            startedAt: fixtureNow,
            completedAt: nil,
            exitCode: nil,
            pid: nil,
            approvalReason: nil,
            approvalSeverity: nil,
            engine: "hermes",
            resumeSessionID: nil,
            projectID: "veqral-forge",
            chatID: "retry-task",
            provider: nil,
            model: nil,
            usage: nil,
            interaction: nil
        ),
        RemoteRunRecord(
            id: "old-attempt",
            prompt: "Implement the Forge mission surface",
            workingDirectory: "/Users/fixture/Veqral",
            sessionID: nil,
            status: "cancelled",
            startedAt: fixtureNow.addingTimeInterval(-300),
            completedAt: fixtureNow.addingTimeInterval(-240),
            exitCode: nil,
            pid: nil,
            approvalReason: nil,
            approvalSeverity: nil,
            engine: "hermes",
            resumeSessionID: nil,
            projectID: "veqral-forge",
            chatID: "retry-task",
            provider: nil,
            model: nil,
            usage: nil,
            interaction: nil
        ),
        RemoteRunRecord(
            id: "running-input-run",
            prompt: "Continue after receiving a release note",
            workingDirectory: "/Users/fixture/Veqral",
            sessionID: nil,
            status: "running",
            startedAt: fixtureNow.addingTimeInterval(-30),
            completedAt: nil,
            exitCode: nil,
            pid: nil,
            approvalReason: nil,
            approvalSeverity: nil,
            engine: "hermes",
            resumeSessionID: nil,
            projectID: "veqral-forge",
            chatID: nil,
            provider: nil,
            model: nil,
            usage: nil,
            interaction: CommandInteractionPrompt(
                kind: .message,
                prompt: "Need a release note before continuing.",
                choices: []
            )
        ),
        RemoteRunRecord(
            id: "approval-run",
            prompt: "Review the production handoff",
            workingDirectory: "/Users/fixture/Veqral",
            sessionID: nil,
            status: "waitingApproval",
            startedAt: fixtureNow.addingTimeInterval(-60),
            completedAt: nil,
            exitCode: nil,
            pid: nil,
            approvalReason: "Production handoff requires approval",
            approvalSeverity: "high",
            engine: "codex",
            resumeSessionID: nil,
            projectID: "veqral-forge",
            chatID: nil,
            provider: nil,
            model: nil,
            usage: nil,
            interaction: nil,
            approvalProvenance: RemoteRunApprovalProvenance(
                state: "pending",
                grantedAt: nil,
                grantedByDeviceID: nil
            )
        ),
        RemoteRunRecord(
            id: "input-run",
            prompt: "Choose the release channel",
            workingDirectory: "/Users/fixture/Veqral",
            sessionID: nil,
            status: "needsAttention",
            startedAt: fixtureNow.addingTimeInterval(-90),
            completedAt: nil,
            exitCode: nil,
            pid: nil,
            approvalReason: nil,
            approvalSeverity: nil,
            engine: "hermes",
            resumeSessionID: nil,
            projectID: "veqral-forge",
            chatID: nil,
            provider: nil,
            model: nil,
            usage: nil,
            interaction: CommandInteractionPrompt(
                kind: .message,
                prompt: "Which release channel should be used?",
                choices: []
            )
        ),
        RemoteRunRecord(
            id: "completed-run",
            prompt: "Prepare the verified handoff artifact",
            workingDirectory: "/Users/fixture/Veqral",
            sessionID: nil,
            status: "complete",
            startedAt: fixtureNow.addingTimeInterval(-120),
            completedAt: fixtureNow.addingTimeInterval(-30),
            exitCode: 0,
            pid: nil,
            approvalReason: nil,
            approvalSeverity: nil,
            engine: "claude",
            resumeSessionID: nil,
            projectID: "veqral-forge",
            chatID: nil,
            provider: nil,
            model: nil,
            usage: nil,
            interaction: nil
        )
    ]

    private static let fixtureArtifact = RemoteArtifactRecord(
        id: "fixture-handoff",
        title: "Verified handoff",
        type: "markdown",
        path: "handoff.md",
        bytes: 24,
        updatedAt: fixtureNow
    )

    private static let fixtureHandoff = RemoteHandoffRecord(
        id: "fixture-handoff-record",
        taskID: "legacy-run:completed-run",
        runID: "completed-run",
        sourceWorkstreamID: ForgeRuntime.claude.rawValue,
        targetWorkstreamID: nil,
        artifactIDs: [fixtureArtifact.id],
        summary: "Verified handoff",
        state: .readyForReview,
        createdAt: fixtureNow,
        reviewedAt: nil
    )

    private static func fixtureLogs(for runID: String) -> [RemoteHostLogEvent] {
        guard fixtureRuns.contains(where: { $0.id == runID }) else { return [] }
        let interaction: CommandInteractionPrompt? = if runID == "active-run" {
            CommandInteractionPrompt(
                kind: .message,
                prompt: "Provide the late deployment choice.",
                choices: []
            )
        } else {
            nil
        }
        return [RemoteHostLogEvent(
            runID: runID,
            kind: interaction == nil ? "log" : "approval",
            stream: "host",
            message: "Deterministic fixture event",
            createdAt: fixtureNow.addingTimeInterval(1),
            sessionID: nil,
            exitCode: nil,
            interaction: interaction
        )]
    }

    private func fixtureSnapshot(runID: String) throws -> RemoteRunSnapshotResponse {
        guard let run = Self.fixtureRuns.first(where: { $0.id == runID }) else {
            throw RemoteHostError.server("Fixture run was not found.")
        }
        let artifacts = runID == "completed-run" ? [Self.fixtureArtifact] : []
        return RemoteRunSnapshotResponse(
            run: run,
            logs: Self.fixtureLogs(for: runID),
            diff: [],
            artifacts: artifacts,
            handoffs: runID == "completed-run" ? [Self.fixtureHandoff] : []
        )
    }
    #endif
}
