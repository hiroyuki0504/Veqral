import AppKit
import CryptoKit
import Foundation
import Network
import Security
import Darwin

private let serviceName = "dev.hiroyuki.veqral.host"
private let serverGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

@main
final class VeqralHostApp: NSObject, NSApplicationDelegate {
    private var statusController: StatusController?
    private var server: HostServer?
    private let state = HostState()

    static func main() {
        // LaunchAgents can inherit an invalid working directory; normalize before Foundation spawns helper processes.
        _ = Darwin.chdir("/")
        let app = NSApplication.shared
        let delegate = VeqralHostApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = HostConfig.load()
        let state = HostState(config: config)
        self.statusController = StatusController(state: state)
        do {
            let server = try HostServer(config: config, state: state)
            self.server = server
            try server.start()
            statusController?.setStatus("Listening on \(config.port)")
        } catch {
            statusController?.setStatus("Failed: \(error.localizedDescription)")
        }
    }
}

struct HostConfig: Codable, Sendable {
    var port: UInt16 = 7878
    var defaultWorkingDirectory: String = NSHomeDirectory()
    var maxRunsPerDay: Int = 20
    var maxRunsPerProjectPerDay: Int = 8
    var maxActiveRuns: Int = 2
    var logRetentionDays: Int = 30
    var auditRetentionDays: Int = 90

    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".veqral-host", isDirectory: true)
    }

    static var configURL: URL {
        folder.appendingPathComponent("config.json")
    }

    static func load() -> HostConfig {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: configURL),
           let config = try? JSONDecoder().decode(HostConfig.self, from: data) {
            return config
        }
        let config = HostConfig()
        if let data = try? JSONEncoder.pretty.encode(config) {
            try? data.write(to: configURL, options: .atomic)
        }
        return config
    }
}

struct DeviceRecord: Codable, Sendable, Identifiable {
    var id: String
    var name: String
    var pairedAt: Date
    var lastSeenAt: Date?
}

enum RunStatusWire: String, Codable, Sendable {
    case queued
    case running
    case waitingApproval
    case cancelled
    case failed
    case complete
    case needsAttention
}

enum AgentEngine: String, Codable, Sendable, CaseIterable {
    case hermes
    case codex
    case claude

    var title: String {
        switch self {
        case .hermes:
            "Hermes"
        case .codex:
            "Codex"
        case .claude:
            "Claude"
        }
    }
}

struct HostRun: Codable, Sendable, Identifiable {
    var id: String
    var prompt: String
    var workingDirectory: String
    var sessionID: String?
    var status: RunStatusWire
    var startedAt: Date
    var completedAt: Date?
    var exitCode: Int32?
    var pid: Int32?
    var approvalReason: String?
    var engine: AgentEngine?
    var resumeSessionID: String?
    var projectID: String?
    var chatID: String?
    var provider: String?
    var model: String?

    var engineOrDefault: AgentEngine {
        engine ?? .hermes
    }
}

struct HostLogEvent: Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case log
        case status
        case approval
        case complete
        case error
    }

    var runID: String
    var kind: Kind
    var stream: String
    var message: String
    var createdAt: Date
    var sessionID: String?
    var exitCode: Int32?
}

actor HostState {
    private var config: HostConfig
    private var runs: [String: HostRun] = [:]
    private var logs: [String: [HostLogEvent]] = [:]
    private var subscribers: [String: [UUID: @Sendable (HostLogEvent) -> Void]] = [:]
    private var processes: [String: pid_t] = [:]
    private var devices: [DeviceRecord] = []
    private var pairingCode: String = String(UUID().uuidString.prefix(8)).uppercased()

    init(config: HostConfig = HostConfig.load()) {
        self.config = config
        self.runs = Self.loadRuns()
        self.logs = Self.loadLogs(for: Array(self.runs.keys))
        self.devices = Self.loadDevices()
    }

    nonisolated static var devicesURL: URL {
        HostConfig.folder.appendingPathComponent("devices.json")
    }

    nonisolated static var auditURL: URL {
        HostConfig.folder.appendingPathComponent("audit.log")
    }

    nonisolated static var runsURL: URL {
        HostConfig.folder.appendingPathComponent("runs.json")
    }

    nonisolated static var logsFolder: URL {
        HostConfig.folder.appendingPathComponent("logs", isDirectory: true)
    }

    func currentPairingCode() -> String {
        pairingCode
    }

    func rotatePairingCode() -> String {
        pairingCode = String(UUID().uuidString.prefix(8)).uppercased()
        return pairingCode
    }

    func pairingURL() -> String {
        let endpoint = "http://\(tailscaleIP() ?? localHostName()):\(config.port)"
        return "veqral://pair?endpoint=\(endpoint.urlQueryEscaped)&code=\(pairingCode)"
    }

    func pair(deviceName: String, code: String) throws -> (deviceID: String, token: String) {
        guard code == pairingCode else {
            throw HostError.unauthorized("Invalid pairing code")
        }
        let deviceID = UUID().uuidString
        let token = randomToken()
        try KeychainStore.set(token, account: "device:\(deviceID)")
        devices.append(DeviceRecord(id: deviceID, name: deviceName, pairedAt: Date(), lastSeenAt: Date()))
        persistDevices()
        _ = rotatePairingCode()
        appendAudit("paired device=\(deviceName) id=\(deviceID)")
        return (deviceID, token)
    }

    func validate(deviceID: String, method: String, path: String, timestamp: String, signature: String, body: Data) throws {
        guard let token = KeychainStore.get(account: "device:\(deviceID)") else {
            throw HostError.unauthorized("Unknown device")
        }
        guard let signedAt = ISO8601DateFormatter().date(from: timestamp),
              abs(signedAt.timeIntervalSinceNow) < 300 else {
            throw HostError.unauthorized("Expired signature")
        }
        let expected = HMACSigner.signature(token: token, method: method, path: path, timestamp: timestamp, body: body)
        guard secureCompare(signature, expected) else {
            throw HostError.unauthorized("Invalid signature")
        }
        if let index = devices.firstIndex(where: { $0.id == deviceID }) {
            devices[index].lastSeenAt = Date()
            persistDevices()
        }
    }

    func revoke(deviceID: String) {
        KeychainStore.delete(account: "device:\(deviceID)")
        devices.removeAll { $0.id == deviceID }
        persistDevices()
        appendAudit("revoked device id=\(deviceID)")
    }

    func devicesList() -> [DeviceRecord] {
        devices
    }

    func runsList() -> [HostRun] {
        runs.values.sorted { $0.startedAt > $1.startedAt }
    }

    func recordAudit(_ line: String) {
        appendAudit(line)
    }

    func auditLines(limit: Int = 200) -> [String] {
        guard let text = try? String(contentsOf: Self.auditURL, encoding: .utf8) else {
            return []
        }
        return Array(text.split(whereSeparator: \.isNewline).suffix(limit)).map(String.init)
    }

    func recoverableRunIDs() -> [String] {
        runs.values
            .filter { $0.status == .queued }
            .sorted { $0.startedAt < $1.startedAt }
            .map(\.id)
    }

    func budgetAllows(project: String) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let dailyRuns = runs.values.filter { $0.startedAt >= today }.count
        let projectRuns = runs.values.filter { $0.startedAt >= today && $0.workingDirectory == project }.count
        let activeRuns = runs.values.filter { $0.status == .running || $0.status == .queued }.count
        return dailyRuns < config.maxRunsPerDay
            && projectRuns < config.maxRunsPerProjectPerDay
            && activeRuns < config.maxActiveRuns
    }

    func createRun(
        prompt: String,
        workingDirectory: String,
        engine: AgentEngine = .hermes,
        resumeSessionID: String? = nil,
        projectID: String? = nil,
        chatID: String? = nil,
        provider: String? = nil,
        model: String? = nil,
        attachments: [RunAttachmentUpload] = []
    ) throws -> HostRun {
        let directory = (workingDirectory.isEmpty ? config.defaultWorkingDirectory : workingDirectory).expandingTilde
        guard FileManager.default.fileExists(atPath: directory) else {
            throw HostError.badRequest("Working directory does not exist")
        }
        let risk = RiskClassifier.classify(prompt)
        let approvalReason: String? = if !budgetAllows(project: directory) {
            "Budget guard exceeded"
        } else if risk.requiresApproval {
            risk.reason
        } else {
            nil
        }
        var run = HostRun(
            id: UUID().uuidString,
            prompt: prompt,
            workingDirectory: directory,
            sessionID: nil,
            status: approvalReason == nil ? .queued : .waitingApproval,
            startedAt: Date(),
            completedAt: nil,
            exitCode: nil,
            pid: nil,
            approvalReason: approvalReason,
            engine: engine,
            resumeSessionID: resumeSessionID?.nilIfBlank,
            projectID: projectID?.nilIfBlank,
            chatID: chatID?.nilIfBlank,
            provider: provider?.nilIfBlank,
            model: model?.nilIfBlank
        )
        let savedAttachments = try AttachmentStore.save(attachments, runID: run.id)
        if !savedAttachments.isEmpty {
            run.prompt += "\n\nAttached files from Veqral iOS:\n"
            run.prompt += savedAttachments.map { "- \($0.title): \($0.path)" }.joined(separator: "\n")
            appendAudit("saved attachments run id=\(run.id) count=\(savedAttachments.count)")
        }
        runs[run.id] = run
        persistRuns()
        if let approvalReason {
            appendAudit("created approval run id=\(run.id) engine=\(engine.rawValue) dir=\(directory) reason=\(approvalReason)")
            publish(HostLogEvent(runID: run.id, kind: .approval, stream: "approval", message: approvalReason, createdAt: Date()))
        } else {
            appendAudit("created run id=\(run.id) engine=\(engine.rawValue) dir=\(directory)")
        }
        return run
    }

    func markStarted(runID: String, pid: pid_t) {
        guard var run = runs[runID] else { return }
        run.status = .running
        run.pid = pid
        runs[runID] = run
        processes[runID] = pid
        persistRuns()
        publish(HostLogEvent(runID: runID, kind: .status, stream: "host", message: "Run started pid=\(pid)", createdAt: Date()))
    }

    func appendLog(runID: String, stream: String, message: String) {
        let redacted = Redactor.redact(message)
        if let sessionID = SessionParser.sessionID(from: redacted), var run = runs[runID] {
            run.sessionID = sessionID
            runs[runID] = run
            persistRuns()
        }
        publish(HostLogEvent(runID: runID, kind: .log, stream: stream, message: redacted, createdAt: Date(), sessionID: runs[runID]?.sessionID))
    }

    func finish(runID: String, exitCode: Int32) {
        guard var run = runs[runID] else { return }
        guard run.status != .cancelled else { return }
        run.status = exitCode == 0 ? .complete : .failed
        run.exitCode = exitCode
        run.completedAt = Date()
        run.pid = nil
        runs[runID] = run
        processes[runID] = nil
        persistRuns()
        appendAudit("finished run id=\(runID) exit=\(exitCode)")
        publish(HostLogEvent(runID: runID, kind: .complete, stream: "host", message: "Exit code: \(exitCode)", createdAt: Date(), sessionID: run.sessionID, exitCode: exitCode))
    }

    func cancel(runID: String) {
        guard var run = runs[runID] else { return }
        guard ![RunStatusWire.complete, .failed, .cancelled].contains(run.status) else { return }
        if let pid = processes[runID] {
            kill(pid, SIGTERM)
            usleep(200_000)
            kill(pid, SIGKILL)
        }
        run.status = .cancelled
        run.completedAt = Date()
        run.pid = nil
        runs[runID] = run
        processes[runID] = nil
        persistRuns()
        appendAudit("cancelled run id=\(runID)")
        publish(HostLogEvent(runID: runID, kind: .status, stream: "host", message: "Run cancelled", createdAt: Date()))
    }

    func resume(runID: String) throws -> HostRun {
        guard var run = runs[runID] else {
            throw HostError.notFound("Run not found")
        }
        guard run.status != .running else {
            return run
        }
        run.status = .queued
        run.completedAt = nil
        run.exitCode = nil
        runs[runID] = run
        persistRuns()
        appendAudit("resume requested run id=\(runID)")
        return run
    }

    func approve(runID: String) throws -> HostRun {
        guard var run = runs[runID] else {
            throw HostError.notFound("Run not found")
        }
        guard run.status == .waitingApproval else {
            return run
        }
        run.status = .queued
        run.approvalReason = nil
        runs[runID] = run
        persistRuns()
        appendAudit("approved run id=\(runID)")
        publish(HostLogEvent(runID: runID, kind: .status, stream: "host", message: "Approval accepted", createdAt: Date(), sessionID: run.sessionID))
        return run
    }

    func run(runID: String) -> HostRun? {
        runs[runID]
    }

    func replayLogs(runID: String) -> [HostLogEvent] {
        logs[runID] ?? []
    }

    func subscribe(runID: String, handler: @escaping @Sendable (HostLogEvent) -> Void) -> UUID {
        let id = UUID()
        subscribers[runID, default: [:]][id] = handler
        for event in logs[runID] ?? [] {
            handler(event)
        }
        return id
    }

    func unsubscribe(runID: String, id: UUID) {
        subscribers[runID]?[id] = nil
    }

    private func publish(_ event: HostLogEvent) {
        logs[event.runID, default: []].append(event)
        appendLogFile(event)
        subscribers[event.runID]?.values.forEach { $0(event) }
    }

    private func appendAudit(_ line: String) {
        let entry = "\(ISO8601DateFormatter().string(from: Date())) \(line)\n"
        try? FileManager.default.createDirectory(at: HostConfig.folder, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: Self.auditURL.path),
           let handle = try? FileHandle(forWritingTo: Self.auditURL) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(entry.utf8))
            try? handle.close()
        } else {
            try? Data(entry.utf8).write(to: Self.auditURL, options: .atomic)
        }
    }

    private func persistDevices() {
        if let data = try? JSONEncoder.pretty.encode(devices) {
            try? data.write(to: Self.devicesURL, options: .atomic)
        }
    }

    private func persistRuns() {
        try? FileManager.default.createDirectory(at: HostConfig.folder, withIntermediateDirectories: true)
        let sortedRuns = runs.values.sorted { $0.startedAt < $1.startedAt }
        if let data = try? JSONEncoder.pretty.encode(sortedRuns) {
            try? data.write(to: Self.runsURL, options: .atomic)
        }
    }

    private func appendLogFile(_ event: HostLogEvent) {
        try? FileManager.default.createDirectory(at: Self.logsFolder, withIntermediateDirectories: true)
        let url = Self.logsFolder.appendingPathComponent("\(event.runID).jsonl")
        guard let data = try? JSONEncoder.dates.encode(event) else { return }
        var line = data
        line.append(0x0A)
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
            try? handle.close()
        } else {
            try? line.write(to: url, options: .atomic)
        }
    }

    private static func loadDevices() -> [DeviceRecord] {
        guard let data = try? Data(contentsOf: devicesURL),
              let devices = try? JSONDecoder.dates.decode([DeviceRecord].self, from: data) else {
            return []
        }
        return devices
    }

    private static func loadRuns() -> [String: HostRun] {
        guard let data = try? Data(contentsOf: runsURL),
              let storedRuns = try? JSONDecoder.dates.decode([HostRun].self, from: data) else {
            return [:]
        }
        return Dictionary(
            uniqueKeysWithValues: storedRuns.map { storedRun in
                var run = storedRun
                if run.status == .running || run.status == .queued {
                    run.status = .queued
                    run.pid = nil
                    run.completedAt = nil
                }
                return (run.id, run)
            }
        )
    }

    private static func loadLogs(for runIDs: [String]) -> [String: [HostLogEvent]] {
        var loaded: [String: [HostLogEvent]] = [:]
        for runID in runIDs {
            let url = logsFolder.appendingPathComponent("\(runID).jsonl")
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            loaded[runID] = text
                .split(whereSeparator: \.isNewline)
                .compactMap { line in
                    try? JSONDecoder.dates.decode(HostLogEvent.self, from: Data(String(line).utf8))
                }
        }
        return loaded
    }
}

final class HostServer: @unchecked Sendable {
    private let config: HostConfig
    private let state: HostState
    private let listener: NWListener
    private let runner: AgentRunner
    private let memoryStore = HermesMemoryStore()
    private let historyStore = AgentHistoryStore()
    private let connectionLock = NSLock()
    private var activeConnections: [ObjectIdentifier: NWConnection] = [:]

    init(config: HostConfig, state: HostState) throws {
        self.config = config
        self.state = state
        self.listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: config.port)!)
        self.runner = AgentRunner(state: state)
    }

    func start() throws {
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: .global(qos: .userInitiated))
        Task {
            let recoverable = await state.recoverableRunIDs()
            for runID in recoverable {
                await runner.start(runID: runID)
            }
        }
    }

    private func handle(_ connection: NWConnection) {
        retain(connection)
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let connection else { return }
            if case .cancelled = state {
                self?.release(connection)
            }
            if case .failed = state {
                self?.release(connection)
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
        readRequest(connection: connection, buffer: Data())
    }

    private func retain(_ connection: NWConnection) {
        connectionLock.lock()
        activeConnections[ObjectIdentifier(connection)] = connection
        connectionLock.unlock()
    }

    private func release(_ connection: NWConnection) {
        connectionLock.lock()
        activeConnections[ObjectIdentifier(connection)] = nil
        connectionLock.unlock()
    }

    private func readRequest(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                var next = buffer
                next.append(data)
                if let request = HTTPRequest.parse(next) {
                    Task { await self.route(request, connection: connection) }
                } else {
                    self.readRequest(connection: connection, buffer: next)
                }
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                self.readRequest(connection: connection, buffer: buffer)
            }
        }
    }

    private func route(_ request: HTTPRequest, connection: NWConnection) async {
        do {
            if request.path == "/v1/health" {
                let toolStatuses = CLIAdapterRegistry.allStatuses()
                let response = HealthResponse(
                    status: "ok",
                    host: localHostName(),
                    tailscaleIP: tailscaleIP(),
                    port: config.port,
                    hermesVersion: toolStatuses.first { $0.engine == AgentEngine.hermes.rawValue }?.version ?? AgentRunner.hermesVersion(),
                    toolStatuses: toolStatuses
                )
                sendJSON(response, connection: connection)
                return
            }

            if request.path == "/v1/pair", request.method == "POST" {
                let body = try JSONDecoder.dates.decode(PairRequest.self, from: request.body)
                let result = try await state.pair(deviceName: body.deviceName, code: body.pairingCode)
                sendJSON(PairResponse(deviceID: result.deviceID, token: result.token), connection: connection)
                return
            }

            if request.path == "/v1/pairing", request.method == "GET" {
                let url = await state.pairingURL()
                let code = await state.currentPairingCode()
                sendJSON(PairingStatus(pairingCode: code, pairingURL: url), connection: connection)
                return
            }

            try await authenticate(request)

            if request.path == "/v1/setup/unattended/status", request.method == "GET" {
                sendJSON(UnattendedSetupManager.status(), connection: connection)
                return
            }

            if request.path == "/v1/setup/unattended/apply", request.method == "POST" {
                let body = try JSONDecoder.dates.decode(UnattendedApplyRequest.self, from: request.body)
                let result = try UnattendedSetupManager.apply(
                    loginPassword: body.loginPassword,
                    allowSkipAutologin: body.allowSkipAutologin
                )
                await state.recordAudit("unattended setup applied autologinSkipped=\(result.autologinSkipped)")
                sendJSON(result, connection: connection)
                return
            }

            if request.path == "/v1/setup/unattended/revert", request.method == "POST" {
                let result = try UnattendedSetupManager.revert()
                await state.recordAudit("unattended setup reverted")
                sendJSON(result, connection: connection)
                return
            }

            if request.path == "/v1/memory", request.method == "GET" {
                sendJSON(try memoryStore.list(), connection: connection)
                return
            }

            if request.path == "/v1/memory/read", request.method == "POST" {
                let body = try JSONDecoder.dates.decode(MemoryFileRequest.self, from: request.body)
                sendJSON(try memoryStore.read(id: body.id), connection: connection)
                return
            }

            if request.path == "/v1/memory/diff", request.method == "POST" {
                let body = try JSONDecoder.dates.decode(MemoryWriteRequest.self, from: request.body)
                sendJSON(try memoryStore.diff(id: body.id, proposedContent: body.content), connection: connection)
                return
            }

            if request.path == "/v1/memory/write", request.method == "POST" {
                let body = try JSONDecoder.dates.decode(MemoryWriteRequest.self, from: request.body)
                let response = try memoryStore.write(id: body.id, content: body.content)
                await state.recordAudit("memory wrote id=\(body.id) bytes=\(body.content.utf8.count)")
                sendJSON(response, connection: connection)
                return
            }

            if request.path == "/v1/devices", request.method == "GET" {
                sendJSON(DeviceListResponse(devices: await state.devicesList()), connection: connection)
                return
            }

            if request.path.hasPrefix("/v1/devices/"), request.path.hasSuffix("/revoke"), request.method == "POST" {
                let parts = request.path.split(separator: "/").map(String.init)
                guard parts.count == 4 else { throw HostError.notFound("Invalid device path") }
                await state.revoke(deviceID: parts[2])
                sendJSON(SimpleResponse(ok: true), connection: connection)
                return
            }

            if request.path == "/v1/audit", request.method == "GET" {
                sendJSON(AuditLogResponse(lines: await state.auditLines()), connection: connection)
                return
            }

            if request.path == "/v1/history/sessions", request.method == "POST" {
                let body = try JSONDecoder.dates.decode(HistorySessionListRequest.self, from: request.body)
                sendJSON(try historyStore.list(body), connection: connection)
                return
            }

            if request.path == "/v1/history/session", request.method == "POST" {
                let body = try JSONDecoder.dates.decode(HistorySessionDetailRequest.self, from: request.body)
                sendJSON(try historyStore.detail(body), connection: connection)
                return
            }

            if request.path == "/v1/github/status", request.method == "POST" {
                let body = try JSONDecoder.dates.decode(GitHubStatusRequest.self, from: request.body)
                sendJSON(GitHubInspector.status(workingDirectory: body.workingDirectory), connection: connection)
                return
            }

            if request.path == "/v1/github/draft-pr", request.method == "POST" {
                let body = try JSONDecoder.dates.decode(CreateDraftPRRequest.self, from: request.body)
                let response = try GitHubInspector.createDraftPR(
                    workingDirectory: body.workingDirectory,
                    title: body.title,
                    body: body.body
                )
                await state.recordAudit("github draft-pr url=\(response.url)")
                sendJSON(response, connection: connection)
                return
            }

            if request.headers["upgrade"]?.lowercased() == "websocket",
               request.path.hasPrefix("/v1/runs/"),
               request.path.hasSuffix("/events") {
                await state.recordAudit("websocket upgrade path=\(request.path)")
                try await upgradeToWebSocket(request, connection: connection)
                return
            }

            if request.path == "/v1/runs", request.method == "GET" {
                sendJSON(RunListResponse(runs: await state.runsList()), connection: connection)
                return
            }

            if request.path == "/v1/runs", request.method == "POST" {
                let body = try JSONDecoder.dates.decode(CreateRunRequest.self, from: request.body)
                let run = try await state.createRun(
                    prompt: body.prompt,
                    workingDirectory: body.workingDirectory,
                    engine: body.engine ?? .hermes,
                    resumeSessionID: body.resumeSessionID,
                    projectID: body.projectID,
                    chatID: body.chatID,
                    provider: body.provider,
                    model: body.model,
                    attachments: body.attachments ?? []
                )
                sendJSON(
                    CreateRunResponse(
                        runID: run.id,
                        sessionID: run.sessionID,
                        status: run.status.rawValue,
                        approvalRequired: run.status == .waitingApproval,
                        approvalReason: run.approvalReason
                    ),
                    connection: connection
                )
                if run.status != .waitingApproval {
                    Task { await runner.start(runID: run.id) }
                }
                return
            }

            if request.path.hasPrefix("/v1/runs/") {
                let parts = request.path.split(separator: "/").map(String.init)
                guard parts.count >= 3 else { throw HostError.notFound("Invalid run path") }
                let runID = parts[2]
                if request.method == "GET", parts.count == 3 {
                    guard let run = await state.run(runID: runID) else { throw HostError.notFound("Run not found") }
                    sendJSON(
                        RunSnapshotResponse(
                            run: run,
                            logs: await state.replayLogs(runID: runID),
                            diff: GitDiffInspector.entries(workingDirectory: run.workingDirectory),
                            artifacts: ArtifactScanner.artifacts(for: run)
                        ),
                        connection: connection
                    )
                    return
                }
                guard parts.count >= 4 else { throw HostError.notFound("Invalid run path") }
                let action = parts[3]
                switch (request.method, action) {
                case ("GET", "logs"):
                    sendJSON(RunLogResponse(logs: await state.replayLogs(runID: runID)), connection: connection)
                case ("GET", "diff"):
                    guard let run = await state.run(runID: runID) else { throw HostError.notFound("Run not found") }
                    sendJSON(GitDiffResponse(files: GitDiffInspector.entries(workingDirectory: run.workingDirectory)), connection: connection)
                case ("GET", "artifacts"):
                    guard let run = await state.run(runID: runID) else { throw HostError.notFound("Run not found") }
                    sendJSON(ArtifactListResponse(artifacts: ArtifactScanner.artifacts(for: run)), connection: connection)
                case ("POST", "cancel"):
                    await state.cancel(runID: runID)
                    sendJSON(SimpleResponse(ok: true), connection: connection)
                case ("POST", "resume"):
                    _ = try await state.resume(runID: runID)
                    sendJSON(SimpleResponse(ok: true), connection: connection)
                    Task { await runner.start(runID: runID) }
                case ("POST", "approve"):
                    _ = try await state.approve(runID: runID)
                    sendJSON(SimpleResponse(ok: true), connection: connection)
                    Task { await runner.start(runID: runID) }
                case ("POST", "reject"):
                    await state.cancel(runID: runID)
                    sendJSON(SimpleResponse(ok: true), connection: connection)
                default:
                    throw HostError.notFound("Unknown run action")
                }
                return
            }

            throw HostError.notFound("Not found")
        } catch {
            sendError(error, connection: connection)
        }
    }

    private func authenticate(_ request: HTTPRequest) async throws {
        guard let device = request.headers["x-veqral-device"],
              let timestamp = request.headers["x-veqral-timestamp"],
              let signature = request.headers["x-veqral-signature"] else {
            throw HostError.unauthorized("Missing Veqral auth headers")
        }
        try await state.validate(
            deviceID: device,
            method: request.method,
            path: request.path,
            timestamp: timestamp,
            signature: signature,
            body: request.body
        )
    }

    private func upgradeToWebSocket(_ request: HTTPRequest, connection: NWConnection) async throws {
        guard let key = request.headers["sec-websocket-key"] else {
            throw HostError.badRequest("Missing websocket key")
        }
        let runID = request.path
            .replacingOccurrences(of: "/v1/runs/", with: "")
            .replacingOccurrences(of: "/events", with: "")
        let accept = websocketAccept(key)
        let response = [
            "HTTP/1.1 101 Switching Protocols",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Accept: \(accept)",
            "",
            ""
        ].joined(separator: "\r\n")
        connection.send(content: Data(response.utf8), contentContext: .defaultStream, isComplete: false, completion: .contentProcessed { error in
            if error != nil {
                connection.cancel()
            }
        })
        let subscription = await state.subscribe(runID: runID) { event in
            guard let data = try? JSONEncoder.dates.encode(event) else { return }
            WebSocketFrame.sendText(String(data: data, encoding: .utf8) ?? "{}", connection: connection)
        }
        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state {
                Task { await self?.state.unsubscribe(runID: runID, id: subscription) }
                self?.release(connection)
            }
            if case .failed = state {
                Task { await self?.state.unsubscribe(runID: runID, id: subscription) }
                self?.release(connection)
            }
        }
    }

    private func sendJSON<T: Encodable>(_ value: T, connection: NWConnection) {
        let data = (try? JSONEncoder.dates.encode(value)) ?? Data("{}".utf8)
        sendResponse(status: "200 OK", body: data, connection: connection)
    }

    private func sendError(_ error: Error, connection: NWConnection) {
        let status: String
        if let hostError = error as? HostError {
            status = hostError.httpStatus
        } else {
            status = "500 Internal Server Error"
        }
        let body = (try? JSONEncoder().encode(ErrorResponse(error: String(describing: error)))) ?? Data()
        sendResponse(status: status, body: body, connection: connection)
    }

    private func sendResponse(status: String, body: Data, connection: NWConnection) {
        let header = [
            "HTTP/1.1 \(status)",
            "Content-Type: application/json",
            "Content-Length: \(body.count)",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")
        var payload = Data(header.utf8)
        payload.append(body)
        connection.send(content: payload, contentContext: .defaultStream, isComplete: true, completion: .contentProcessed { [weak self] _ in
            connection.cancel()
            self?.release(connection)
        })
    }
}

struct CLIToolStatus: Codable, Sendable, Equatable {
    var engine: String
    var title: String
    var executablePath: String?
    var version: String
    var adapter: String
    var commandShape: String
    var isInstalled: Bool
    var isKnownCompatible: Bool
    var compatibilityNote: String

    var versionSummary: String {
        version.split(whereSeparator: \.isNewline).first.map(String.init) ?? version
    }
}

struct CLIExecutionPlan: Sendable {
    var executable: String
    var arguments: [String]
    var toolStatus: CLIToolStatus
}

enum CLIAdapterRegistry {
    static func allStatuses() -> [CLIToolStatus] {
        AgentEngine.allCases.map { status(for: $0) }
    }

    static func status(for engine: AgentEngine) -> CLIToolStatus {
        let path = executablePath(for: engine)
        let version = path.map { detectVersion(executable: $0) } ?? "Not installed"
        let compatibility = compatibility(for: engine, version: version, installed: path != nil)
        return CLIToolStatus(
            engine: engine.rawValue,
            title: engine.title,
            executablePath: path,
            version: version,
            adapter: adapterName(for: engine),
            commandShape: commandShape(for: engine),
            isInstalled: path != nil,
            isKnownCompatible: compatibility.known,
            compatibilityNote: compatibility.note
        )
    }

    static func plan(for run: HostRun) -> CLIExecutionPlan? {
        let toolStatus = status(for: run.engineOrDefault)
        guard let executable = toolStatus.executablePath else {
            return nil
        }
        return CLIExecutionPlan(
            executable: executable,
            arguments: arguments(for: run),
            toolStatus: toolStatus
        )
    }

    static func adapterDiagnostic(for tool: CLIToolStatus, output: String, exitCode: Int32) -> String? {
        guard exitCode != 0 else { return nil }
        let lower = output.lowercased()
        let flagFailureMarkers = [
            "unexpected argument",
            "unknown option",
            "unrecognized option",
            "unknown command",
            "invalid option",
            "no such option",
            "unrecognized arguments",
            "unrecognized subcommand",
            "unknown subcommand"
        ]
        guard flagFailureMarkers.contains(where: { lower.contains($0) }) else {
            return nil
        }
        return "\(tool.title) \(tool.versionSummary): CLI flags or subcommands were rejected for \(tool.commandShape). Update \(tool.adapter) in MacHost/Sources/VeqralHost/main.swift if the CLI changed."
    }

    static func hermesVersion() -> String {
        status(for: .hermes).version
    }

    private static func arguments(for run: HostRun) -> [String] {
        switch run.engineOrDefault {
        case .hermes:
            hermesArguments(for: run)
        case .codex:
            codexArguments(for: run)
        case .claude:
            claudeArguments(for: run)
        }
    }

    private static func hermesArguments(for run: HostRun) -> [String] {
        let source = "veqral-\(safeTag(run.projectID ?? projectName(for: run.workingDirectory)))"
        let modelLine = [run.provider, run.model].compactMap { $0?.nilIfBlank }.joined(separator: " / ")
        let prompt = """
        You are Hermes Agent running under Veqral Mac Host.
        Use Codex CLI and other configured CLI tools through Hermes when useful.
        Project scope: \(run.projectID ?? projectName(for: run.workingDirectory))
        Chat: \(run.chatID ?? "new")
        Model/provider selection: \(modelLine.isEmpty ? "Hermes configured default" : modelLine)
        Use Hermes native persistent memory, skills, checkpoints, and session history. Do not create a separate shared memory store for Veqral.
        Follow Veqral's P0 policy:
        - Use --worktree for repository work.
        - Auto-run implementation, tests, commits, branch creation, non-main push, and draft PR creation when appropriate.
        - Stop for deletion, main/force push, merge, production deploy, billing, secrets, tokens, .env, or Computer Use.
        - Keep logs concise but preserve actionable tool output.

        User request:
        \(run.prompt)
        """
        var args = [
            "chat",
            "-Q",
            "--source", source,
            "--checkpoints",
            "--worktree",
            "--pass-session-id",
            "--toolsets", "terminal,file,skills,memory,browser",
            "--max-turns", "40"
        ]
        if let provider = run.provider?.nilIfBlank {
            args.append(contentsOf: ["--provider", provider])
        }
        if let model = run.model?.nilIfBlank {
            args.append(contentsOf: ["--model", model])
        }
        if let sessionID = run.resumeSessionID?.nilIfBlank ?? run.sessionID?.nilIfBlank {
            args.append(contentsOf: ["--resume", sessionID])
        }
        args.append(contentsOf: ["-q", prompt])
        return args
    }

    private static func codexArguments(for run: HostRun) -> [String] {
        let prompt = directPrompt(for: run, engineName: "Codex")
        var args = [
            "exec",
            "--cd", run.workingDirectory,
            "--sandbox", "workspace-write"
        ]
        if let model = run.model?.nilIfBlank {
            args.append(contentsOf: ["--model", model])
        }
        if let resumeID = run.resumeSessionID?.nilIfBlank ?? run.sessionID?.nilIfBlank {
            args.append(contentsOf: ["resume", resumeID, prompt])
        } else {
            args.append(prompt)
        }
        return args
    }

    private static func claudeArguments(for run: HostRun) -> [String] {
        let prompt = directPrompt(for: run, engineName: "Claude")
        var args = [
            "--print",
            "--output-format", "stream-json",
            "--permission-mode", "auto"
        ]
        if let model = run.model?.nilIfBlank {
            args.append(contentsOf: ["--model", model])
        }
        if let resumeID = run.resumeSessionID?.nilIfBlank ?? run.sessionID?.nilIfBlank {
            args.append(contentsOf: ["--resume", resumeID])
        }
        args.append(prompt)
        return args
    }

    private static func directPrompt(for run: HostRun, engineName: String) -> String {
        """
        You are \(engineName) running directly from Veqral Mac Host.
        This is direct mode: use your own native session history and memory. Do not write to Hermes memory for this run.
        Follow Veqral safety: stop and explain before deletion, main/force push, merge, production deploy, billing, secrets, tokens, .env, or Computer Use.

        User request:
        \(run.prompt)
        """
    }

    private static func executablePath(for engine: AgentEngine) -> String? {
        switch engine {
        case .hermes:
            executablePath(
                named: "hermes",
                candidates: [
                    "\(NSHomeDirectory())/.local/bin/hermes",
                    "\(NSHomeDirectory())/.hermes/hermes-agent/venv/bin/hermes",
                    "/opt/homebrew/bin/hermes",
                    "/usr/local/bin/hermes"
                ]
            )
        case .codex:
            executablePath(
                named: "codex",
                candidates: [
                    "\(NSHomeDirectory())/.local/bin/codex",
                    "/opt/homebrew/bin/codex",
                    "/usr/local/bin/codex"
                ]
            )
        case .claude:
            executablePath(
                named: "claude",
                candidates: [
                    "\(NSHomeDirectory())/.local/bin/claude",
                    "/opt/homebrew/bin/claude",
                    "/usr/local/bin/claude"
                ]
            )
        }
    }

    private static func executablePath(named name: String, candidates: [String]) -> String? {
        if let candidate = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return candidate
        }
        let output = ProcessRunner.run(
            "/bin/zsh",
            ["-lc", "PATH=\(shellQuoted("\(NSHomeDirectory())/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin")) command -v \(shellQuoted(name))"],
            timeout: 5
        )
        let discovered = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return FileManager.default.isExecutableFile(atPath: discovered) ? discovered : nil
    }

    private static func detectVersion(executable: String) -> String {
        let output = ProcessRunner.run(executable, ["--version"], timeout: 15)
        let text = output.combinedTrimmed
        return text.isEmpty ? "Installed" : text
    }

    private static func compatibility(for engine: AgentEngine, version: String, installed: Bool) -> (known: Bool, note: String) {
        guard installed else {
            return (false, "\(engine.title) CLI is not installed.")
        }
        guard let parsed = SemanticVersion.first(in: version) else {
            return (false, "Version could not be parsed. The latest known \(adapterName(for: engine)) shape will be used.")
        }
        let expected: SemanticVersion
        switch engine {
        case .hermes:
            expected = SemanticVersion(major: 0, minor: 15, patch: 1)
        case .codex:
            expected = SemanticVersion(major: 0, minor: 130, patch: 0)
        case .claude:
            expected = SemanticVersion(major: 2, minor: 1, patch: 144)
        }
        if parsed.major == expected.major, parsed.minor == expected.minor {
            var note = "Known command shape: \(adapterName(for: engine))."
            if version.localizedCaseInsensitiveContains("update available") {
                note += " CLI reports an update is available."
            }
            return (true, note)
        }
        if parsed.major > expected.major || (parsed.major == expected.major && parsed.minor > expected.minor) {
            return (false, "\(engine.title) is newer than the validated adapter range. Runs still use the latest known command shape.")
        }
        return (false, "\(engine.title) is older than the validated adapter range. Upgrade the CLI or adjust \(adapterName(for: engine)).")
    }

    private static func adapterName(for engine: AgentEngine) -> String {
        switch engine {
        case .hermes:
            "HermesChatAdapter"
        case .codex:
            "CodexExecAdapter"
        case .claude:
            "ClaudePrintAdapter"
        }
    }

    private static func commandShape(for engine: AgentEngine) -> String {
        switch engine {
        case .hermes:
            "hermes chat -Q --source veqral-<project> --provider <provider> --model <model> --checkpoints --worktree"
        case .codex:
            "codex exec [--model <model>] [resume <session>] <prompt>"
        case .claude:
            "claude --print --output-format stream-json [--resume <session>] [--model <model>] <prompt>"
        }
    }

    private static func projectName(for path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent.nilIfBlank ?? "project"
    }

    private static func safeTag(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.lowercased().unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        return String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-")).nilIfBlank ?? "project"
    }
}

struct SemanticVersion: Sendable, Equatable {
    var major: Int
    var minor: Int
    var patch: Int

    static func first(in text: String) -> SemanticVersion? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+)\.(\d+)(?:\.(\d+))?"#) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let majorRange = Range(match.range(at: 1), in: text),
              let minorRange = Range(match.range(at: 2), in: text),
              let major = Int(text[majorRange]),
              let minor = Int(text[minorRange]) else {
            return nil
        }
        let patch: Int
        if match.range(at: 3).location != NSNotFound,
           let patchRange = Range(match.range(at: 3), in: text),
           let parsedPatch = Int(text[patchRange]) {
            patch = parsedPatch
        } else {
            patch = 0
        }
        return SemanticVersion(major: major, minor: minor, patch: patch)
    }
}

final class AgentRunner {
    private let state: HostState

    init(state: HostState) {
        self.state = state
    }

    static func hermesVersion() -> String {
        CLIAdapterRegistry.hermesVersion()
    }

    func start(runID: String) async {
        guard let run = await state.run(runID: runID) else { return }
        guard let plan = CLIAdapterRegistry.plan(for: run) else {
            let status = CLIAdapterRegistry.status(for: run.engineOrDefault)
            await state.appendLog(runID: runID, stream: "error", message: status.compatibilityNote)
            await state.finish(runID: runID, exitCode: 127)
            return
        }
        await state.appendLog(runID: runID, stream: "host", message: "Starting \(plan.toolStatus.title) engine with \(plan.toolStatus.adapter) (\(plan.toolStatus.versionSummary))")
        if !plan.toolStatus.isKnownCompatible {
            await state.appendLog(runID: runID, stream: "warn", message: plan.toolStatus.compatibilityNote)
        }
        await PTYProcess.run(
            executable: plan.executable,
            arguments: plan.arguments,
            workingDirectory: run.workingDirectory,
            runID: runID,
            state: state,
            toolStatus: plan.toolStatus
        )
    }
}

enum PTYProcess {
    static func run(
        executable: String,
        arguments: [String],
        workingDirectory: String,
        runID: String,
        state: HostState,
        toolStatus: CLIToolStatus? = nil
    ) async {
        var master: Int32 = -1
        var slave: Int32 = -1
        guard openpty(&master, &slave, nil, nil, nil) == 0 else {
            await state.appendLog(runID: runID, stream: "error", message: "Failed to open PTY")
            await state.finish(runID: runID, exitCode: 127)
            return
        }
        defer {
            if master >= 0 { close(master) }
            if slave >= 0 { close(slave) }
        }

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        posix_spawn_file_actions_addchdir_np(&actions, workingDirectory)
        posix_spawn_file_actions_adddup2(&actions, slave, STDIN_FILENO)
        posix_spawn_file_actions_adddup2(&actions, slave, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, slave, STDERR_FILENO)
        defer { posix_spawn_file_actions_destroy(&actions) }

        let argStrings = [executable] + arguments
        var argv: [UnsafeMutablePointer<CChar>?] = argStrings.map { strdup($0) }
        argv.append(nil)
        defer { argv.forEach { if $0 != nil { free($0) } } }

        let home = NSHomeDirectory()
        let envStrings = [
            "PATH=\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME=\(home)",
            "LANG=en_US.UTF-8"
        ]
        var env: [UnsafeMutablePointer<CChar>?] = envStrings.map { strdup($0) }
        env.append(nil)
        defer { env.forEach { if $0 != nil { free($0) } } }

        var pid = pid_t()
        let status = executable.withCString { path in
            argv.withUnsafeMutableBufferPointer { argvBuffer in
                env.withUnsafeMutableBufferPointer { envBuffer in
                    posix_spawn(&pid, path, &actions, nil, argvBuffer.baseAddress, envBuffer.baseAddress)
                }
            }
        }
        close(slave)
        slave = -1
        if status != 0 {
            await state.appendLog(runID: runID, stream: "error", message: "Failed to spawn process: \(status)")
            await state.finish(runID: runID, exitCode: 127)
            return
        }
        await state.markStarted(runID: runID, pid: pid)
        setNonBlocking(master)

        var waitStatus: Int32 = 0
        var lineBuffer = Data()
        var capturedOutput = ""
        while true {
            appendCaptured(&capturedOutput, await readAvailable(master: master, buffer: &lineBuffer, runID: runID, state: state))
            let result = waitpid(pid, &waitStatus, WNOHANG)
            if result == pid {
                appendCaptured(&capturedOutput, await readAvailable(master: master, buffer: &lineBuffer, runID: runID, state: state))
                if !lineBuffer.isEmpty {
                    let text = String(data: lineBuffer, encoding: .utf8) ?? ""
                    appendCaptured(&capturedOutput, text)
                    await state.appendLog(runID: runID, stream: "pty", message: text)
                }
                let code = exitCode(from: waitStatus)
                if let toolStatus,
                   let diagnostic = CLIAdapterRegistry.adapterDiagnostic(for: toolStatus, output: capturedOutput, exitCode: code) {
                    await state.appendLog(runID: runID, stream: "adapter", message: diagnostic)
                }
                await state.finish(runID: runID, exitCode: code)
                break
            }
            if result == -1 {
                await state.finish(runID: runID, exitCode: 1)
                break
            }
            usleep(50_000)
        }
    }

    private static func readAvailable(master: Int32, buffer: inout Data, runID: String, state: HostState) async -> String {
        var temp = [UInt8](repeating: 0, count: 4096)
        var emitted = ""
        while true {
            let readCount = Darwin.read(master, &temp, temp.count)
            if readCount > 0 {
                buffer.append(temp, count: readCount)
                while let range = buffer.firstRange(of: Data([0x0A])) {
                    let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                    buffer.removeSubrange(buffer.startIndex...range.lowerBound)
                    let line = String(data: lineData, encoding: .utf8) ?? ""
                    emitted += line + "\n"
                    await state.appendLog(runID: runID, stream: "pty", message: line)
                }
            } else {
                break
            }
        }
        return emitted
    }

    private static func appendCaptured(_ output: inout String, _ text: String) {
        guard !text.isEmpty else { return }
        output += text
        let maxCharacters = 524_288
        if output.count > maxCharacters {
            output = String(output.suffix(maxCharacters))
        }
    }

    private static func setNonBlocking(_ fd: Int32) {
        let flags = fcntl(fd, F_GETFL, 0)
        if flags >= 0 {
            _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        }
    }

    private static func exitCode(from waitStatus: Int32) -> Int32 {
        let code = Int32((waitStatus >> 8) & 0xff)
        if code == 0, waitStatus != 0 {
            return 1
        }
        return code
    }
}

enum HostMenuLanguage: String, Codable, CaseIterable {
    case system
    case english
    case japanese

    var effective: HostMenuLanguage {
        switch self {
        case .system:
            Locale.current.identifier.lowercased().hasPrefix("ja") ? .japanese : .english
        case .english, .japanese:
            self
        }
    }

    var menuTitle: String {
        switch self {
        case .system:
            "System"
        case .english:
            "English"
        case .japanese:
            "日本語"
        }
    }
}

enum HostMenuBarStyle: String, Codable, CaseIterable {
    case textOnly
    case iconAndText
    case iconOnly

    func title(language: HostMenuLanguage) -> String {
        let japanese = language.effective == .japanese
        switch self {
        case .textOnly:
            return japanese ? "文字のみ" : "Text only"
        case .iconAndText:
            return japanese ? "アイコン + 文字" : "Icon + text"
        case .iconOnly:
            return japanese ? "アイコンのみ" : "Icon only"
        }
    }
}

enum HostMenuBarSymbol: String, Codable, CaseIterable {
    case commandNode
    case terminal
    case spark
    case network
    case bolt

    var systemName: String {
        switch self {
        case .commandNode:
            "point.3.connected.trianglepath.dotted"
        case .terminal:
            "terminal"
        case .spark:
            "sparkles"
        case .network:
            "network"
        case .bolt:
            "bolt.horizontal.circle"
        }
    }

    func title(language: HostMenuLanguage) -> String {
        let japanese = language.effective == .japanese
        switch self {
        case .commandNode:
            return japanese ? "コマンドノード" : "Command node"
        case .terminal:
            return japanese ? "ターミナル" : "Terminal"
        case .spark:
            return japanese ? "スパーク" : "Spark"
        case .network:
            return japanese ? "ネットワーク" : "Network"
        case .bolt:
            return japanese ? "ボルト" : "Bolt"
        }
    }
}

struct HostAppearanceSettings: Codable, Equatable {
    var title: String = "Veqral"
    var style: HostMenuBarStyle = .textOnly
    var symbol: HostMenuBarSymbol = .commandNode
    var language: HostMenuLanguage = .system
    var animateWhileListening: Bool = false

    static let defaultsKey = "dev.hiroyuki.veqral.host.appearance"

    static func load() -> HostAppearanceSettings {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let settings = try? JSONDecoder().decode(HostAppearanceSettings.self, from: data) else {
            return HostAppearanceSettings()
        }
        return settings.normalized()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(normalized()) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    func normalized() -> HostAppearanceSettings {
        var copy = self
        copy.title = copy.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if copy.title.isEmpty {
            copy.title = "Veqral"
        }
        return copy
    }
}

struct HostMenuLabels {
    let language: HostMenuLanguage

    private var japanese: Bool {
        language.effective == .japanese
    }

    var appearanceSettings: String { japanese ? "メニューバー表示設定..." : "Menu Bar Appearance..." }
    var showPairingQR: String { japanese ? "ペアリングQRを表示" : "Show Pairing QR" }
    var copyPairingURL: String { japanese ? "ペアリングURLをコピー" : "Copy Pairing URL" }
    var rotatePairingCode: String { japanese ? "ペアリングコードを更新" : "Rotate Pairing Code" }
    var unattendedSetup: String { japanese ? "無人運用設定..." : "Unattended Remote Setup..." }
    var installLoginAgent: String { japanese ? "ログインエージェントを登録" : "Install Login Agent" }
    var removeLoginAgent: String { japanese ? "ログインエージェントを削除" : "Remove Login Agent" }
    var quit: String { japanese ? "終了" : "Quit" }
    var settingsTitle: String { japanese ? "メニューバー表示設定" : "Menu Bar Appearance" }
    var displayName: String { japanese ? "表示名" : "Display name" }
    var style: String { japanese ? "スタイル" : "Style" }
    var icon: String { japanese ? "アイコン" : "Icon" }
    var languageTitle: String { japanese ? "言語" : "Language" }
    var animate: String { japanese ? "待受中にアイコンをゆっくり動かす" : "Animate icon while listening" }
    var reset: String { japanese ? "リセット" : "Reset" }
    var cancel: String { japanese ? "キャンセル" : "Cancel" }
    var apply: String { japanese ? "適用" : "Apply" }
    var pairWindowTitle: String { japanese ? "Veqral をペアリング" : "Pair Veqral" }
    var starting: String { japanese ? "起動中" : "Starting" }
    var pairingRotated: String { japanese ? "ペアリングコードを更新しました" : "Pairing rotated" }
    var loginAgentInstalled: String { japanese ? "ログインエージェントを登録しました" : "Login agent installed" }
    var loginAgentFailed: String { japanese ? "ログインエージェント登録に失敗しました" : "Login agent failed" }
    var loginAgentRemoved: String { japanese ? "ログインエージェントを削除しました" : "Login agent removed" }
    var loginAgentRemoveFailed: String { japanese ? "ログインエージェント削除に失敗しました" : "Login agent remove failed" }

    func status(_ status: String) -> String {
        guard japanese else { return status }
        if status == "Starting" { return starting }
        if status == "Pairing rotated" { return pairingRotated }
        if status == "Login agent installed" { return loginAgentInstalled }
        if status == "Login agent failed" { return loginAgentFailed }
        if status == "Login agent removed" { return loginAgentRemoved }
        if status == "Login agent remove failed" { return loginAgentRemoveFailed }
        if status.hasPrefix("Listening on ") {
            return "待受中: \(status.replacingOccurrences(of: "Listening on ", with: ""))"
        }
        if status.hasPrefix("Failed: ") {
            return "失敗: \(status.replacingOccurrences(of: "Failed: ", with: ""))"
        }
        return status
    }
}

@MainActor
final class StatusController {
    private let state: HostState
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var window: NSWindow?
    private var setupWindow: NSWindow?
    private var appearanceWindow: NSWindow?
    private var settings = HostAppearanceSettings.load()
    private var lastStatus = "Starting"
    private var animationTimer: Timer?
    private var animationFrame = 0
    private weak var setupStatusView: NSTextView?
    private weak var setupPasswordField: NSSecureTextField?
    private weak var setupSkipAutologinButton: NSButton?
    private weak var appearanceTitleField: NSTextField?
    private weak var appearanceStylePopup: NSPopUpButton?
    private weak var appearanceSymbolPopup: NSPopUpButton?
    private weak var appearanceLanguagePopup: NSPopUpButton?
    private weak var appearanceAnimateButton: NSButton?

    private var labels: HostMenuLabels {
        HostMenuLabels(language: settings.language)
    }

    init(state: HostState) {
        self.state = state
        applyAppearance()
        rebuildMenu(status: labels.starting)
    }

    func setStatus(_ status: String) {
        lastStatus = status
        applyAppearance()
        rebuildMenu(status: labels.status(status))
    }

    private func rebuildMenu(status: String) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: status, action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: labels.appearanceSettings, action: #selector(showAppearanceSettings), keyEquivalent: ","))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: labels.showPairingQR, action: #selector(showPairingQR), keyEquivalent: "p"))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem(title: labels.copyPairingURL, action: #selector(copyPairingURL), keyEquivalent: "c"))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem(title: labels.rotatePairingCode, action: #selector(rotatePairing), keyEquivalent: "r"))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: labels.unattendedSetup, action: #selector(showUnattendedSetup), keyEquivalent: "u"))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem(title: labels.installLoginAgent, action: #selector(installLoginAgent), keyEquivalent: "i"))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem(title: labels.removeLoginAgent, action: #selector(removeLoginAgent), keyEquivalent: ""))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: labels.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
    }

    private func applyAppearance() {
        guard let button = item.button else { return }
        settings = settings.normalized()
        button.title = settings.style == .iconOnly ? "" : settings.title
        button.image = settings.style == .textOnly ? nil : statusImage()
        button.imagePosition = settings.style == .iconOnly ? .imageOnly : .imageLeading
        button.toolTip = settings.title
        item.length = settings.style == .iconOnly ? 28 : NSStatusItem.variableLength
        configureAnimation()
    }

    private func statusImage() -> NSImage? {
        let image = NSImage(systemSymbolName: settings.symbol.systemName, accessibilityDescription: settings.title)
        image?.isTemplate = true
        return image
    }

    private var isListeningStatus: Bool {
        lastStatus.lowercased().hasPrefix("listening")
    }

    private func configureAnimation() {
        if settings.animateWhileListening, isListeningStatus, settings.style != .textOnly {
            guard animationTimer == nil else { return }
            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.85, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.animationFrame += 1
                    self.item.button?.alphaValue = self.animationFrame.isMultiple(of: 2) ? 0.62 : 1.0
                }
            }
        } else {
            animationTimer?.invalidate()
            animationTimer = nil
            animationFrame = 0
            item.button?.alphaValue = 1.0
        }
    }

    @objc private func showAppearanceSettings() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 290))

        let title = NSTextField(labelWithString: labels.settingsTitle)
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.frame = NSRect(x: 22, y: 246, width: 396, height: 24)
        content.addSubview(title)

        let nameLabel = NSTextField(labelWithString: labels.displayName)
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.frame = NSRect(x: 22, y: 202, width: 130, height: 18)
        content.addSubview(nameLabel)

        let titleField = NSTextField(frame: NSRect(x: 170, y: 196, width: 248, height: 28))
        titleField.stringValue = settings.title
        content.addSubview(titleField)
        appearanceTitleField = titleField

        let styleLabel = NSTextField(labelWithString: labels.style)
        styleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        styleLabel.frame = NSRect(x: 22, y: 160, width: 130, height: 18)
        content.addSubview(styleLabel)

        let stylePopup = NSPopUpButton(frame: NSRect(x: 170, y: 154, width: 248, height: 28))
        for style in HostMenuBarStyle.allCases {
            stylePopup.addItem(withTitle: style.title(language: settings.language))
            stylePopup.lastItem?.representedObject = style.rawValue
        }
        stylePopup.selectItem(withTitle: settings.style.title(language: settings.language))
        content.addSubview(stylePopup)
        appearanceStylePopup = stylePopup

        let symbolLabel = NSTextField(labelWithString: labels.icon)
        symbolLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        symbolLabel.frame = NSRect(x: 22, y: 118, width: 130, height: 18)
        content.addSubview(symbolLabel)

        let symbolPopup = NSPopUpButton(frame: NSRect(x: 170, y: 112, width: 248, height: 28))
        for symbol in HostMenuBarSymbol.allCases {
            symbolPopup.addItem(withTitle: symbol.title(language: settings.language))
            symbolPopup.lastItem?.representedObject = symbol.rawValue
        }
        symbolPopup.selectItem(withTitle: settings.symbol.title(language: settings.language))
        content.addSubview(symbolPopup)
        appearanceSymbolPopup = symbolPopup

        let languageLabel = NSTextField(labelWithString: labels.languageTitle)
        languageLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        languageLabel.frame = NSRect(x: 22, y: 76, width: 130, height: 18)
        content.addSubview(languageLabel)

        let languagePopup = NSPopUpButton(frame: NSRect(x: 170, y: 70, width: 248, height: 28))
        for language in HostMenuLanguage.allCases {
            languagePopup.addItem(withTitle: language.menuTitle)
            languagePopup.lastItem?.representedObject = language.rawValue
        }
        languagePopup.selectItem(withTitle: settings.language.menuTitle)
        content.addSubview(languagePopup)
        appearanceLanguagePopup = languagePopup

        let animate = NSButton(checkboxWithTitle: labels.animate, target: nil, action: nil)
        animate.frame = NSRect(x: 166, y: 36, width: 252, height: 24)
        animate.state = settings.animateWhileListening ? .on : .off
        content.addSubview(animate)
        appearanceAnimateButton = animate

        let reset = NSButton(title: labels.reset, target: self, action: #selector(resetAppearanceSettings))
        reset.frame = NSRect(x: 22, y: 10, width: 92, height: 28)
        content.addSubview(reset)

        let cancel = NSButton(title: labels.cancel, target: self, action: #selector(closeAppearanceSettings))
        cancel.frame = NSRect(x: 226, y: 10, width: 90, height: 28)
        content.addSubview(cancel)

        let apply = NSButton(title: labels.apply, target: self, action: #selector(applyAppearanceSettings))
        apply.bezelStyle = .rounded
        apply.keyEquivalent = "\r"
        apply.frame = NSRect(x: 328, y: 10, width: 90, height: 28)
        content.addSubview(apply)

        let window = NSWindow(contentRect: content.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = labels.settingsTitle
        window.contentView = content
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        appearanceWindow = window
    }

    @objc private func applyAppearanceSettings() {
        settings = HostAppearanceSettings(
            title: appearanceTitleField?.stringValue ?? "Veqral",
            style: selectedStyle(),
            symbol: selectedSymbol(),
            language: selectedLanguage(),
            animateWhileListening: appearanceAnimateButton?.state == .on
        ).normalized()
        settings.save()
        applyAppearance()
        rebuildMenu(status: labels.status(lastStatus))
        closeAppearanceSettings()
    }

    @objc private func resetAppearanceSettings() {
        settings = HostAppearanceSettings()
        settings.save()
        applyAppearance()
        rebuildMenu(status: labels.status(lastStatus))
        closeAppearanceSettings()
    }

    @objc private func closeAppearanceSettings() {
        appearanceWindow?.close()
        appearanceWindow = nil
    }

    private func selectedStyle() -> HostMenuBarStyle {
        guard let value = appearanceStylePopup?.selectedItem?.representedObject as? String,
              let style = HostMenuBarStyle(rawValue: value) else {
            return settings.style
        }
        return style
    }

    private func selectedSymbol() -> HostMenuBarSymbol {
        guard let value = appearanceSymbolPopup?.selectedItem?.representedObject as? String,
              let symbol = HostMenuBarSymbol(rawValue: value) else {
            return settings.symbol
        }
        return symbol
    }

    private func selectedLanguage() -> HostMenuLanguage {
        guard let value = appearanceLanguagePopup?.selectedItem?.representedObject as? String,
              let language = HostMenuLanguage(rawValue: value) else {
            return settings.language
        }
        return language
    }

    @objc private func copyPairingURL() {
        Task {
            let url = await state.pairingURL()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url, forType: .string)
        }
    }

    @objc private func rotatePairing() {
        Task {
            _ = await state.rotatePairingCode()
            await MainActor.run { setStatus("Pairing rotated") }
        }
    }

    @objc private func showPairingQR() {
        Task {
            let url = await state.pairingURL()
            let image = QRCode.image(from: url)
            await MainActor.run {
                let imageView = NSImageView(image: image)
                imageView.imageScaling = .scaleProportionallyUpOrDown
                imageView.frame = NSRect(x: 20, y: 54, width: 260, height: 260)
                let text = NSTextField(labelWithString: url)
                text.frame = NSRect(x: 20, y: 18, width: 260, height: 28)
                text.lineBreakMode = .byTruncatingMiddle
                let content = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 334))
                content.addSubview(imageView)
                content.addSubview(text)
                let window = NSWindow(contentRect: content.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
                window.title = self.labels.pairWindowTitle
                window.contentView = content
                window.center()
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                self.window = window
            }
        }
    }

    @objc private func installLoginAgent() {
        do {
            try LaunchAgentManager.install()
            setStatus("Login agent installed")
        } catch {
            setStatus("Login agent failed")
        }
    }

    @objc private func removeLoginAgent() {
        do {
            try LaunchAgentManager.remove()
            setStatus("Login agent removed")
        } catch {
            setStatus("Login agent remove failed")
        }
    }

    @objc private func showUnattendedSetup() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 470))

        let title = NSTextField(labelWithString: "Unattended Remote Operation")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.frame = NSRect(x: 22, y: 430, width: 496, height: 24)
        content.addSubview(title)

        let explanation = NSTextField(wrappingLabelWithString: "Use this on a dedicated Mac mini or always-on Mac Host. It can disable screen-lock password, prevent sleep, enable restart after power loss, and optionally enable macOS autologin. The login password is used only for this operation and is never saved.")
        explanation.font = .systemFont(ofSize: 12)
        explanation.textColor = .secondaryLabelColor
        explanation.frame = NSRect(x: 22, y: 368, width: 496, height: 54)
        content.addSubview(explanation)

        let statusScroll = NSScrollView(frame: NSRect(x: 22, y: 156, width: 496, height: 196))
        statusScroll.borderType = .bezelBorder
        statusScroll.hasVerticalScroller = true
        let statusView = NSTextView(frame: statusScroll.bounds)
        statusView.isEditable = false
        statusView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusView.string = Self.statusText(UnattendedSetupManager.status())
        statusScroll.documentView = statusView
        content.addSubview(statusScroll)
        setupStatusView = statusView

        let passwordLabel = NSTextField(labelWithString: "Login password (only used to set autologin)")
        passwordLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        passwordLabel.frame = NSRect(x: 22, y: 124, width: 260, height: 18)
        content.addSubview(passwordLabel)

        let password = NSSecureTextField(frame: NSRect(x: 286, y: 118, width: 232, height: 28))
        password.placeholderString = "Not saved"
        content.addSubview(password)
        setupPasswordField = password

        let skipAutologin = NSButton(checkboxWithTitle: "Skip autologin when FileVault is On", target: nil, action: nil)
        skipAutologin.frame = NSRect(x: 22, y: 86, width: 300, height: 24)
        skipAutologin.state = .on
        content.addSubview(skipAutologin)
        setupSkipAutologinButton = skipAutologin

        let refresh = NSButton(title: "Refresh", target: self, action: #selector(refreshUnattendedStatus))
        refresh.frame = NSRect(x: 22, y: 34, width: 92, height: 32)
        content.addSubview(refresh)

        let revert = NSButton(title: "Revert", target: self, action: #selector(revertUnattendedSetup))
        revert.frame = NSRect(x: 318, y: 34, width: 90, height: 32)
        content.addSubview(revert)

        let apply = NSButton(title: "Apply", target: self, action: #selector(applyUnattendedSetup))
        apply.bezelStyle = .rounded
        apply.keyEquivalent = "\r"
        apply.frame = NSRect(x: 426, y: 34, width: 92, height: 32)
        content.addSubview(apply)

        let window = NSWindow(contentRect: content.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Veqral Mac Host Setup"
        window.contentView = content
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        setupWindow = window
    }

    @objc private func refreshUnattendedStatus() {
        setupStatusView?.string = Self.statusText(UnattendedSetupManager.status())
    }

    @objc private func applyUnattendedSetup() {
        let alert = NSAlert()
        alert.messageText = "Apply unattended remote operation settings?"
        alert.informativeText = "This changes macOS security and power settings so the Mac can recover and accept remote work. Use it only on a Mac you are comfortable leaving available for remote agent execution."
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let password = setupPasswordField?.stringValue ?? ""
        let allowSkip = setupSkipAutologinButton?.state == .on
        Task {
            do {
                let result = try UnattendedSetupManager.apply(loginPassword: password, allowSkipAutologin: allowSkip)
                await state.recordAudit("unattended setup applied from menu autologinSkipped=\(result.autologinSkipped)")
                await MainActor.run {
                    setupPasswordField?.stringValue = ""
                    setupStatusView?.string = "\(result.message)\n\n\(Self.statusText(result.status))"
                }
            } catch {
                await MainActor.run {
                    setupStatusView?.string = "Apply failed:\n\(error.localizedDescription)\n\n\(Self.statusText(UnattendedSetupManager.status()))"
                }
            }
        }
    }

    @objc private func revertUnattendedSetup() {
        let alert = NSAlert()
        alert.messageText = "Revert unattended remote operation settings?"
        alert.informativeText = "This turns autologin off, restores screen-lock password, allows sleep again, and disables autorestart."
        alert.addButton(withTitle: "Revert")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        Task {
            do {
                let result = try UnattendedSetupManager.revert()
                await state.recordAudit("unattended setup reverted from menu")
                await MainActor.run {
                    setupStatusView?.string = "\(result.message)\n\n\(Self.statusText(result.status))"
                }
            } catch {
                await MainActor.run {
                    setupStatusView?.string = "Revert failed:\n\(error.localizedDescription)\n\n\(Self.statusText(UnattendedSetupManager.status()))"
                }
            }
        }
    }

    private static func statusText(_ status: UnattendedSetupStatus) -> String {
        var lines = [
            "FileVault: \(status.fileVaultStatus)",
            "Autologin: \(status.autologinStatus)",
            "Screen lock password: \(status.askForPassword)",
            "Screen lock delay: \(status.askForPasswordDelay)",
            "System sleep: \(status.sleep)",
            "Display sleep: \(status.displaySleep)",
            "Autorestart: \(status.autorestart)"
        ]
        if !status.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            lines.append(contentsOf: status.warnings.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }
}

enum QRCode {
    static func image(from string: String) -> NSImage {
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(Data(string.utf8), forKey: "inputMessage")
        filter?.setValue("M", forKey: "inputCorrectionLevel")
        let output = filter?.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let rep = NSCIImageRep(ciImage: output ?? CIImage())
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}

enum LaunchAgentManager {
    private static let label = "dev.hiroyuki.veqral.host"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static func install() throws {
        guard let executable = ProcessInfo.processInfo.arguments.first else {
            throw HostError.badRequest("Cannot resolve current host executable path.")
        }
        let logFolder = HostConfig.folder.appendingPathComponent("launchd", isDirectory: true)
        try FileManager.default.createDirectory(at: logFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": logFolder.appendingPathComponent("stdout.log").path,
            "StandardErrorPath": logFolder.appendingPathComponent("stderr.log").path,
            "WorkingDirectory": FileManager.default.currentDirectoryPath,
            "EnvironmentVariables": [
                "PATH": "\(NSHomeDirectory())/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
                "HOME": NSHomeDirectory(),
                "LANG": "en_US.UTF-8"
            ]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
        _ = ProcessRunner.run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(label)"], timeout: 10)
        let output = ProcessRunner.run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistURL.path], timeout: 20)
        guard output.exitCode == 0 else {
            throw HostError.badRequest(output.combinedTrimmed)
        }
    }

    static func remove() throws {
        _ = ProcessRunner.run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(label)"], timeout: 10)
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }
}

enum GitDiffInspector {
    static func entries(workingDirectory: String) -> [GitDiffEntry] {
        let output = runGit("git diff --numstat", workingDirectory: workingDirectory)
        guard output.exitCode == 0 else { return [] }
        return output.stdout
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let parts = line.split(separator: "\t").map(String.init)
                guard parts.count >= 3,
                      let additions = Int(parts[0]),
                      let deletions = Int(parts[1]) else {
                    return nil
                }
                return GitDiffEntry(path: parts[2], additions: additions, deletions: deletions)
            }
    }

    static func runGit(_ command: String, workingDirectory: String) -> ProcessOutput {
        ProcessRunner.run(
            "/bin/zsh",
            ["-lc", "cd \(shellQuoted(workingDirectory.expandingTilde)) && \(command)"],
            timeout: 30
        )
    }
}

enum ArtifactScanner {
    static func artifacts(for run: HostRun) -> [HostArtifact] {
        var artifacts = AttachmentStore.artifacts(runID: run.id)
        let root = URL(fileURLWithPath: run.workingDirectory.expandingTilde)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return artifacts
        }
        let extensions: Set<String> = ["png", "jpg", "jpeg", "gif", "pdf", "html", "htm", "json", "log", "txt", "md"]
        for case let url as URL in enumerator {
            guard extensions.contains(url.pathExtension.lowercased()),
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
                continue
            }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            if let updatedAt = values?.contentModificationDate, updatedAt < run.startedAt {
                continue
            }
            artifacts.append(HostArtifact(
                id: url.path,
                title: url.lastPathComponent,
                type: url.pathExtension.lowercased(),
                path: url.path,
                bytes: values?.fileSize ?? 0,
                updatedAt: values?.contentModificationDate
            ))
        }
        return artifacts.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }.prefix(50).map { $0 }
    }
}

enum AttachmentStore {
    private static var rootURL: URL {
        HostConfig.folder.appendingPathComponent("attachments", isDirectory: true)
    }

    static func save(_ attachments: [RunAttachmentUpload], runID: String) throws -> [HostArtifact] {
        guard !attachments.isEmpty else { return [] }
        let runFolder = rootURL.appendingPathComponent(runID, isDirectory: true)
        try FileManager.default.createDirectory(at: runFolder, withIntermediateDirectories: true)

        return try attachments.prefix(8).map { attachment in
            let destination = runFolder.appendingPathComponent(safeFileName(attachment.fileName, fallback: "\(attachment.id).bin"))
            try attachment.data.write(to: destination, options: .atomic)
            let values = try? destination.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            return HostArtifact(
                id: "attachment:\(runID):\(destination.lastPathComponent)",
                title: destination.lastPathComponent,
                type: attachment.mimeType,
                path: destination.path,
                bytes: values?.fileSize ?? attachment.data.count,
                updatedAt: values?.contentModificationDate ?? Date()
            )
        }
    }

    static func artifacts(runID: String) -> [HostArtifact] {
        let runFolder = rootURL.appendingPathComponent(runID, isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: runFolder,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return files.compactMap { url in
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile != false else { return nil }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            return HostArtifact(
                id: "attachment:\(runID):\(url.lastPathComponent)",
                title: url.lastPathComponent,
                type: url.pathExtension.isEmpty ? "attachment" : url.pathExtension.lowercased(),
                path: url.path,
                bytes: values?.fileSize ?? 0,
                updatedAt: values?.contentModificationDate
            )
        }
    }

    private static func safeFileName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? fallback : URL(fileURLWithPath: trimmed).lastPathComponent
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        let sanitized = String(base.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        return sanitized.isEmpty ? fallback : sanitized
    }
}

enum GitHubInspector {
    static func status(workingDirectory: String) -> GitHubStatusResponse {
        let directory = workingDirectory.expandingTilde
        guard let root = findGitRoot(startingAt: directory) else {
            return GitHubStatusResponse(
                workingDirectory: directory,
                gitRoot: "",
                branch: "",
                remote: "",
                changedFiles: 0,
                aheadBehind: "",
                ghAuthenticated: false,
                pullRequestURL: "",
                pullRequestState: "No repository",
                checksSummary: "No checks",
                error: "Not a Git repository"
            )
        }
        let branch = firstLine(git("symbolic-ref --short HEAD 2>/dev/null || rev-parse --short HEAD 2>/dev/null", root: root, timeout: 2))
        let remote = firstLine(git("remote get-url origin", root: root, timeout: 2))
        let status = git("status --porcelain", root: root, timeout: 2)
        let upstream = git("rev-list --left-right --count @{upstream}...HEAD 2>/dev/null", root: root, timeout: 2)
        let auth = shell("gh auth status -h github.com >/dev/null 2>&1 && echo yes || echo no", timeout: 10)
        let prJSON: ProcessOutput
        if let slug = githubSlug(from: remote), !branch.isEmpty {
            prJSON = shell("gh pr list --repo \(shellQuoted(slug)) --head \(shellQuoted(branch)) --json url,state,statusCheckRollup --limit 1 2>/dev/null || true", timeout: 10)
        } else {
            prJSON = ProcessOutput(exitCode: 0, stdout: "[]", stderr: "")
        }
        let pr = parsePR(prJSON.stdout)
        var errors: [String] = []
        if branch.isEmpty { errors.append("git branch unavailable") }
        if remote.isEmpty { errors.append("git remote unavailable") }
        if status.exitCode != 0 {
            errors.append(status.combinedTrimmed.isEmpty ? "git status unavailable (exit \(status.exitCode))" : status.combinedTrimmed)
        }
        return GitHubStatusResponse(
            workingDirectory: directory,
            gitRoot: root,
            branch: branch,
            remote: remote,
            changedFiles: status.stdout.split(whereSeparator: \.isNewline).count,
            aheadBehind: firstLine(upstream),
            ghAuthenticated: firstLine(auth).lowercased() == "yes",
            pullRequestURL: pr.url,
            pullRequestState: pr.state,
            checksSummary: pr.checks,
            error: errors.isEmpty ? nil : errors.joined(separator: "; ")
        )
    }

    static func createDraftPR(workingDirectory: String, title: String, body: String) throws -> CreateDraftPRResponse {
        let directory = workingDirectory.expandingTilde
        guard let root = findGitRoot(startingAt: directory) else {
            throw HostError.badRequest("Not a Git repository")
        }
        let branch = firstLine(git("symbolic-ref --short HEAD 2>/dev/null || rev-parse --short HEAD 2>/dev/null", root: root, timeout: 5))
        let remote = firstLine(git("remote get-url origin", root: root, timeout: 5))
        guard let slug = githubSlug(from: remote), !branch.isEmpty else {
            throw HostError.badRequest("GitHub remote or branch not found")
        }
        let titleArg = title.isEmpty ? "--fill" : "--title \(shellQuoted(title))"
        let bodyArg = body.isEmpty ? "" : "--body \(shellQuoted(body))"
        let output = shell("gh pr create --repo \(shellQuoted(slug)) --head \(shellQuoted(branch)) --draft \(titleArg) \(bodyArg)", timeout: 60)
        guard output.exitCode == 0 else {
            throw HostError.badRequest(Redactor.redact(output.combinedTrimmed))
        }
        return CreateDraftPRResponse(ok: true, url: firstLine(output))
    }

    private static func git(_ arguments: String, root: String, timeout: TimeInterval = 30) -> ProcessOutput {
        let gitDir = gitDirectory(for: root)
        return shell("\(gitCommand) --git-dir \(shellQuoted(gitDir)) --work-tree \(shellQuoted(root)) \(arguments)", timeout: timeout)
    }

    private static func shell(_ command: String, timeout: TimeInterval = 30) -> ProcessOutput {
        ProcessRunner.run("/bin/zsh", ["-lc", command], timeout: timeout)
    }

    private static let gitCommand = "GIT_OPTIONAL_LOCKS=0 /usr/bin/git -c core.fsmonitor=false"

    private static func findGitRoot(startingAt path: String) -> String? {
        var isDirectory = ObjCBool(false)
        var url = URL(fileURLWithPath: path)
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            url.deleteLastPathComponent()
        }
        while true {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path) {
                return url.path
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { return nil }
            url = parent
        }
    }

    private static func gitDirectory(for root: String) -> String {
        let dotGit = URL(fileURLWithPath: root).appendingPathComponent(".git")
        var isDirectory = ObjCBool(false)
        if FileManager.default.fileExists(atPath: dotGit.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return dotGit.path
        }
        if let content = try? String(contentsOf: dotGit, encoding: .utf8),
           content.hasPrefix("gitdir:") {
            let rawValue = content
                .replacingOccurrences(of: "gitdir:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if rawValue.hasPrefix("/") { return rawValue }
            return URL(fileURLWithPath: root)
                .appendingPathComponent(rawValue)
                .standardizedFileURL
                .path
        }
        return dotGit.path
    }

    private static func currentBranch(root: String) -> String {
        let headURL = URL(fileURLWithPath: gitDirectory(for: root)).appendingPathComponent("HEAD")
        guard let head = try? String(contentsOf: headURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              !head.isEmpty else {
            return ""
        }
        let prefix = "ref: refs/heads/"
        if head.hasPrefix(prefix) {
            return String(head.dropFirst(prefix.count))
        }
        return String(head.prefix(12))
    }

    private static func originRemote(root: String) -> String {
        let configURL = URL(fileURLWithPath: gitDirectory(for: root)).appendingPathComponent("config")
        guard let config = try? String(contentsOf: configURL, encoding: .utf8) else {
            return ""
        }
        var inOrigin = false
        for rawLine in config.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                inOrigin = line == "[remote \"origin\"]"
                continue
            }
            if inOrigin, line.hasPrefix("url") {
                let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 { return parts[1] }
            }
        }
        return ""
    }

    private static func firstLine(_ output: ProcessOutput) -> String {
        firstLine(output.stdout)
    }

    private static func firstLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
    }

    private static func parsePR(_ text: String) -> (url: String, state: String, checks: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return ("", "Not opened", "No checks")
        }
        let object: [String: Any]
        if let array = json as? [[String: Any]] {
            guard let first = array.first else { return ("", "Not opened", "No checks") }
            object = first
        } else if let dictionary = json as? [String: Any] {
            object = dictionary
        } else {
            return ("", "Not opened", "No checks")
        }
        let url = object["url"] as? String ?? ""
        let state = object["state"] as? String ?? (url.isEmpty ? "Not opened" : "Unknown")
        let checks = object["statusCheckRollup"] as? [[String: Any]] ?? []
        if checks.isEmpty {
            return (url, state, "No checks")
        }
        let failed = checks.filter { ($0["conclusion"] as? String)?.lowercased() == "failure" }.count
        let pending = checks.filter { ($0["status"] as? String)?.lowercased() != "completed" }.count
        if failed > 0 { return (url, state, "\(failed) failing") }
        if pending > 0 { return (url, state, "\(pending) pending") }
        return (url, state, "\(checks.count) passing")
    }

    private static func githubSlug(from remote: String) -> String? {
        let trimmed = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let path: String
        if trimmed.hasPrefix("git@github.com:") {
            path = String(trimmed.dropFirst("git@github.com:".count))
        } else if let url = URL(string: trimmed), url.host?.lowercased() == "github.com" {
            path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else {
            return nil
        }
        let withoutSuffix = path.hasSuffix(".git") ? String(path.dropLast(4)) : path
        let parts = withoutSuffix.split(separator: "/")
        guard parts.count >= 2 else { return nil }
        return "\(parts[0])/\(parts[1])"
    }
}

struct UnattendedSetupStatus: Codable {
    var fileVaultStatus: String
    var autologinStatus: String
    var askForPassword: String
    var askForPasswordDelay: String
    var sleep: String
    var displaySleep: String
    var autorestart: String
    var warnings: [String]
    var updatedAt: Date
}

struct UnattendedApplyRequest: Codable {
    var loginPassword: String
    var allowSkipAutologin: Bool
}

struct UnattendedSetupResult: Codable {
    var ok: Bool
    var autologinSkipped: Bool
    var status: UnattendedSetupStatus
    var message: String
}

enum UnattendedSetupManager {
    static func status() -> UnattendedSetupStatus {
        let fileVault = ProcessRunner.run("/usr/bin/fdesetup", ["status"], timeout: 10).combinedTrimmed
        let autologin = ProcessRunner.run("/usr/sbin/sysadminctl", ["-autologin", "status"], timeout: 10).combinedTrimmed
        let askForPassword = defaultsValue(["-currentHost", "read", "com.apple.screensaver", "askForPassword"])
        let askForPasswordDelay = defaultsValue(["-currentHost", "read", "com.apple.screensaver", "askForPasswordDelay"])
        let pmset = ProcessRunner.run("/usr/bin/pmset", ["-g", "custom"], timeout: 10).combinedTrimmed
        var warnings: [String] = []
        if fileVault.localizedCaseInsensitiveContains("On") {
            warnings.append("FileVault is On. macOS autologin cannot be fully enabled until FileVault is disabled.")
        }
        if askForPassword == "0" {
            warnings.append("Screen lock password is disabled for unattended operation.")
        }
        return UnattendedSetupStatus(
            fileVaultStatus: fileVault.isEmpty ? "Unknown" : fileVault,
            autologinStatus: autologin.isEmpty ? "Unknown" : autologin,
            askForPassword: askForPassword,
            askForPasswordDelay: askForPasswordDelay,
            sleep: pmsetValue(" sleep", in: pmset),
            displaySleep: pmsetValue(" displaysleep", in: pmset),
            autorestart: pmsetValue(" autorestart", in: pmset),
            warnings: warnings,
            updatedAt: Date()
        )
    }

    static func apply(loginPassword: String, allowSkipAutologin: Bool = true) throws -> UnattendedSetupResult {
        let current = status()
        let fileVaultOn = current.fileVaultStatus.localizedCaseInsensitiveContains("On")
        let shouldSkipAutologin = fileVaultOn && allowSkipAutologin
        if fileVaultOn && !allowSkipAutologin {
            throw HostError.approvalRequired("FileVault is On. Disable FileVault first or allow skipping autologin.")
        }
        if !shouldSkipAutologin && loginPassword.isEmpty {
            throw HostError.badRequest("Login password is required to enable autologin.")
        }

        try runChecked("/usr/bin/defaults", ["-currentHost", "write", "com.apple.screensaver", "askForPassword", "-int", "0"])
        try runChecked("/usr/bin/defaults", ["-currentHost", "write", "com.apple.screensaver", "askForPasswordDelay", "-int", "0"])

        var scriptLines: [String] = []
        if !shouldSkipAutologin {
            scriptLines.append("/usr/sbin/sysadminctl -autologin set -userName \(shellQuoted(NSUserName())) -password \(shellQuoted(loginPassword))")
        }
        scriptLines.append("/usr/bin/pmset -a sleep 0 displaysleep 0")
        scriptLines.append("/usr/bin/pmset autorestart 1")
        try runAsAdmin(scriptLines.joined(separator: "\n"))

        let updated = status()
        let message = shouldSkipAutologin
            ? "Applied sleep, display, screen-lock, and autorestart settings. Autologin was skipped because FileVault is On."
            : "Applied autologin, sleep, display, screen-lock, and autorestart settings."
        return UnattendedSetupResult(ok: true, autologinSkipped: shouldSkipAutologin, status: updated, message: message)
    }

    static func revert() throws -> UnattendedSetupResult {
        try runChecked("/usr/bin/defaults", ["-currentHost", "write", "com.apple.screensaver", "askForPassword", "-int", "1"])
        try runAsAdmin([
            "/usr/sbin/sysadminctl -autologin off",
            "/usr/bin/pmset -a sleep 1 displaysleep 10",
            "/usr/bin/pmset autorestart 0"
        ].joined(separator: "\n"))
        let updated = status()
        return UnattendedSetupResult(ok: true, autologinSkipped: false, status: updated, message: "Reverted unattended operation settings.")
    }

    private static func defaultsValue(_ arguments: [String]) -> String {
        let output = ProcessRunner.run("/usr/bin/defaults", arguments, timeout: 10).combinedTrimmed
        return output.isEmpty ? "unset" : output
    }

    private static func pmsetValue(_ key: String, in text: String) -> String {
        for line in text.components(separatedBy: .newlines) where line.contains(key) {
            let tokens = line.split(whereSeparator: \.isWhitespace).map(String.init)
            if let value = tokens.last {
                return value
            }
        }
        return "unknown"
    }

    private static func runChecked(_ executable: String, _ arguments: [String]) throws {
        let output = ProcessRunner.run(executable, arguments, timeout: 20)
        guard output.exitCode == 0 else {
            throw HostError.badRequest(Redactor.redact(output.combinedTrimmed))
        }
    }

    private static func runAsAdmin(_ shellScript: String) throws {
        let script = "do shell script \(appleScriptQuoted(shellScript)) with administrator privileges"
        let output = ProcessRunner.run("/usr/bin/osascript", ["-e", script], timeout: 120)
        guard output.exitCode == 0 else {
            throw HostError.badRequest(Redactor.redact(output.combinedTrimmed))
        }
    }
}

struct MemoryFileRecord: Codable, Identifiable {
    var id: String
    var title: String
    var kind: String
    var path: String
    var relativePath: String
    var updatedAt: Date?
    var bytes: Int
    var isEditable: Bool
}

struct MemoryListResponse: Codable {
    var files: [MemoryFileRecord]
}

struct MemoryFileRequest: Codable {
    var id: String
}

struct MemoryWriteRequest: Codable {
    var id: String
    var content: String
}

struct MemoryFileContentResponse: Codable {
    var file: MemoryFileRecord
    var content: String
}

struct MemoryDiffResponse: Codable {
    var id: String
    var diff: String
    var hasChanges: Bool
}

struct MemoryWriteResponse: Codable {
    var file: MemoryFileRecord
    var diff: String
    var hasChanges: Bool
}

enum HistoryTool: String, Codable, CaseIterable {
    case claude
    case codex

    var title: String {
        switch self {
        case .claude:
            "Claude"
        case .codex:
            "Codex"
        }
    }
}

struct HistorySessionListRequest: Codable {
    var tool: HistoryTool?
    var project: String?
    var query: String?
    var date: String?
    var page: Int?
    var limit: Int?
}

struct HistorySessionDetailRequest: Codable {
    var id: String
    var tool: HistoryTool
}

struct HistorySessionSummary: Codable, Identifiable {
    var id: String
    var tool: HistoryTool
    var resumeID: String?
    var project: String
    var projectPath: String
    var startedAt: Date?
    var updatedAt: Date?
    var messageCount: Int
    var model: String?
    var summary: String
    var filePath: String
    var bytes: Int
}

struct HistorySessionListResponse: Codable {
    var sessions: [HistorySessionSummary]
    var total: Int
    var page: Int
    var limit: Int
    var projects: [String]
    var tools: [HistoryTool]
    var warnings: [String]
}

struct HistoryTurn: Codable, Identifiable {
    var id: String
    var role: String
    var kind: String
    var timestamp: Date?
    var text: String
    var metadata: String?
}

struct HistorySessionDetailResponse: Codable {
    var session: HistorySessionSummary
    var turns: [HistoryTurn]
    var truncated: Bool
}

struct HermesMemoryStore {
    private let memoriesFolder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".hermes/memories", isDirectory: true)
    private let skillsFolder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".hermes/skills", isDirectory: true)
    private let maxReadableBytes = 1_048_576

    func list() throws -> MemoryListResponse {
        var files = [
            record(id: "user", kind: "user", title: "USER.md", url: userURL, relativePath: "~/.hermes/memories/USER.md", isEditable: true),
            record(id: "memory", kind: "memory", title: "MEMORY.md", url: memoryURL, relativePath: "~/.hermes/memories/MEMORY.md", isEditable: true)
        ]
        files.append(contentsOf: skillRecords())
        return MemoryListResponse(files: files)
    }

    func read(id: String) throws -> MemoryFileContentResponse {
        let file = try fileRecord(for: id)
        guard file.bytes <= maxReadableBytes else {
            throw HostError.badRequest("Memory file is too large to edit safely.")
        }
        let url = try url(for: id)
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return MemoryFileContentResponse(file: file, content: content)
    }

    func diff(id: String, proposedContent: String) throws -> MemoryDiffResponse {
        let file = try fileRecord(for: id)
        let current = (try? String(contentsOf: try url(for: id), encoding: .utf8)) ?? ""
        let diffText = try unifiedDiff(original: current, proposed: proposedContent, label: file.relativePath)
        return MemoryDiffResponse(id: id, diff: diffText, hasChanges: current != proposedContent)
    }

    func write(id: String, content: String) throws -> MemoryWriteResponse {
        let existing = try fileRecord(for: id)
        guard existing.isEditable else {
            throw HostError.badRequest("This memory file is read-only.")
        }
        let diffResponse = try diff(id: id, proposedContent: content)
        let destination = try url(for: id)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: destination, options: .atomic)
        let updated = try fileRecord(for: id)
        return MemoryWriteResponse(file: updated, diff: diffResponse.diff, hasChanges: diffResponse.hasChanges)
    }

    private var userURL: URL {
        memoriesFolder.appendingPathComponent("USER.md")
    }

    private var memoryURL: URL {
        memoriesFolder.appendingPathComponent("MEMORY.md")
    }

    private func skillRecords() -> [MemoryFileRecord] {
        guard let enumerator = FileManager.default.enumerator(
            at: skillsFolder,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        var records: [MemoryFileRecord] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "md",
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true,
                  let relative = relativeSkillPath(for: url) else {
                continue
            }
            records.append(record(
                id: "skill:\(relative)",
                kind: "skill",
                title: url.lastPathComponent,
                url: url,
                relativePath: "~/.hermes/skills/\(relative)",
                isEditable: true
            ))
        }
        return records.sorted { $0.relativePath < $1.relativePath }
    }

    private func fileRecord(for id: String) throws -> MemoryFileRecord {
        switch id {
        case "user":
            return record(id: id, kind: "user", title: "USER.md", url: userURL, relativePath: "~/.hermes/memories/USER.md", isEditable: true)
        case "memory":
            return record(id: id, kind: "memory", title: "MEMORY.md", url: memoryURL, relativePath: "~/.hermes/memories/MEMORY.md", isEditable: true)
        default:
            guard id.hasPrefix("skill:") else {
                throw HostError.notFound("Unknown memory file")
            }
            let relative = String(id.dropFirst("skill:".count))
            let url = try skillURL(relativePath: relative)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw HostError.notFound("Skill memory file not found")
            }
            return record(id: id, kind: "skill", title: url.lastPathComponent, url: url, relativePath: "~/.hermes/skills/\(relative)", isEditable: true)
        }
    }

    private func url(for id: String) throws -> URL {
        switch id {
        case "user":
            return userURL
        case "memory":
            return memoryURL
        default:
            guard id.hasPrefix("skill:") else {
                throw HostError.notFound("Unknown memory file")
            }
            return try skillURL(relativePath: String(id.dropFirst("skill:".count)))
        }
    }

    private func skillURL(relativePath: String) throws -> URL {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              relativePath.pathExtensionLowercased == "md",
              !relativePath.split(separator: "/").contains("..") else {
            throw HostError.badRequest("Invalid skill memory path")
        }
        let url = skillsFolder.appendingPathComponent(relativePath)
        let standardized = url.standardizedFileURL.path
        guard standardized.hasPrefix(skillsFolder.standardizedFileURL.path + "/") else {
            throw HostError.badRequest("Skill path escapes ~/.hermes/skills")
        }
        return url
    }

    private func record(id: String, kind: String, title: String, url: URL, relativePath: String, isEditable: Bool) -> MemoryFileRecord {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        return MemoryFileRecord(
            id: id,
            title: title,
            kind: kind,
            path: url.path,
            relativePath: relativePath,
            updatedAt: values?.contentModificationDate,
            bytes: values?.fileSize ?? 0,
            isEditable: isEditable
        )
    }

    private func relativeSkillPath(for url: URL) -> String? {
        let base = skillsFolder.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(base + "/") else { return nil }
        return String(path.dropFirst(base.count + 1))
    }

    private func unifiedDiff(original: String, proposed: String, label: String) throws -> String {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("VeqralMemoryDiff-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let before = folder.appendingPathComponent("before.md")
        let after = folder.appendingPathComponent("after.md")
        try Data(original.utf8).write(to: before, options: .atomic)
        try Data(proposed.utf8).write(to: after, options: .atomic)
        let output = ProcessRunner.run("/usr/bin/diff", ["-u", before.path, after.path], timeout: 20)
        if output.exitCode > 1 {
            throw HostError.badRequest(output.combinedTrimmed)
        }
        var lines = output.stdout.components(separatedBy: .newlines)
        if lines.indices.contains(0) {
            lines[0] = "--- \(label)"
        }
        if lines.indices.contains(1) {
            lines[1] = "+++ \(label) (proposed)"
        }
        return lines.joined(separator: "\n")
    }
}

struct AgentHistoryStore {
    private let fileManager = FileManager.default
    private let listMaxFiles = 240
    private let listScanLines = 160
    private let listScanBytes = 196_608
    private let detailScanLines = 5_000
    private let detailScanBytes = 8_000_000

    func list(_ request: HistorySessionListRequest) throws -> HistorySessionListResponse {
        let page = max(0, request.page ?? 0)
        let limit = min(max(1, request.limit ?? 50), 100)
        let query = request.query?.trimmingCharacters(in: .whitespacesAndNewlines)
        let warnings = historyWarnings(for: request.tool)
        var sessions = try allSessions(tool: request.tool)

        if let project = request.project, !project.isEmpty {
            sessions = sessions.filter { $0.project == project || $0.projectPath == project }
        }

        if let date = request.date, !date.isEmpty {
            sessions = sessions.filter { session in
                guard let startedAt = session.startedAt ?? session.updatedAt else { return false }
                return Self.dayFormatter.string(from: startedAt) == date
            }
        }

        if let query, !query.isEmpty {
            let folded = query.lowercased()
            sessions = sessions.filter { session in
                let visible = "\(session.tool.rawValue) \(session.project) \(session.projectPath) \(session.summary) \(session.model ?? "")".lowercased()
                return visible.contains(folded) || fileContains(session.filePath, query: folded)
            }
        }

        sessions.sort {
            ($0.startedAt ?? $0.updatedAt ?? .distantPast) > ($1.startedAt ?? $1.updatedAt ?? .distantPast)
        }
        let total = sessions.count
        let projects = Array(Set(sessions.map(\.project).filter { !$0.isEmpty })).sorted()
        let start = min(page * limit, total)
        let end = min(start + limit, total)
        let pageItems = start < end ? Array(sessions[start..<end]) : []

        return HistorySessionListResponse(
            sessions: pageItems,
            total: total,
            page: page,
            limit: limit,
            projects: projects,
            tools: HistoryTool.allCases,
            warnings: warnings
        )
    }

    func detail(_ request: HistorySessionDetailRequest) throws -> HistorySessionDetailResponse {
        guard let sessionFile = sessionFile(id: request.id, tool: request.tool),
              let session = summarize(url: sessionFile.url, tool: request.tool, fallbackProject: sessionFile.fallbackProject) else {
            throw HostError.notFound("History session not found")
        }
        let url = URL(fileURLWithPath: session.filePath)
        var turns: [HistoryTurn] = []
        var truncated = false
        var lineNumber = 0

        try HistoryLineReader.forEachLine(url: url, maxLines: detailScanLines, maxBytes: detailScanBytes) { line in
            lineNumber += 1
            let fallbackID = "\(session.id)-\(lineNumber)"
            guard let object = HistoryJSON.object(from: line) else {
                if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    turns.append(rawTurn(line: line, fallbackID: fallbackID, reason: "Unrecognized \(request.tool.title) history record: invalid JSONL"))
                }
                return
            }
            if let turn = turn(from: object, tool: request.tool, fallbackID: fallbackID) {
                turns.append(turn)
            } else if !shouldSkipUnknownRecord(object, tool: request.tool) {
                turns.append(rawTurn(line: line, fallbackID: fallbackID, reason: unknownRecordReason(object, tool: request.tool)))
            }
        } onTruncated: {
            truncated = true
        }

        return HistorySessionDetailResponse(session: session, turns: turns, truncated: truncated)
    }

    private func allSessions(tool: HistoryTool?) throws -> [HistorySessionSummary] {
        switch tool {
        case .claude:
            return claudeSessions()
        case .codex:
            return codexSessions()
        case nil:
            return claudeSessions() + codexSessions()
        }
    }

    private func sessionFile(id: String, tool: HistoryTool) -> (url: URL, fallbackProject: String)? {
        switch tool {
        case .claude:
            for root in claudeProjectRoots() {
                for url in jsonlFiles(under: root, limit: listMaxFiles) where Self.identifier(for: url) == id {
                    return (url, decodeClaudeProject(url.deletingLastPathComponent().lastPathComponent))
                }
            }
        case .codex:
            for root in codexSessionRoots() {
                for url in jsonlFiles(under: root, limit: listMaxFiles) where Self.identifier(for: url) == id {
                    return (url, "Codex")
                }
            }
        }
        return nil
    }

    private func claudeSessions() -> [HistorySessionSummary] {
        let roots = claudeProjectRoots()
        let perRootLimit = max(1, listMaxFiles / max(1, roots.count))
        return roots.flatMap { root in
            jsonlFiles(under: root, limit: perRootLimit).compactMap { url in
                summarize(url: url, tool: .claude, fallbackProject: decodeClaudeProject(url.deletingLastPathComponent().lastPathComponent))
            }
        }
    }

    private func codexSessions() -> [HistorySessionSummary] {
        let roots = codexSessionRoots()
        let perRootLimit = max(1, listMaxFiles / max(1, roots.count))
        return roots.flatMap { jsonlFiles(under: $0, limit: perRootLimit) }
            .compactMap { summarize(url: $0, tool: .codex, fallbackProject: "Codex") }
    }

    private func historyWarnings(for tool: HistoryTool?) -> [String] {
        var warnings: [String] = []
        if tool == nil || tool == .codex {
            let roots = codexSessionRoots()
            if !roots.contains(where: { fileManager.fileExists(atPath: $0.path) }) {
                warnings.append("Codex history directory not found. Checked: \(roots.map(\.path).joined(separator: ", "))")
            }
        }
        if tool == nil || tool == .claude {
            let roots = claudeProjectRoots()
            if !roots.contains(where: { fileManager.fileExists(atPath: $0.path) }) {
                warnings.append("Claude history directory not found. Checked: \(roots.map(\.path).joined(separator: ", "))")
            }
        }
        return warnings
    }

    private func codexSessionRoots() -> [URL] {
        let defaultHome = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
        var homes: [URL] = []
        if let envHome = ProcessInfo.processInfo.environment["CODEX_HOME"]?.nilIfBlank {
            homes.append(URL(fileURLWithPath: envHome.expandingTilde, isDirectory: true))
        }
        if !homes.contains(where: { $0.standardizedFileURL.path == defaultHome.standardizedFileURL.path }) {
            homes.append(defaultHome)
        }
        return uniqueURLs(homes.flatMap {
            [
                $0.appendingPathComponent("sessions", isDirectory: true),
                $0.appendingPathComponent("archived_sessions", isDirectory: true)
            ]
        })
    }

    private func claudeProjectRoots() -> [URL] {
        let defaultRoot = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects", isDirectory: true)
        var roots: [URL] = []
        if let configDir = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"]?.nilIfBlank {
            roots.append(URL(fileURLWithPath: configDir.expandingTilde, isDirectory: true).appendingPathComponent("projects", isDirectory: true))
        }
        if let homeDir = ProcessInfo.processInfo.environment["CLAUDE_HOME"]?.nilIfBlank {
            roots.append(URL(fileURLWithPath: homeDir.expandingTilde, isDirectory: true).appendingPathComponent("projects", isDirectory: true))
        }
        roots.append(defaultRoot)
        return uniqueURLs(roots)
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { url in
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { return false }
            seen.insert(path)
            return true
        }
    }

    private func jsonlFiles(under root: URL, limit: Int) -> [URL] {
        guard fileManager.fileExists(atPath: root.path),
              let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
              ) else {
            return []
        }
        var files: [(url: URL, date: Date)] = []
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "jsonl" {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            files.append((url, date))
        }
        return files.sorted { $0.date > $1.date }.prefix(limit).map(\.url)
    }

    private func summarize(url: URL, tool: HistoryTool, fallbackProject: String) -> HistorySessionSummary? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        var startedAt: Date?
        var projectPath = ""
        var model: String?
        var summary = ""
        var messageCount = 0

        do {
            try HistoryLineReader.forEachLine(url: url, maxLines: listScanLines, maxBytes: listScanBytes) { line in
                guard let object = HistoryJSON.object(from: line) else { return }
                if startedAt == nil {
                    startedAt = HistoryJSON.date(in: object)
                }
                if projectPath.isEmpty {
                    projectPath = HistoryJSON.projectPath(in: object, tool: tool)
                }
                if model == nil {
                    model = HistoryJSON.model(in: object)
                }
                if let turn = turn(from: object, tool: tool, fallbackID: "") {
                    messageCount += 1
                    if summary.isEmpty, turn.role == "user" {
                        summary = turn.text
                    }
                }
            }
        } catch {
            return nil
        }

        if startedAt == nil {
            startedAt = dateFromCodexFilename(url.lastPathComponent) ?? values?.contentModificationDate
        }
        if projectPath.isEmpty {
            projectPath = fallbackProject
        }
        if summary.isEmpty {
            summary = url.deletingPathExtension().lastPathComponent
        }

        return HistorySessionSummary(
            id: Self.identifier(for: url),
            tool: tool,
            resumeID: resumeIdentifier(for: url, tool: tool),
            project: projectName(from: projectPath, fallback: fallbackProject),
            projectPath: projectPath,
            startedAt: startedAt,
            updatedAt: values?.contentModificationDate,
            messageCount: messageCount,
            model: model,
            summary: clipped(Redactor.redact(summary), limit: 240),
            filePath: url.path,
            bytes: values?.fileSize ?? 0
        )
    }

    private func resumeIdentifier(for url: URL, tool: HistoryTool) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        switch tool {
        case .claude:
            return stem
        case .codex:
            if let range = stem.range(
                of: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#,
                options: .regularExpression
            ) {
                return String(stem[range])
            }
            return stem
        }
    }

    private func turn(from object: [String: Any], tool: HistoryTool, fallbackID: String) -> HistoryTurn? {
        switch tool {
        case .claude:
            return claudeTurn(from: object, fallbackID: fallbackID)
        case .codex:
            return codexTurn(from: object, fallbackID: fallbackID)
        }
    }

    private func claudeTurn(from object: [String: Any], fallbackID: String) -> HistoryTurn? {
        guard let type = object["type"] as? String else { return nil }
        let uuid = (object["uuid"] as? String) ?? fallbackID
        let timestamp = HistoryJSON.date(in: object)

        if type == "user" || type == "assistant" {
            guard let message = object["message"] as? [String: Any] else { return nil }
            let text = HistoryJSON.contentText(message["content"])
            guard !text.isEmpty, object["isMeta"] as? Bool != true else { return nil }
            return HistoryTurn(id: uuid, role: type, kind: "message", timestamp: timestamp, text: clipped(Redactor.redact(text), limit: 14_000), metadata: nil)
        }

        if type == "tool_use" || type == "tool_result" || type == "attachment" {
            let text = HistoryJSON.contentText(object["message"] ?? object["attachment"] ?? object)
            guard !text.isEmpty else { return nil }
            return HistoryTurn(id: uuid, role: "tool", kind: type, timestamp: timestamp, text: clipped(Redactor.redact(text), limit: 8_000), metadata: type)
        }

        return nil
    }

    private func codexTurn(from object: [String: Any], fallbackID: String) -> HistoryTurn? {
        let timestamp = HistoryJSON.date(in: object)
        guard let type = object["type"] as? String else { return nil }
        if type == "session_meta" { return nil }

        if let payload = object["payload"] as? [String: Any] {
            let payloadType = payload["type"] as? String
            if payloadType == "message" {
                let role = payload["role"] as? String ?? "assistant"
                let text = HistoryJSON.contentText(payload["content"])
                guard !text.isEmpty else { return nil }
                return HistoryTurn(id: fallbackID, role: role, kind: "message", timestamp: timestamp, text: clipped(Redactor.redact(text), limit: 14_000), metadata: nil)
            }
            if payloadType == "function_call" || payloadType == "tool_call" || type == "event_msg" {
                let text = HistoryJSON.contentText(payload)
                guard !text.isEmpty else { return nil }
                return HistoryTurn(id: fallbackID, role: "tool", kind: payloadType ?? type, timestamp: timestamp, text: clipped(Redactor.redact(text), limit: 8_000), metadata: payloadType ?? type)
            }
        }

        if type == "response_item", let text = object["text"] as? String, !text.isEmpty {
            return HistoryTurn(id: fallbackID, role: "assistant", kind: "message", timestamp: timestamp, text: clipped(Redactor.redact(text), limit: 14_000), metadata: nil)
        }

        return nil
    }

    private func rawTurn(line: String, fallbackID: String, reason: String) -> HistoryTurn {
        HistoryTurn(
            id: fallbackID,
            role: "unknown",
            kind: "raw",
            timestamp: nil,
            text: clipped(Redactor.redact(line), limit: 8_000),
            metadata: reason
        )
    }

    private func shouldSkipUnknownRecord(_ object: [String: Any], tool: HistoryTool) -> Bool {
        if tool == .codex, object["type"] as? String == "session_meta" {
            return true
        }
        if tool == .claude, object["isMeta"] as? Bool == true {
            return true
        }
        return false
    }

    private func unknownRecordReason(_ object: [String: Any], tool: HistoryTool) -> String {
        if let type = object["type"] as? String {
            return "Unrecognized \(tool.title) history record: \(type)"
        }
        if let payload = object["payload"] as? [String: Any],
           let type = payload["type"] as? String {
            return "Unrecognized \(tool.title) history payload: \(type)"
        }
        return "Unrecognized \(tool.title) history record schema"
    }

    private func fileContains(_ path: String, query: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        var found = false
        try? HistoryLineReader.forEachLine(url: url, maxLines: 5_000, maxBytes: 5_000_000) { line in
            if line.lowercased().contains(query) {
                found = true
            }
        }
        return found
    }

    private func decodeClaudeProject(_ folderName: String) -> String {
        guard folderName.hasPrefix("-") else { return folderName }
        return "/" + folderName.dropFirst().replacingOccurrences(of: "-", with: "/")
    }

    private func projectName(from path: String, fallback: String) -> String {
        let clean = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return fallback }
        let name = URL(fileURLWithPath: clean).lastPathComponent
        return name.isEmpty ? clean : name
    }

    private func dateFromCodexFilename(_ name: String) -> Date? {
        guard let range = name.range(of: #"rollout-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}"#, options: .regularExpression) else {
            return nil
        }
        let raw = String(name[range]).replacingOccurrences(of: "rollout-", with: "")
        let parts = raw.split(separator: "T", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        let time = parts[1].replacingOccurrences(of: "-", with: ":")
        return ISO8601DateFormatter().date(from: "\(parts[0])T\(time)Z")
    }

    private func clipped(_ value: String, limit: Int) -> String {
        if value.count <= limit { return value }
        return String(value.prefix(limit)) + "\n[truncated]"
    }

    private static func identifier(for url: URL) -> String {
        SHA256.hash(data: Data(url.path.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

}

enum HistoryJSON {
    static func object(from line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    static func date(in object: [String: Any]) -> Date? {
        if let timestamp = object["timestamp"] as? String {
            return parseDate(timestamp)
        }
        if let timestamp = object["timestamp"] as? Double {
            return Date(timeIntervalSince1970: timestamp > 10_000_000_000 ? timestamp / 1000 : timestamp)
        }
        if let payload = object["payload"] as? [String: Any] {
            if let timestamp = payload["timestamp"] as? String {
                return parseDate(timestamp)
            }
            if let startedAt = payload["started_at"] as? Double {
                return Date(timeIntervalSince1970: startedAt)
            }
        }
        return nil
    }

    static func projectPath(in object: [String: Any], tool: HistoryTool) -> String {
        if let cwd = object["cwd"] as? String { return cwd }
        if let project = object["project"] as? String { return project }
        if let payload = object["payload"] as? [String: Any] {
            if let cwd = payload["cwd"] as? String { return cwd }
            if let project = payload["project"] as? String { return project }
        }
        if tool == .codex,
           let payload = object["payload"] as? [String: Any],
           let meta = payload["payload"] as? [String: Any],
           let cwd = meta["cwd"] as? String {
            return cwd
        }
        return ""
    }

    static func model(in object: [String: Any]) -> String? {
        if let model = object["model"] as? String { return model }
        if let version = object["version"] as? String { return version }
        if let payload = object["payload"] as? [String: Any] {
            if let model = payload["model"] as? String { return model }
            if let model = payload["model_provider"] as? String { return model }
            if let version = payload["cli_version"] as? String { return version }
        }
        return nil
    }

    static func contentText(_ value: Any?) -> String {
        guard let value else { return "" }
        if let string = value as? String {
            return string
        }
        if let array = value as? [Any] {
            return array.map(contentText).filter { !$0.isEmpty }.joined(separator: "\n")
        }
        if let dict = value as? [String: Any] {
            if let text = dict["text"] as? String { return text }
            if let content = dict["content"] { return contentText(content) }
            if let name = dict["name"] as? String, let arguments = dict["arguments"] {
                return "\(name)\n\(contentText(arguments))"
            }
            if JSONSerialization.isValidJSONObject(dict),
               let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
               let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        return String(describing: value)
    }

    private static func parseDate(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) { return date }
        return ISO8601DateFormatter().date(from: text)
    }
}

enum HistoryLineReader {
    static func forEachLine(
        url: URL,
        maxLines: Int,
        maxBytes: Int,
        handle: (String) throws -> Void,
        onTruncated: (() -> Void)? = nil
    ) throws {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var pending = Data()
        var lines = 0
        var bytes = 0

        while bytes < maxBytes, lines < maxLines {
            let chunk = file.readData(ofLength: min(64 * 1024, maxBytes - bytes))
            if chunk.isEmpty { break }
            bytes += chunk.count
            pending.append(chunk)

            while let newline = pending.firstIndex(of: 10), lines < maxLines {
                let lineData = pending.subdata(in: pending.startIndex..<newline)
                pending.removeSubrange(pending.startIndex...newline)
                if let line = String(data: lineData, encoding: .utf8) {
                    try handle(line)
                }
                lines += 1
            }
        }

        if !pending.isEmpty, lines < maxLines, bytes < maxBytes,
           let line = String(data: pending, encoding: .utf8) {
            try handle(line)
        } else if bytes >= maxBytes || lines >= maxLines {
            onTruncated?()
        }
    }
}

struct ProcessOutput {
    var exitCode: Int32
    var stdout: String
    var stderr: String

    var combinedTrimmed: String {
        [stdout, stderr]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ProcessRunner {
    static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 30) -> ProcessOutput {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.currentDirectoryURL = URL(fileURLWithPath: "/")
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return ProcessOutput(exitCode: 127, stdout: "", stderr: error.localizedDescription)
        }

        let stdoutFD = stdout.fileHandleForReading.fileDescriptor
        let stderrFD = stderr.fileHandleForReading.fileDescriptor
        setNonBlocking(stdoutFD)
        setNonBlocking(stderrFD)
        var stdoutData = Data()
        var stderrData = Data()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            readAvailable(from: stdoutFD, into: &stdoutData)
            readAvailable(from: stderrFD, into: &stderrData)
            if Date() >= deadline {
                process.terminate()
                Thread.sleep(forTimeInterval: 0.2)
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        process.waitUntilExit()
        readAvailable(from: stdoutFD, into: &stdoutData)
        readAvailable(from: stderrFD, into: &stderrData)
        return ProcessOutput(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }

    private static func setNonBlocking(_ fd: Int32) {
        let flags = fcntl(fd, F_GETFL, 0)
        if flags >= 0 {
            _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        }
    }

    private static func readAvailable(from fd: Int32, into data: inout Data) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let readCount = Darwin.read(fd, &buffer, buffer.count)
            if readCount > 0 {
                data.append(buffer, count: readCount)
            } else {
                break
            }
        }
    }
}

struct HTTPRequest {
    var method: String
    var path: String
    var headers: [String: String]
    var body: Data

    static func parse(_ data: Data) -> HTTPRequest? {
        guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = data.subdata(in: data.startIndex..<headerRange.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let first = lines.first else { return nil }
        let parts = first.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let pair = line.split(separator: ":", maxSplits: 1).map(String.init)
            if pair.count == 2 {
                headers[pair[0].lowercased()] = pair[1].trimmingCharacters(in: .whitespaces)
            }
        }
        let bodyStart = headerRange.upperBound
        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        guard data.count >= bodyStart + contentLength else { return nil }
        let body = data.subdata(in: bodyStart..<(bodyStart + contentLength))
        let rawPath = parts[1].split(separator: "?", maxSplits: 1).first.map(String.init) ?? parts[1]
        return HTTPRequest(method: parts[0], path: rawPath, headers: headers, body: body)
    }
}

enum WebSocketFrame {
    static func sendText(_ text: String, connection: NWConnection) {
        let payload = Data(text.utf8)
        var frame = Data([0x81])
        if payload.count < 126 {
            frame.append(UInt8(payload.count))
        } else if payload.count <= UInt16.max {
            frame.append(126)
            frame.append(UInt8((payload.count >> 8) & 0xff))
            frame.append(UInt8(payload.count & 0xff))
        } else {
            frame.append(127)
            let count = UInt64(payload.count)
            for shift in stride(from: 56, through: 0, by: -8) {
                frame.append(UInt8((count >> UInt64(shift)) & 0xff))
            }
        }
        frame.append(payload)
        connection.send(content: frame, contentContext: .defaultStream, isComplete: false, completion: .contentProcessed { _ in })
    }
}

struct HealthResponse: Codable {
    var status: String
    var host: String
    var tailscaleIP: String?
    var port: UInt16
    var hermesVersion: String
    var toolStatuses: [CLIToolStatus]
}

struct PairingStatus: Codable {
    var pairingCode: String
    var pairingURL: String
}

struct PairRequest: Codable {
    var deviceName: String
    var pairingCode: String
}

struct PairResponse: Codable {
    var deviceID: String
    var token: String
}

struct CreateRunRequest: Codable {
    var prompt: String
    var workingDirectory: String
    var engine: AgentEngine?
    var resumeSessionID: String?
    var projectID: String?
    var chatID: String?
    var provider: String?
    var model: String?
    var attachments: [RunAttachmentUpload]?
}

struct RunAttachmentUpload: Codable {
    var id: UUID
    var fileName: String
    var mimeType: String
    var data: Data
}

struct CreateRunResponse: Codable {
    var runID: String
    var sessionID: String?
    var status: String
    var approvalRequired: Bool
    var approvalReason: String?
}

struct RunListResponse: Codable {
    var runs: [HostRun]
}

struct RunLogResponse: Codable {
    var logs: [HostLogEvent]
}

struct RunSnapshotResponse: Codable {
    var run: HostRun
    var logs: [HostLogEvent]
    var diff: [GitDiffEntry]
    var artifacts: [HostArtifact]
}

struct DeviceListResponse: Codable {
    var devices: [DeviceRecord]
}

struct AuditLogResponse: Codable {
    var lines: [String]
}

struct GitDiffEntry: Codable {
    var path: String
    var additions: Int
    var deletions: Int
}

struct GitDiffResponse: Codable {
    var files: [GitDiffEntry]
}

struct HostArtifact: Codable, Identifiable {
    var id: String
    var title: String
    var type: String
    var path: String
    var bytes: Int
    var updatedAt: Date?
}

struct ArtifactListResponse: Codable {
    var artifacts: [HostArtifact]
}

struct GitHubStatusRequest: Codable {
    var workingDirectory: String
}

struct GitHubStatusResponse: Codable {
    var workingDirectory: String
    var gitRoot: String
    var branch: String
    var remote: String
    var changedFiles: Int
    var aheadBehind: String
    var ghAuthenticated: Bool
    var pullRequestURL: String
    var pullRequestState: String
    var checksSummary: String
    var error: String?
}

struct CreateDraftPRRequest: Codable {
    var workingDirectory: String
    var title: String
    var body: String
}

struct CreateDraftPRResponse: Codable {
    var ok: Bool
    var url: String
}

struct SimpleResponse: Codable {
    var ok: Bool
}

struct ErrorResponse: Codable {
    var error: String
}

enum HostError: Error, CustomStringConvertible {
    case badRequest(String)
    case unauthorized(String)
    case notFound(String)
    case approvalRequired(String)

    var description: String {
        switch self {
        case .badRequest(let message), .unauthorized(let message), .notFound(let message), .approvalRequired(let message):
            return message
        }
    }

    var httpStatus: String {
        switch self {
        case .badRequest: "400 Bad Request"
        case .unauthorized: "401 Unauthorized"
        case .notFound: "404 Not Found"
        case .approvalRequired: "409 Conflict"
        }
    }
}

struct RiskResult {
    var requiresApproval: Bool
    var reason: String
}

enum RiskClassifier {
    static func classify(_ prompt: String) -> RiskResult {
        let lower = prompt.lowercased()
        let highRisk = [
            "rm ", "delete", "remove file", "git clean", "reset --hard", "branch -d", "branch -D",
            "force push", "push main", "merge main", "deploy production", "production deploy",
            ".env", "secret", "token", "private key", "keychain", "billing", "stripe", "payment",
            "computer use", "screen control"
        ]
        if let hit = highRisk.first(where: { lower.contains($0.lowercased()) }) {
            return RiskResult(requiresApproval: true, reason: "Approval required for \(hit)")
        }
        return RiskResult(requiresApproval: false, reason: "auto")
    }
}

enum Redactor {
    static func redact(_ text: String) -> String {
        var output = text
        let patterns = [
            (#"(?i)(authorization:\s*bearer\s+)[A-Za-z0-9._\-]+"#, "$1[REDACTED]"),
            (#"(?i)(token|api[_-]?key|secret|password)\s*[:=]\s*['"]?[^'"\s]+"#, "$1=[REDACTED]"),
            (#"(?i)sk-[A-Za-z0-9]{12,}"#, "[REDACTED]"),
            (#"(?i)gh[opusr]_[A-Za-z0-9_]+"#, "[REDACTED]"),
            (#"(?i)github_pat_[A-Za-z0-9_]+"#, "[REDACTED]")
        ]
        for (pattern, replacement) in patterns {
            output = output.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return output
    }
}

enum SessionParser {
    static func sessionID(from line: String) -> String? {
        let patterns = [
            #"session_id:\s*([A-Za-z0-9_\-]+)"#,
            #"Session ID:\s*([A-Za-z0-9_\-]+)"#,
            #""session_id"\s*:\s*"([A-Za-z0-9_\-]+)""#,
            #""sessionId"\s*:\s*"([A-Za-z0-9_\-]+)""#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = regex.firstMatch(in: line, range: range),
               let idRange = Range(match.range(at: 1), in: line) {
                return String(line[idRange])
            }
        }
        return nil
    }
}

enum HMACSigner {
    static func signature(token: String, method: String, path: String, timestamp: String, body: Data) -> String {
        let bodyHash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        let canonical = "\(method)\n\(path)\n\(timestamp)\n\(bodyHash)"
        let key = SymmetricKey(data: Data(token.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(canonical.utf8), using: key)
        return Data(signature).base64EncodedString()
    }
}

enum KeychainStore {
    static func set(_ value: String, account: String) throws {
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8)
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw HostError.badRequest("Keychain write failed: \(status)")
        }
    }

    static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private func websocketAccept(_ key: String) -> String {
    let digest = Insecure.SHA1.hash(data: Data((key + serverGUID).utf8))
    return Data(digest).base64EncodedString()
}

private func secureCompare(_ lhs: String, _ rhs: String) -> Bool {
    let left = Array(lhs.utf8)
    let right = Array(rhs.utf8)
    guard left.count == right.count else { return false }
    var diff: UInt8 = 0
    for index in left.indices {
        diff |= left[index] ^ right[index]
    }
    return diff == 0
}

private func randomToken() -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    return Data(bytes).base64EncodedString()
}

private func tailscaleIP() -> String? {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.currentDirectoryURL = URL(fileURLWithPath: "/")
    process.arguments = ["-lc", "command -v tailscale >/dev/null 2>&1 && tailscale ip -4 | head -n 1"]
    process.standardOutput = pipe
    try? process.run()
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    return value?.isEmpty == false ? value : nil
}

private func localHostName() -> String {
    ProcessInfo.processInfo.hostName
}

private func shellQuoted(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
}

private func appleScriptQuoted(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
}

private extension String {
    var expandingTilde: String {
        NSString(string: self).expandingTildeInPath
    }

    var pathExtensionLowercased: String {
        NSString(string: self).pathExtension.lowercased()
    }

    var urlQueryEscaped: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~:/")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }

    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension JSONEncoder {
    static var dates: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static var pretty: JSONEncoder {
        let encoder = dates
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var dates: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
