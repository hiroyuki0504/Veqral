import Foundation

private struct PairingStatusWire: Decodable {
    var simulatorPairingURL: String
}

private enum ForgeClientSmokeError: Error, LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        }
    }
}

private actor StreamProbe {
    private var events: [RemoteHostLogEvent] = []
    private var failure: String?
    private var resyncCount = 0

    func append(_ event: RemoteHostLogEvent) {
        events.append(event)
    }

    func fail(_ error: Error) {
        failure = error.localizedDescription
    }

    func resync(_ snapshot: RemoteRunSnapshotResponse) {
        _ = snapshot
        resyncCount += 1
    }

    func state() -> ([RemoteHostLogEvent], String?, Int) {
        (events, failure, resyncCount)
    }
}

@main
private struct ForgeClientSmoke {
    static func main() async throws {
        guard CommandLine.arguments.count == 4,
              let baseURL = URL(string: CommandLine.arguments[1]) else {
            throw ForgeClientSmokeError.invalid("usage: ForgeClientSmoke <base-url> <working-directory> <control-directory>")
        }
        let workingDirectory = CommandLine.arguments[2]
        let controlDirectory = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)

        let contractClient = RemoteHostClient(configuration: RemoteHostConfiguration(
            isEnabled: true,
            endpoint: baseURL.absoluteString,
            deviceID: "contract-device",
            token: "contract-token",
            name: "Contract",
            minimumAuthVersion: 2
        ))
        let encodedRunPath = try contractClient.runPath("a/b", suffix: "/logs")
        guard encodedRunPath == "/v1/runs/a%2Fb/logs",
              let encodedRunURL = RemoteHostClient.endpointURL(baseURL.absoluteString, path: encodedRunPath),
              encodedRunURL.absoluteString == baseURL.absoluteString + "/v1/runs/a%2Fb/logs" else {
            throw ForgeClientSmokeError.invalid("Run URL path was double encoded")
        }

        var replayCursor = RemoteStreamReplayCursor()
        let firstReplayEvent = RemoteHostLogEvent(
            runID: "cursor-contract",
            kind: "log",
            stream: "stdout",
            message: "event-0",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            sessionID: nil,
            exitCode: nil,
            interaction: nil,
            eventID: "cursor-first"
        )
        guard replayCursor.accepts(firstReplayEvent) else {
            throw ForgeClientSmokeError.invalid("replay cursor rejected its first event")
        }
        for index in 1...4_096 {
            let event = RemoteHostLogEvent(
                runID: "cursor-contract",
                kind: "log",
                stream: "stdout",
                message: "event-\(index)",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
                sessionID: nil,
                exitCode: nil,
                interaction: nil
            )
            guard replayCursor.accepts(event) else {
                throw ForgeClientSmokeError.invalid("replay cursor rejected unique event \(index)")
            }
        }
        guard !replayCursor.accepts(firstReplayEvent) else {
            throw ForgeClientSmokeError.invalid("replay cursor forgot an older event")
        }
        let repeatedLineA = RemoteHostLogEvent(
            runID: "cursor-contract",
            kind: "log",
            stream: "stdout",
            message: "same line",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            sessionID: nil,
            exitCode: nil,
            interaction: nil,
            eventID: "repeated-a"
        )
        let repeatedLineB = RemoteHostLogEvent(
            runID: repeatedLineA.runID,
            kind: repeatedLineA.kind,
            stream: repeatedLineA.stream,
            message: repeatedLineA.message,
            createdAt: repeatedLineA.createdAt,
            sessionID: repeatedLineA.sessionID,
            exitCode: repeatedLineA.exitCode,
            interaction: repeatedLineA.interaction,
            eventID: "repeated-b"
        )
        guard replayCursor.accepts(repeatedLineA),
              replayCursor.accepts(repeatedLineB),
              !replayCursor.accepts(repeatedLineA) else {
            throw ForgeClientSmokeError.invalid("stable event IDs suppressed a legitimate repeated log or accepted a replay")
        }

        var replayState = RemoteRunRecord(
            id: "attempt-replay",
            prompt: "Wait for input",
            workingDirectory: workingDirectory,
            sessionID: "session-new",
            status: "running",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: nil,
            exitCode: nil,
            pid: nil,
            approvalReason: nil,
            approvalSeverity: nil,
            engine: "hermes",
            resumeSessionID: nil,
            projectID: "forge-client-smoke",
            chatID: nil,
            provider: nil,
            model: nil,
            usage: nil,
            interaction: nil,
            statusUpdatedAt: Date(timeIntervalSince1970: 300),
            taskID: "task:replay"
        )
        let staleInteraction = RemoteHostLogEvent(
            runID: replayState.id,
            kind: "approval",
            stream: "stdout",
            message: "Old input prompt",
            createdAt: Date(timeIntervalSince1970: 200),
            sessionID: nil,
            exitCode: nil,
            interaction: CommandInteractionPrompt(kind: .message, prompt: "Old input prompt", choices: []),
            eventID: "stale-interaction",
            runStatus: "running"
        )
        guard !RemoteRunStreamReducer.apply(staleInteraction, to: &replayState),
              replayState.interaction == nil else {
            throw ForgeClientSmokeError.invalid("persisted replay resurrected resolved input")
        }
        let terminalEvent = RemoteHostLogEvent(
            runID: replayState.id,
            kind: "complete",
            stream: "host",
            message: "Exit code: 0",
            createdAt: Date(timeIntervalSince1970: 400),
            sessionID: "session-new",
            exitCode: 0,
            interaction: nil,
            eventID: "terminal-event",
            runStatus: "complete"
        )
        guard RemoteRunStreamReducer.apply(terminalEvent, to: &replayState),
              replayState.status == "complete",
              replayState.completedAt == terminalEvent.createdAt else {
            throw ForgeClientSmokeError.invalid("live terminal event did not update Run state")
        }

        let pairingStatusURL = baseURL.appending(path: "v1/pairing")
        let (pairingData, response) = try await URLSession.shared.data(from: pairingStatusURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ForgeClientSmokeError.invalid("pairing status failed")
        }
        let pairingStatus = try JSONDecoder.forge.decode(PairingStatusWire.self, from: pairingData)
        guard let pairingURL = URL(string: pairingStatus.simulatorPairingURL) else {
            throw ForgeClientSmokeError.invalid("invalid simulator pairing URL")
        }
        let link = try RemotePairingLink(url: pairingURL)
        guard let endpoint = link.endpoints.first else {
            throw ForgeClientSmokeError.invalid("pairing link has no endpoint")
        }
        let paired = try await RemoteHostClient.pair(
            endpoint: endpoint,
            deviceName: "Forge client smoke",
            pairingCode: link.pairingCode,
            pairingSignature: link.legacySignature,
            signedEndpoint: link.signedEndpoint,
            clientStableID: "forge-client-smoke",
            pairingLink: link
        )
        guard paired.minimumAuthVersion == 2 else {
            throw ForgeClientSmokeError.invalid("pairing response did not require auth v2")
        }
        let deviceID = paired.deviceID
        let token = paired.token
        let client = RemoteHostClient(configuration: RemoteHostConfiguration(
            isEnabled: true,
            endpoint: endpoint,
            deviceID: deviceID,
            token: token,
            name: "Forge smoke",
            minimumAuthVersion: paired.minimumAuthVersion
        ))
        let health = try await client.health()
        guard health.status == "ok" else {
            throw ForgeClientSmokeError.invalid("Host health is not ok")
        }

        let created = try await client.createRun(ForgeRunRequest(
            prompt: "Delete .env and deploy production. This must stop for explicit approval and must never execute in this smoke.",
            workingDirectory: workingDirectory,
            runtime: .hermes,
            projectID: "forge-client-smoke",
            taskID: "task:forge-client-smoke"
        ))
        guard created.approvalRequired == true,
              created.approvalSeverity?.lowercased() == "high" else {
            throw ForgeClientSmokeError.invalid("high-risk Run did not stop for approval")
        }

        let list = try await client.runList()
        guard list.runs.contains(where: {
            $0.id == created.runID && $0.taskID == "task:forge-client-smoke"
        }) else {
            throw ForgeClientSmokeError.invalid("created Run is missing from list")
        }
        let snapshot = try await client.runSnapshot(remoteRunID: created.runID)
        guard snapshot.run.status == "waitingApproval" else {
            throw ForgeClientSmokeError.invalid("Run escaped approval gate: \(snapshot.run.status)")
        }
        let projection = ForgeRemoteProjection.snapshot(
            from: [snapshot.run],
            artifactsByRunID: [created.runID: snapshot.artifacts]
        )
        guard let attention = projection.attention.first,
              attention.kind == .approval,
              attention.approvalSeverity == .high,
              attention.runID == created.runID,
              attention.taskID != attention.runID else {
            throw ForgeClientSmokeError.invalid("Run was not projected as a distinct high approval Task")
        }
        var missingApprovalProvenance = snapshot.run
        missingApprovalProvenance.approvalProvenance = nil
        let missingProvenanceProjection = ForgeRemoteProjection.snapshot(from: [missingApprovalProvenance])
        guard missingProvenanceProjection.attention.first?.kind == .unsupported else {
            throw ForgeClientSmokeError.invalid("missing approval provenance did not fail closed")
        }
        var failedUnsupportedRuntime = snapshot.run
        failedUnsupportedRuntime.status = "failed"
        failedUnsupportedRuntime.engine = "shell"
        failedUnsupportedRuntime.interaction = nil
        let failedUnsupportedProjection = ForgeRemoteProjection.snapshot(from: [failedUnsupportedRuntime])
        guard let failedUnsupportedTask = failedUnsupportedProjection.missions.flatMap(\.tasks).first,
              failedUnsupportedTask.state == .failed,
              failedUnsupportedProjection.attention.contains(where: { $0.kind == .blocker }) else {
            throw ForgeClientSmokeError.invalid("unsupported runtime overwrote failed blocker state")
        }

        _ = try await client.runLogs(remoteRunID: created.runID)
        _ = try await client.runDiff(remoteRunID: created.runID)
        let handoffURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
            .appendingPathComponent("result.handoff.md", isDirectory: false)
        try Data("# Handoff\nReview this explicit deliverable.\n".utf8).write(to: handoffURL, options: .atomic)
        let artifactResponse = try await client.runArtifacts(remoteRunID: created.runID)
        guard let handoffArtifact = artifactResponse.artifacts.first(where: { $0.type == "handoff" }) else {
            throw ForgeClientSmokeError.invalid("explicit handoff artifact was not transported")
        }
        let handoffSnapshot = try await client.runSnapshot(remoteRunID: created.runID)
        guard handoffSnapshot.handoffs.contains(where: {
            $0.taskID == "task:forge-client-smoke"
                && $0.runID == created.runID
                && $0.artifactIDs.contains(handoffArtifact.id)
                && $0.state == .readyForReview
        }) else {
            throw ForgeClientSmokeError.invalid("first-class handoff record was not transported")
        }
        let handoffProjection = ForgeRemoteProjection.snapshot(
            from: [handoffSnapshot.run],
            artifactsByRunID: [created.runID: handoffSnapshot.artifacts],
            handoffs: handoffSnapshot.handoffs
        )
        guard handoffProjection.missions
            .flatMap(\.tasks)
            .first(where: { $0.id == "task:forge-client-smoke" })?
            .handoffs
            .contains(where: { $0.artifactIDs.contains(handoffArtifact.id) }) == true,
              handoffProjection.attention.contains(where: {
                  $0.kind == .review && $0.taskID == "task:forge-client-smoke"
              }) else {
            throw ForgeClientSmokeError.invalid("explicit handoff relationship was not projected for review")
        }
        try await verifyStreamReconnects(
            client: client,
            runID: created.runID,
            taskID: "task:forge-client-smoke",
            controlDirectory: controlDirectory
        )

        let cancelled = try await client.runSnapshot(remoteRunID: created.runID)
        guard cancelled.run.status == "cancelled" else {
            throw ForgeClientSmokeError.invalid("Run did not cancel")
        }

        let superseding = try await client.createRun(ForgeRunRequest(
            prompt: "Delete .env and deploy production. This superseding attempt must remain approval-gated.",
            workingDirectory: workingDirectory,
            runtime: .hermes,
            projectID: "forge-client-smoke",
            taskID: "task:forge-client-smoke"
        ))
        let postRetryList = try await client.runList()
        guard postRetryList.handoffs.contains(where: {
            $0.taskID == "task:forge-client-smoke"
                && $0.runID == created.runID
                && $0.state == .readyForReview
        }) else {
            throw ForgeClientSmokeError.invalid("persisted handoff disappeared after Host restart or Task retry")
        }
        do {
            try await client.cancel(
                remoteRunID: created.runID,
                expectedTaskID: "task:forge-client-smoke"
            )
            throw ForgeClientSmokeError.invalid("stale Run attempt accepted a control mutation")
        } catch is ForgeClientSmokeError {
            throw ForgeClientSmokeError.invalid("stale Run attempt accepted a control mutation")
        } catch {
            // Expected: Host atomically rejects an old attempt for this Task.
        }
        try await client.cancel(
            remoteRunID: superseding.runID,
            expectedTaskID: "task:forge-client-smoke"
        )

        print("PASS: Forge Swift client pair=1 auth-v2=1 health=1 run-list=1 high-approval-gate=1 approval-provenance=1 failed-blocker=1 projection=1 task-id=1 atomic-attempt=1 stale-replay=1 live-status=1 explicit-handoff=1 handoff-persistence=1 logs=1 diff=1 artifacts=1 stream-reconnect=1 replay-dedup=1 replay-dedup-4097=1 event-id=1 repeated-lines=1 snapshot-resync=1 cancel=1 url-path=1")
    }

    private static func verifyStreamReconnects(
        client: RemoteHostClient,
        runID: String,
        taskID: String,
        controlDirectory: URL
    ) async throws {
        let probe = StreamProbe()
        let streamTask = Task {
            do {
                for try await event in client.stream(
                    remoteRunID: runID,
                    onResync: { snapshot in await probe.resync(snapshot) }
                ) {
                    await probe.append(event)
                }
            } catch {
                await probe.fail(error)
            }
        }
        defer { streamTask.cancel() }

        try await waitForStream(probe, description: "initial stream event") { !$0.isEmpty }
        let restartRequestURL = controlDirectory.appendingPathComponent("restart.request", isDirectory: false)
        guard FileManager.default.createFile(
            atPath: restartRequestURL.path,
            contents: Data("restart\n".utf8)
        ), FileManager.default.fileExists(atPath: restartRequestURL.path) else {
            throw ForgeClientSmokeError.invalid("could not create Host restart marker at \(restartRequestURL.path)")
        }
        try await waitForFile(
            controlDirectory.appendingPathComponent("restart.done", isDirectory: false),
            description: "Host restart"
        )
        try await client.cancel(remoteRunID: runID, expectedTaskID: taskID)
        try await waitForStream(probe, description: "post-restart cancel event") { events in
            events.contains { $0.message == "Run cancelled" }
        }

        let (events, failure, resyncCount) = await probe.state()
        if let failure {
            throw ForgeClientSmokeError.invalid("stream failed during Host restart: \(failure)")
        }
        let identities = events.map(RemoteStreamReplayCursor.identity(for:))
        guard Set(identities).count == identities.count else {
            throw ForgeClientSmokeError.invalid("replayed stream events were emitted twice")
        }
        guard events.allSatisfy({ $0.eventID?.isEmpty == false }) else {
            throw ForgeClientSmokeError.invalid("Host stream event was missing a stable event ID")
        }
        guard resyncCount >= 2 else {
            throw ForgeClientSmokeError.invalid("stream did not resync its snapshot after Host restart")
        }
    }

    private static func waitForStream(
        _ probe: StreamProbe,
        description: String,
        predicate: ([RemoteHostLogEvent]) -> Bool
    ) async throws {
        for _ in 0..<200 {
            let (events, failure, _) = await probe.state()
            if predicate(events) { return }
            if let failure {
                throw ForgeClientSmokeError.invalid("\(description) failed: \(failure)")
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw ForgeClientSmokeError.invalid("\(description) timed out")
    }

    private static func waitForFile(_ url: URL, description: String) async throws {
        for _ in 0..<200 {
            if FileManager.default.fileExists(atPath: url.path) { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw ForgeClientSmokeError.invalid("\(description) timed out")
    }
}
