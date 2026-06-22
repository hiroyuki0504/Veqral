import Foundation

enum RemoteHostError: Error, LocalizedError {
    case invalidConfiguration
    case authentication(String)
    case approvalRequired(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "Remote Host is not configured."
        case .authentication(let message):
            message
        case .approvalRequired(let message):
            message
        case .server(let message):
            message
        }
    }
}

struct RemoteHostClient: Sendable {
    let configuration: RemoteHostConfiguration

    static func pair(endpoint: String, deviceName: String, pairingCode: String, pairingSignature: String? = nil) async throws -> RemotePairResponse {
        guard let url = URL(string: "/v1/pair", relativeTo: URL(string: endpoint)) else {
            throw RemoteHostError.invalidConfiguration
        }
        struct PairBody: Codable {
            var deviceName: String
            var pairingCode: String
            var pairingEndpoint: String
            var pairingSignature: String?
        }
        var request = URLRequest(url: url.absoluteURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.commandCenter.encode(PairBody(
            deviceName: deviceName,
            pairingCode: pairingCode,
            pairingEndpoint: endpoint,
            pairingSignature: pairingSignature
        ))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteHostError.server("Invalid response")
        }
        if [401, 403].contains(http.statusCode) {
            let message = (try? JSONDecoder.commandCenter.decode([String: String].self, from: data)["error"]) ?? "Unauthorized"
            throw RemoteHostError.authentication(message)
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder.commandCenter.decode([String: String].self, from: data)["error"]) ?? "HTTP \(http.statusCode)"
            throw RemoteHostError.server(message)
        }
        return try JSONDecoder.commandCenter.decode(RemotePairResponse.self, from: data)
    }

    func health() async throws -> RemoteHealthResponse {
        guard let url = URL(string: "/v1/health", relativeTo: URL(string: configuration.endpoint)) else {
            throw RemoteHostError.invalidConfiguration
        }
        let (data, response) = try await URLSession.shared.data(from: url.absoluteURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RemoteHostError.server("Health check failed")
        }
        return try JSONDecoder.commandCenter.decode(RemoteHealthResponse.self, from: data)
    }

    func telemetry() async throws -> RemoteHostTelemetry {
        let data = try await request(path: "/v1/telemetry", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteHostTelemetry.self, from: data)
    }

    func authOnboardingStatus() async throws -> RemoteAuthOnboardingStatus {
        let data = try await request(path: "/v1/auth/onboarding", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteAuthOnboardingStatus.self, from: data)
    }

    func refreshAuthOnboarding() async throws -> RemoteAuthOnboardingStatus {
        let data = try await request(path: "/v1/auth/onboarding/refresh", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteAuthOnboardingStatus.self, from: data)
    }

    func cleanupVoiceCommand(_ requestBody: RemoteVoiceCleanupRequest) async throws -> RemoteVoiceCleanupResponse {
        let body = try JSONEncoder.commandCenter.encode(requestBody)
        let data = try await request(path: "/v1/voice/cleanup", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteVoiceCleanupResponse.self, from: data)
    }

    func testDiscordNotification() async throws -> RemoteNotificationTestResponse {
        let data = try await request(path: "/v1/notifications/discord/test", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteNotificationTestResponse.self, from: data)
    }

    func createRun(
        prompt: String,
        workingDirectory: String,
        runtime: CommandRuntime,
        resumeSessionID: String?,
        projectID: String?,
        chatID: String?,
        provider: String?,
        model: String?,
        attachments: [CommandAttachment] = []
    ) async throws -> RemoteCreateRunResponse {
        struct Body: Encodable {
            var prompt: String
            var workingDirectory: String
            var engine: String?
            var resumeSessionID: String?
            var projectID: String?
            var chatID: String?
            var provider: String?
            var model: String?
            var attachments: [RemoteRunAttachment]
        }
        let body = try JSONEncoder.commandCenter.encode(Body(
            prompt: prompt,
            workingDirectory: workingDirectory,
            engine: runtime.remoteEngine,
            resumeSessionID: resumeSessionID,
            projectID: projectID,
            chatID: chatID,
            provider: provider == "auto" ? nil : provider,
            model: model?.nilIfBlank,
            attachments: attachments.map {
                RemoteRunAttachment(id: $0.id, fileName: $0.fileName, mimeType: $0.mimeType, data: $0.data)
            }
        ))
        let data = try await request(path: "/v1/runs", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteCreateRunResponse.self, from: data)
    }

    func runList() async throws -> RemoteRunListResponse {
        let data = try await request(path: "/v1/runs", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteRunListResponse.self, from: data)
    }

    func runSnapshot(remoteRunID: String) async throws -> RemoteRunSnapshotResponse {
        let data = try await request(path: "/v1/runs/\(remoteRunID)", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteRunSnapshotResponse.self, from: data)
    }

    func runLogs(remoteRunID: String) async throws -> RemoteRunLogResponse {
        let data = try await request(path: "/v1/runs/\(remoteRunID)/logs", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteRunLogResponse.self, from: data)
    }

    func runDiff(remoteRunID: String) async throws -> RemoteGitDiffResponse {
        let data = try await request(path: "/v1/runs/\(remoteRunID)/diff", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteGitDiffResponse.self, from: data)
    }

    func runArtifacts(remoteRunID: String) async throws -> RemoteArtifactListResponse {
        let data = try await request(path: "/v1/runs/\(remoteRunID)/artifacts", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteArtifactListResponse.self, from: data)
    }

    func artifactContent(remoteRunID: String, artifactID: String) async throws -> RemoteArtifactContentResponse {
        struct Body: Encodable {
            var artifactID: String
        }
        let body = try JSONEncoder.commandCenter.encode(Body(artifactID: artifactID))
        let data = try await request(path: "/v1/runs/\(remoteRunID)/artifact-content", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteArtifactContentResponse.self, from: data)
    }

    func cancel(remoteRunID: String) async throws {
        _ = try await request(path: "/v1/runs/\(remoteRunID)/cancel", method: "POST", body: Data())
    }

    func resume(remoteRunID: String) async throws {
        _ = try await request(path: "/v1/runs/\(remoteRunID)/resume", method: "POST", body: Data())
    }

    func approve(remoteRunID: String) async throws {
        _ = try await request(path: "/v1/runs/\(remoteRunID)/approve", method: "POST", body: Data())
    }

    func reject(remoteRunID: String) async throws {
        _ = try await request(path: "/v1/runs/\(remoteRunID)/reject", method: "POST", body: Data())
    }

    func hermesControlStatus() async throws -> HermesControlStatus {
        let data = try await request(path: "/v1/hermes/control", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(HermesControlStatus.self, from: data)
    }

    func updateHermesControl(_ update: HermesControlUpdate) async throws -> HermesControlUpdateResult {
        let body = try JSONEncoder.commandCenter.encode(update)
        let data = try await request(path: "/v1/hermes/control", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(HermesControlUpdateResult.self, from: data)
    }

    func hermesApprovals() async throws -> HermesApprovalList {
        let data = try await request(path: "/v1/hermes/approvals", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(HermesApprovalList.self, from: data)
    }

    func decideHermesApproval(id: String, decision: String, note: String?) async throws {
        struct Body: Encodable {
            var id: String
            var decision: String
            var note: String?
        }
        let body = try JSONEncoder.commandCenter.encode(Body(id: id, decision: decision, note: note))
        _ = try await request(path: "/v1/hermes/approvals/decide", method: "POST", body: body)
    }

    func devices() async throws -> RemoteDeviceListResponse {
        let data = try await request(path: "/v1/devices", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteDeviceListResponse.self, from: data)
    }

    func revokeDevice(deviceID: String) async throws {
        _ = try await request(path: "/v1/devices/\(deviceID)/revoke", method: "POST", body: Data())
    }

    func audit() async throws -> RemoteAuditLogResponse {
        let data = try await request(path: "/v1/audit", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteAuditLogResponse.self, from: data)
    }

    func githubStatus(workingDirectory: String) async throws -> RemoteGitHubStatus {
        let body = try JSONEncoder.commandCenter.encode(["workingDirectory": workingDirectory])
        let data = try await request(path: "/v1/github/status", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteGitHubStatus.self, from: data)
    }

    func createDraftPR(workingDirectory: String, title: String, body: String) async throws -> RemoteDraftPRResponse {
        let bodyData = try JSONEncoder.commandCenter.encode([
            "workingDirectory": workingDirectory,
            "title": title,
            "body": body
        ])
        let data = try await request(path: "/v1/github/draft-pr", method: "POST", body: bodyData)
        return try JSONDecoder.commandCenter.decode(RemoteDraftPRResponse.self, from: data)
    }

    func costBudgets() async throws -> RemoteProjectBudgetListResponse {
        let data = try await request(path: "/v1/budgets", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteProjectBudgetListResponse.self, from: data)
    }

    func updateCostBudget(_ requestBody: RemoteProjectBudgetUpdateRequest) async throws -> RemoteProjectCostSummary {
        let body = try JSONEncoder.commandCenter.encode(requestBody)
        let data = try await request(path: "/v1/budgets", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteProjectCostSummary.self, from: data)
    }

    func registerPushToken(deviceToken: String, environment: String, bundleID: String, locale: String) async throws -> RemotePushTokenResponse {
        struct Body: Encodable {
            var deviceToken: String
            var environment: String
            var bundleID: String
            var locale: String
        }
        let body = try JSONEncoder.commandCenter.encode(Body(
            deviceToken: deviceToken,
            environment: environment,
            bundleID: bundleID,
            locale: locale
        ))
        let data = try await request(path: "/v1/push/token", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemotePushTokenResponse.self, from: data)
    }

    func portfolioAssets() async throws -> RemotePortfolioAssetListResponse {
        let data = try await request(path: "/v1/portfolio/assets", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemotePortfolioAssetListResponse.self, from: data)
    }

    func discoverPortfolio() async throws -> RemotePortfolioAssetListResponse {
        struct Body: Encodable {
            var engagementRoots: [String]?
            var codeRoots: [String]?
            var includeGitHub: Bool?
        }
        let body = try JSONEncoder.commandCenter.encode(Body(engagementRoots: nil, codeRoots: nil, includeGitHub: nil))
        let data = try await request(path: "/v1/portfolio/discover", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemotePortfolioAssetListResponse.self, from: data)
    }

    func savePortfolioAsset(_ asset: PortfolioAsset) async throws -> PortfolioAsset {
        struct Body: Encodable {
            var asset: PortfolioAsset
        }
        let body = try JSONEncoder.commandCenter.encode(Body(asset: asset))
        let method = asset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "POST" : "PATCH"
        let path = method == "POST" ? "/v1/portfolio/assets" : "/v1/portfolio/assets/\(asset.id)"
        let data = try await request(path: path, method: method, body: body)
        return try JSONDecoder.commandCenter.decode(PortfolioAsset.self, from: data)
    }

    func portfolioStatus(assetID: String) async throws -> RemotePortfolioStatusResponse {
        let data = try await request(path: "/v1/portfolio/assets/\(assetID)/status", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemotePortfolioStatusResponse.self, from: data)
    }

    func portfolioLogs(assetID: String) async throws -> RemotePortfolioLogsResponse {
        let data = try await request(path: "/v1/portfolio/assets/\(assetID)/logs", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemotePortfolioLogsResponse.self, from: data)
    }

    func portfolioLogSummary(assetID: String) async throws -> RemotePortfolioSummaryResponse {
        let data = try await request(path: "/v1/portfolio/assets/\(assetID)/log-summary", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemotePortfolioSummaryResponse.self, from: data)
    }

    func portfolioCommits(assetID: String) async throws -> RemotePortfolioCommitsResponse {
        let data = try await request(path: "/v1/portfolio/assets/\(assetID)/commits", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemotePortfolioCommitsResponse.self, from: data)
    }

    func portfolioControl(assetID: String, action: String) async throws -> RemotePortfolioControlResponse {
        let body = try JSONEncoder.commandCenter.encode(["action": action])
        let data = try await request(path: "/v1/portfolio/assets/\(assetID)/control", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemotePortfolioControlResponse.self, from: data)
    }

    func portfolioPromote(assetID: String) async throws -> RemotePortfolioPromoteResponse {
        let data = try await request(path: "/v1/portfolio/assets/\(assetID)/promote", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(RemotePortfolioPromoteResponse.self, from: data)
    }

    func salesLeads() async throws -> RemoteSalesLeadListResponse {
        let data = try await request(path: "/v1/sales/leads", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteSalesLeadListResponse.self, from: data)
    }

    func saveSalesLead(_ lead: SalesLead) async throws -> SalesLead {
        struct Body: Encodable {
            var lead: SalesLead
        }
        let body = try JSONEncoder.commandCenter.encode(Body(lead: lead))
        let data = try await request(path: "/v1/sales/leads/\(lead.id)", method: "PATCH", body: body)
        return try JSONDecoder.commandCenter.decode(SalesLead.self, from: data)
    }

    func importSalesCSV(_ csv: String) async throws -> RemoteSalesCSVImportResponse {
        let body = try JSONEncoder.commandCenter.encode(["csv": csv])
        let data = try await request(path: "/v1/sales/leads/import-csv", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteSalesCSVImportResponse.self, from: data)
    }

    func auditSalesLead(id: String) async throws -> WebsiteAudit {
        let data = try await request(path: "/v1/sales/leads/\(id)/audit", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(WebsiteAudit.self, from: data)
    }

    func generateSalesRedesign(id: String) async throws -> RedesignMock {
        let data = try await request(path: "/v1/sales/leads/\(id)/generate-mock", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(RedesignMock.self, from: data)
    }

    func generateSalesProposal(id: String) async throws -> Proposal {
        let data = try await request(path: "/v1/sales/leads/\(id)/generate-proposal", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(Proposal.self, from: data)
    }

    func approveSalesProposal(id: String) async throws -> Proposal {
        let data = try await request(path: "/v1/sales/leads/\(id)/approve-proposal", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(Proposal.self, from: data)
    }

    func markSalesLeadContacted(id: String, channel: String, note: String?) async throws -> SalesLead {
        struct Body: Encodable {
            var channel: String
            var note: String?
        }
        let body = try JSONEncoder.commandCenter.encode(Body(channel: channel, note: note))
        let data = try await request(path: "/v1/sales/leads/\(id)/mark-contacted", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(SalesLead.self, from: data)
    }

    func salesLeadAssets(id: String) async throws -> RemoteSalesLeadAssetsResponse {
        let data = try await request(path: "/v1/sales/leads/\(id)/assets", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteSalesLeadAssetsResponse.self, from: data)
    }

    func promoteSalesLeadToPortfolio(id: String) async throws -> RemoteSalesPortfolioPromotionResponse {
        let data = try await request(path: "/v1/sales/leads/\(id)/promote-to-portfolio", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteSalesPortfolioPromotionResponse.self, from: data)
    }

    func createSalesHermesHandoff(id: String) async throws -> RemoteSalesHermesHandoffResponse {
        let data = try await request(path: "/v1/sales/leads/\(id)/create-hermes-handoff", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteSalesHermesHandoffResponse.self, from: data)
    }

    func memoryList() async throws -> RemoteMemoryListResponse {
        let data = try await request(path: "/v1/memory", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteMemoryListResponse.self, from: data)
    }

    func readMemory(id: String) async throws -> RemoteMemoryContentResponse {
        let body = try JSONEncoder.commandCenter.encode(["id": id])
        let data = try await request(path: "/v1/memory/read", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteMemoryContentResponse.self, from: data)
    }

    func projectMemory(_ requestBody: RemoteProjectMemoryRequest) async throws -> RemoteProjectMemoryResponse {
        let body = try JSONEncoder.commandCenter.encode(requestBody)
        let data = try await request(path: "/v1/memory/project", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteProjectMemoryResponse.self, from: data)
    }

    func diffMemory(id: String, content: String) async throws -> RemoteMemoryDiffResponse {
        let body = try JSONEncoder.commandCenter.encode(["id": id, "content": content])
        let data = try await request(path: "/v1/memory/diff", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteMemoryDiffResponse.self, from: data)
    }

    func writeMemory(id: String, content: String) async throws -> RemoteMemoryWriteResponse {
        let body = try JSONEncoder.commandCenter.encode(["id": id, "content": content])
        let data = try await request(path: "/v1/memory/write", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteMemoryWriteResponse.self, from: data)
    }

    func historySessions(
        tool: RemoteHistoryTool?,
        project: String?,
        query: String?,
        date: String?,
        page: Int,
        limit: Int
    ) async throws -> RemoteHistoryListResponse {
        struct Body: Encodable {
            var tool: RemoteHistoryTool?
            var project: String?
            var query: String?
            var date: String?
            var page: Int?
            var limit: Int?
        }
        let body = try JSONEncoder.commandCenter.encode(Body(
            tool: tool,
            project: project?.isEmpty == true ? nil : project,
            query: query?.isEmpty == true ? nil : query,
            date: date?.isEmpty == true ? nil : date,
            page: page,
            limit: limit
        ))
        let data = try await request(path: "/v1/history/sessions", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteHistoryListResponse.self, from: data)
    }

    func historyDetail(id: String, tool: RemoteHistoryTool) async throws -> RemoteHistoryDetailResponse {
        struct Body: Encodable {
            var id: String
            var tool: RemoteHistoryTool
        }
        let body = try JSONEncoder.commandCenter.encode(Body(id: id, tool: tool))
        let data = try await request(path: "/v1/history/session", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteHistoryDetailResponse.self, from: data)
    }

    func stream(remoteRunID: String) -> AsyncThrowingStream<RemoteHostLogEvent, Error> {
        AsyncThrowingStream { continuation in
            guard let baseURL = URL(string: configuration.endpoint) else {
                continuation.finish(throwing: RemoteHostError.invalidConfiguration)
                return
            }
            let path = "/v1/runs/\(remoteRunID)/events"
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
            components?.path = path
            guard let url = components?.url else {
                continuation.finish(throwing: RemoteHostError.invalidConfiguration)
                return
            }
            var request = URLRequest(url: url)
            sign(&request, method: "GET", path: path, body: Data())
            let task = URLSession.shared.webSocketTask(with: request)
            task.resume()

            let receiveTask = Task {
                do {
                    while !Task.isCancelled {
                        let message = try await task.receive()
                        let data: Data
                        switch message {
                        case .data(let payload):
                            data = payload
                        case .string(let text):
                            data = Data(text.utf8)
                        @unknown default:
                            continue
                        }
                        let event = try JSONDecoder.commandCenter.decode(RemoteHostLogEvent.self, from: data)
                        continuation.yield(event)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                receiveTask.cancel()
                task.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    private func request(path: String, method: String, body: Data) async throws -> Data {
        guard let url = URL(string: path, relativeTo: URL(string: configuration.endpoint)) else {
            throw RemoteHostError.invalidConfiguration
        }
        var request = URLRequest(url: url.absoluteURL)
        request.httpMethod = method
        request.httpBody = body.isEmpty ? nil : body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        sign(&request, method: method, path: path, body: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteHostError.server("Invalid response")
        }
        if http.statusCode == 409 {
            let message = (try? JSONDecoder.commandCenter.decode([String: String].self, from: data)["error"]) ?? "Remote approval required"
            throw RemoteHostError.approvalRequired(message)
        }
        if [401, 403].contains(http.statusCode) {
            let message = (try? JSONDecoder.commandCenter.decode([String: String].self, from: data)["error"]) ?? "Unauthorized"
            throw RemoteHostError.authentication(message)
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder.commandCenter.decode([String: String].self, from: data)["error"]) ?? "HTTP \(http.statusCode)"
            throw RemoteHostError.server(message)
        }
        return data
    }

    private func sign(_ request: inout URLRequest, method: String, path: String, body: Data) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        request.setValue(configuration.deviceID, forHTTPHeaderField: "X-Veqral-Device")
        request.setValue(timestamp, forHTTPHeaderField: "X-Veqral-Timestamp")
        request.setValue(
            RemoteHostSigner.signature(
                token: configuration.token,
                method: method,
                path: path,
                timestamp: timestamp,
                body: body
            ),
            forHTTPHeaderField: "X-Veqral-Signature"
        )
    }
}
