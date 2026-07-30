import Foundation

enum RemoteHostError: Error, LocalizedError, Sendable {
    case invalidConfiguration
    case authentication(String)
    case humanAttentionRequired(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "Remote Host is not configured."
        case .authentication(let message), .humanAttentionRequired(let message), .server(let message):
            message
        }
    }
}

private struct RemoteRunControlBody: Encodable {
    var expectedTaskID: String
}

struct RemoteHostClient: Sendable {
    let configuration: RemoteHostConfiguration

    static func pair(
        endpoint: String,
        deviceName: String,
        pairingCode: String,
        pairingSignature: String? = nil,
        signedEndpoint: String? = nil,
        clientStableID: String? = nil,
        pairingLink: RemotePairingLink? = nil
    ) async throws -> RemotePairResponse {
        guard let url = endpointURL(endpoint, path: "/v1/pair") else {
            throw RemoteHostError.invalidConfiguration
        }
        let pairingEndpoint = pairingLink?.signedEndpoint ?? signedEndpoint?.nilIfBlank ?? endpoint
        struct PairBody: Codable {
            var deviceName: String
            var pairingCode: String
            var pairingEndpoint: String
            var pairingSignature: String?
            var clientStableID: String?
            var pairingProtocolVersion: Int?
            var apiProtocolVersion: Int?
            var requestAuthVersions: [Int]?
            var capabilities: [String]?
            var pairingEndpoints: [String]?
            var pairingProof: String?
            var selectedEndpoint: String?
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.forge.encode(PairBody(
            deviceName: deviceName,
            pairingCode: pairingCode,
            pairingEndpoint: pairingEndpoint,
            pairingSignature: pairingLink?.legacySignature ?? pairingSignature,
            clientStableID: clientStableID,
            pairingProtocolVersion: pairingLink?.pairingProtocolVersion,
            apiProtocolVersion: pairingLink?.apiProtocolVersion,
            requestAuthVersions: pairingLink?.requestAuthVersions,
            capabilities: pairingLink?.capabilities,
            pairingEndpoints: pairingLink?.endpoints,
            pairingProof: pairingLink?.pairingProof,
            selectedEndpoint: pairingLink == nil ? nil : endpoint
        ))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.forge.decode(RemotePairResponse.self, from: data)
    }

    func health() async throws -> RemoteHealthResponse {
        guard let url = Self.endpointURL(configuration.endpoint, path: "/v1/health") else {
            throw RemoteHostError.invalidConfiguration
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.validate(response: response, data: data)
        return try JSONDecoder.forge.decode(RemoteHealthResponse.self, from: data)
    }

    func createRun(_ runRequest: ForgeRunRequest) async throws -> RemoteCreateRunResponse {
        struct Body: Encodable {
            var prompt: String
            var workingDirectory: String
            var engine: String
            var resumeSessionID: String?
            var projectID: String?
            var taskID: String
            var chatID: String?
            var provider: String?
            var model: String?
            var attachments: [RemoteRunAttachment]
        }
        let provider = runRequest.provider?.nilIfBlank.flatMap {
            $0.caseInsensitiveCompare("auto") == .orderedSame ? nil : $0
        }
        let body = try JSONEncoder.forge.encode(Body(
            prompt: runRequest.prompt,
            workingDirectory: runRequest.workingDirectory,
            engine: runRequest.runtime.rawValue,
            resumeSessionID: runRequest.resumeSessionID?.nilIfBlank,
            projectID: runRequest.projectID?.nilIfBlank,
            taskID: runRequest.taskID,
            chatID: runRequest.chatID?.nilIfBlank,
            provider: provider,
            model: runRequest.model?.nilIfBlank,
            attachments: runRequest.attachments.map {
                RemoteRunAttachment(id: $0.id, fileName: $0.fileName, mimeType: $0.mimeType, data: $0.data)
            }
        ))
        return try await decode(RemoteCreateRunResponse.self, path: "/v1/runs", method: "POST", body: body)
    }

    func runList() async throws -> RemoteRunListResponse {
        try await decode(RemoteRunListResponse.self, path: "/v1/runs")
    }

    func runSnapshot(remoteRunID: String) async throws -> RemoteRunSnapshotResponse {
        try await decode(RemoteRunSnapshotResponse.self, path: try runPath(remoteRunID))
    }

    func runLogs(remoteRunID: String) async throws -> RemoteRunLogResponse {
        try await decode(RemoteRunLogResponse.self, path: try runPath(remoteRunID, suffix: "/logs"))
    }

    func runDiff(remoteRunID: String) async throws -> RemoteGitDiffResponse {
        try await decode(RemoteGitDiffResponse.self, path: try runPath(remoteRunID, suffix: "/diff"))
    }

    func runArtifacts(remoteRunID: String) async throws -> RemoteArtifactListResponse {
        try await decode(RemoteArtifactListResponse.self, path: try runPath(remoteRunID, suffix: "/artifacts"))
    }

    func artifactContent(remoteRunID: String, artifactID: String) async throws -> RemoteArtifactContentResponse {
        struct Body: Encodable { var artifactID: String }
        let body = try JSONEncoder.forge.encode(Body(artifactID: artifactID))
        return try await decode(
            RemoteArtifactContentResponse.self,
            path: try runPath(remoteRunID, suffix: "/artifact-content"),
            method: "POST",
            body: body
        )
    }

    func cancel(remoteRunID: String, expectedTaskID: String) async throws {
        let body = try JSONEncoder.forge.encode(RemoteRunControlBody(expectedTaskID: expectedTaskID))
        _ = try await request(path: try runPath(remoteRunID, suffix: "/cancel"), method: "POST", body: body)
    }

    func resume(remoteRunID: String, expectedTaskID: String) async throws {
        let body = try JSONEncoder.forge.encode(RemoteRunControlBody(expectedTaskID: expectedTaskID))
        _ = try await request(path: try runPath(remoteRunID, suffix: "/resume"), method: "POST", body: body)
    }

    func approve(remoteRunID: String, expectedTaskID: String) async throws {
        let body = try JSONEncoder.forge.encode(RemoteRunControlBody(expectedTaskID: expectedTaskID))
        _ = try await request(path: try runPath(remoteRunID, suffix: "/approve"), method: "POST", body: body)
    }

    func reject(remoteRunID: String, expectedTaskID: String) async throws {
        let body = try JSONEncoder.forge.encode(RemoteRunControlBody(expectedTaskID: expectedTaskID))
        _ = try await request(path: try runPath(remoteRunID, suffix: "/reject"), method: "POST", body: body)
    }

    func submitInput(remoteRunID: String, expectedTaskID: String, text: String, submit: Bool = true) async throws {
        struct Body: Encodable {
            var expectedTaskID: String
            var text: String
            var submit: Bool
        }
        let body = try JSONEncoder.forge.encode(Body(expectedTaskID: expectedTaskID, text: text, submit: submit))
        _ = try await request(path: try runPath(remoteRunID, suffix: "/input"), method: "POST", body: body)
    }

    func registerPushToken(
        deviceToken: String,
        environment: String,
        bundleID: String,
        locale: String
    ) async throws -> RemotePushTokenResponse {
        struct Body: Encodable {
            var deviceToken: String
            var environment: String
            var bundleID: String
            var locale: String
        }
        let body = try JSONEncoder.forge.encode(Body(
            deviceToken: deviceToken,
            environment: environment,
            bundleID: bundleID,
            locale: locale
        ))
        return try await decode(RemotePushTokenResponse.self, path: "/v1/push/token", method: "POST", body: body)
    }

    func stream(
        remoteRunID: String,
        onResync: @escaping @Sendable (RemoteRunSnapshotResponse) async -> Void = { _ in }
    ) -> AsyncThrowingStream<RemoteHostLogEvent, Error> {
        AsyncThrowingStream { continuation in
            let path: String
            do {
                path = try runPath(remoteRunID, suffix: "/events")
            } catch {
                continuation.finish(throwing: error)
                return
            }

            let driver = Task {
                var replayCursor = RemoteStreamReplayCursor()
                var reconnectAttempt = 0

                while !Task.isCancelled {
                    var socket: URLSessionWebSocketTask?
                    do {
                        let snapshot = try await runSnapshot(remoteRunID: remoteRunID)
                        await onResync(snapshot)
                        let replay = try await runLogs(remoteRunID: remoteRunID)
                        for event in replay.logs where replayCursor.accepts(event) {
                            continuation.yield(event)
                        }
                        if Self.isTerminalRunStatus(snapshot.run.status) {
                            continuation.finish()
                            return
                        }

                        guard let baseURL = Self.endpointURL(configuration.endpoint, path: path) else {
                            throw RemoteHostError.invalidConfiguration
                        }
                        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
                        components?.scheme = baseURL.scheme?.lowercased() == "https" ? "wss" : "ws"
                        components?.query = nil
                        components?.fragment = nil
                        guard let url = components?.url else {
                            throw RemoteHostError.invalidConfiguration
                        }

                        var request = URLRequest(url: url)
                        sign(&request, method: "GET", path: path, body: Data())
                        let activeSocket = URLSession.shared.webSocketTask(with: request)
                        socket = activeSocket
                        activeSocket.resume()

                        try await withTaskCancellationHandler {
                            while !Task.isCancelled {
                                let message = try await activeSocket.receive()
                                let data: Data
                                switch message {
                                case .data(let payload): data = payload
                                case .string(let text): data = Data(text.utf8)
                                @unknown default: continue
                                }
                                let event = try JSONDecoder.forge.decode(RemoteHostLogEvent.self, from: data)
                                reconnectAttempt = 0
                                if replayCursor.accepts(event) {
                                    continuation.yield(event)
                                }
                            }
                        } onCancel: {
                            activeSocket.cancel(with: .goingAway, reason: nil)
                        }
                    } catch {
                        socket?.cancel(with: .goingAway, reason: nil)
                        guard !Task.isCancelled else {
                            continuation.finish()
                            return
                        }
                        guard Self.shouldRetryStream(after: error) else {
                            continuation.finish(throwing: error)
                            return
                        }
                        reconnectAttempt += 1
                        let delay = Self.reconnectDelaySeconds(attempt: reconnectAttempt)
                        do {
                            try await Task.sleep(for: .seconds(delay))
                        } catch {
                            continuation.finish()
                            return
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in driver.cancel() }
        }
    }

    private func decode<T: Decodable>(
        _ type: T.Type,
        path: String,
        method: String = "GET",
        body: Data = Data()
    ) async throws -> T {
        let data = try await request(path: path, method: method, body: body)
        return try JSONDecoder.forge.decode(type, from: data)
    }

    private func request(path: String, method: String, body: Data = Data()) async throws -> Data {
        guard let url = Self.endpointURL(configuration.endpoint, path: path) else {
            throw RemoteHostError.invalidConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body.isEmpty ? nil : body
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        sign(&request, method: method, path: path, body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, data: data)
        return data
    }

    private func sign(_ request: inout URLRequest, method: String, path: String, body: Data) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let nonce = UUID().uuidString.lowercased()
        request.setValue(configuration.deviceID, forHTTPHeaderField: "X-Veqral-Device")
        request.setValue(timestamp, forHTTPHeaderField: "X-Veqral-Timestamp")
        request.setValue("2", forHTTPHeaderField: "X-Veqral-Auth-Version")
        request.setValue(nonce, forHTTPHeaderField: "X-Veqral-Nonce")
        request.setValue(
            RemoteHostSigner.signature(
                token: configuration.token,
                deviceID: configuration.deviceID,
                authVersion: 2,
                method: method,
                path: path,
                timestamp: timestamp,
                nonce: nonce,
                body: body
            ),
            forHTTPHeaderField: "X-Veqral-Signature"
        )
    }

    func runPath(_ runID: String, suffix: String = "") throws -> String {
        guard !runID.isEmpty,
              let encoded = runID.addingPercentEncoding(withAllowedCharacters: Self.pathComponentAllowed),
              !encoded.isEmpty else {
            throw RemoteHostError.invalidConfiguration
        }
        return "/v1/runs/\(encoded)\(suffix)"
    }

    static func endpointURL(_ endpoint: String, path: String) -> URL? {
        guard var components = URLComponents(string: endpoint),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false,
              path.hasPrefix("/") else {
            return nil
        }
        components.percentEncodedPath = path
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw RemoteHostError.server("Invalid response")
        }
        guard !(200..<300).contains(http.statusCode) else { return }
        let rawMessage = (try? JSONDecoder.forge.decode([String: String].self, from: data)["error"])
            ?? "HTTP \(http.statusCode)"
        let message = VeqralRedactor.redact(rawMessage, limit: 1_000)
        switch http.statusCode {
        case 401, 403, 426:
            throw RemoteHostError.authentication(message)
        case 409:
            throw RemoteHostError.humanAttentionRequired(message)
        default:
            throw RemoteHostError.server(message)
        }
    }

    private static func shouldRetryStream(after error: Error) -> Bool {
        switch error {
        case RemoteHostError.invalidConfiguration,
             RemoteHostError.authentication:
            return false
        case RemoteHostError.server(let message):
            return !message.localizedCaseInsensitiveContains("not found")
        default:
            return true
        }
    }

    private static func isTerminalRunStatus(_ status: String) -> Bool {
        ["complete", "failed", "cancelled"].contains(status.lowercased())
    }

    private static func reconnectDelaySeconds(attempt: Int) -> Int {
        min(30, max(1, 1 << min(max(attempt - 1, 0), 5)))
    }

    private static let pathComponentAllowed = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "-._~"))
}
