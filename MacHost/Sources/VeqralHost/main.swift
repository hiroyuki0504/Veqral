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

    func createRun(prompt: String, workingDirectory: String) throws -> HostRun {
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
        let run = HostRun(
            id: UUID().uuidString,
            prompt: prompt,
            workingDirectory: directory,
            sessionID: nil,
            status: approvalReason == nil ? .queued : .waitingApproval,
            startedAt: Date(),
            completedAt: nil,
            exitCode: nil,
            pid: nil,
            approvalReason: approvalReason
        )
        runs[run.id] = run
        persistRuns()
        if let approvalReason {
            appendAudit("created approval run id=\(run.id) dir=\(directory) reason=\(approvalReason)")
            publish(HostLogEvent(runID: run.id, kind: .approval, stream: "approval", message: approvalReason, createdAt: Date()))
        } else {
            appendAudit("created run id=\(run.id) dir=\(directory)")
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
        if let pid = processes[runID] {
            kill(pid, SIGTERM)
            usleep(200_000)
            kill(pid, SIGKILL)
        }
        if var run = runs[runID] {
            run.status = .cancelled
            run.completedAt = Date()
            run.pid = nil
            runs[runID] = run
        }
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
    private let runner: HermesRunner
    private let memoryStore = HermesMemoryStore()
    private let connectionLock = NSLock()
    private var activeConnections: [ObjectIdentifier: NWConnection] = [:]

    init(config: HostConfig, state: HostState) throws {
        self.config = config
        self.state = state
        self.listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: config.port)!)
        self.runner = HermesRunner(state: state)
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
                let response = HealthResponse(
                    status: "ok",
                    host: localHostName(),
                    tailscaleIP: tailscaleIP(),
                    port: config.port,
                    hermesVersion: HermesRunner.hermesVersion()
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
                let run = try await state.createRun(prompt: body.prompt, workingDirectory: body.workingDirectory)
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

final class HermesRunner {
    private let state: HostState

    init(state: HostState) {
        self.state = state
    }

    static func hermesPath() -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.local/bin/hermes",
            "\(home)/.hermes/hermes-agent/venv/bin/hermes",
            "/opt/homebrew/bin/hermes",
            "/usr/local/bin/hermes"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func hermesVersion() -> String {
        guard let path = hermesPath() else { return "Not installed" }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Installed"
    }

    func start(runID: String) async {
        guard let run = await state.run(runID: runID) else { return }
        guard let hermes = Self.hermesPath() else {
            await state.appendLog(runID: runID, stream: "error", message: "Hermes is not installed")
            await state.finish(runID: runID, exitCode: 127)
            return
        }
        let prompt = """
        You are Hermes Agent running under Veqral Mac Host.
        Use Codex CLI and other configured CLI tools through Hermes when useful.
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
            "--source", "veqral",
            "--checkpoints",
            "--worktree",
            "--pass-session-id",
            "--toolsets", "terminal,file,skills,memory,browser",
            "--max-turns", "40"
        ]
        if let sessionID = run.sessionID {
            args.append(contentsOf: ["--resume", sessionID])
        }
        args.append(contentsOf: [
            "-q", prompt
        ])
        await PTYProcess.run(
            executable: hermes,
            arguments: args,
            workingDirectory: run.workingDirectory,
            runID: runID,
            state: state
        )
    }
}

enum PTYProcess {
    static func run(executable: String, arguments: [String], workingDirectory: String, runID: String, state: HostState) async {
        var master: Int32 = -1
        var slave: Int32 = -1
        guard openpty(&master, &slave, nil, nil, nil) == 0 else {
            await state.appendLog(runID: runID, stream: "error", message: "Failed to open PTY")
            await state.finish(runID: runID, exitCode: 127)
            return
        }
        defer {
            close(master)
            close(slave)
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
        if status != 0 {
            await state.appendLog(runID: runID, stream: "error", message: "Failed to spawn Hermes: \(status)")
            await state.finish(runID: runID, exitCode: 127)
            return
        }
        await state.markStarted(runID: runID, pid: pid)
        setNonBlocking(master)

        var waitStatus: Int32 = 0
        var lineBuffer = Data()
        while true {
            await readAvailable(master: master, buffer: &lineBuffer, runID: runID, state: state)
            let result = waitpid(pid, &waitStatus, WNOHANG)
            if result == pid {
                await readAvailable(master: master, buffer: &lineBuffer, runID: runID, state: state)
                if !lineBuffer.isEmpty {
                    let text = String(data: lineBuffer, encoding: .utf8) ?? ""
                    await state.appendLog(runID: runID, stream: "pty", message: text)
                }
                await state.finish(runID: runID, exitCode: exitCode(from: waitStatus))
                break
            }
            if result == -1 {
                await state.finish(runID: runID, exitCode: 1)
                break
            }
            usleep(50_000)
        }
    }

    private static func readAvailable(master: Int32, buffer: inout Data, runID: String, state: HostState) async {
        var temp = [UInt8](repeating: 0, count: 4096)
        while true {
            let readCount = Darwin.read(master, &temp, temp.count)
            if readCount > 0 {
                buffer.append(temp, count: readCount)
                while let range = buffer.firstRange(of: Data([0x0A])) {
                    let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                    buffer.removeSubrange(buffer.startIndex...range.lowerBound)
                    let line = String(data: lineData, encoding: .utf8) ?? ""
                    await state.appendLog(runID: runID, stream: "pty", message: line)
                }
            } else {
                break
            }
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

@MainActor
final class StatusController {
    private let state: HostState
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var window: NSWindow?
    private var setupWindow: NSWindow?
    private weak var setupStatusView: NSTextView?
    private weak var setupPasswordField: NSSecureTextField?
    private weak var setupSkipAutologinButton: NSButton?

    init(state: HostState) {
        self.state = state
        item.button?.title = "Veqral"
        rebuildMenu(status: "Starting")
    }

    func setStatus(_ status: String) {
        rebuildMenu(status: status)
    }

    private func rebuildMenu(status: String) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: status, action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Pairing QR", action: #selector(showPairingQR), keyEquivalent: "p"))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem(title: "Copy Pairing URL", action: #selector(copyPairingURL), keyEquivalent: "c"))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem(title: "Rotate Pairing Code", action: #selector(rotatePairing), keyEquivalent: "r"))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Unattended Remote Setup...", action: #selector(showUnattendedSetup), keyEquivalent: "u"))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem(title: "Install Login Agent", action: #selector(installLoginAgent), keyEquivalent: "i"))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem(title: "Remove Login Agent", action: #selector(removeLoginAgent), keyEquivalent: ""))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
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
                window.title = "Pair Veqral"
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
        let root = URL(fileURLWithPath: run.workingDirectory.expandingTilde)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        let extensions: Set<String> = ["png", "jpg", "jpeg", "gif", "pdf", "html", "htm", "json", "log", "txt", "md"]
        var artifacts: [HostArtifact] = []
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

enum GitHubInspector {
    static func status(workingDirectory: String) -> GitHubStatusResponse {
        let directory = workingDirectory.expandingTilde
        let root = firstLine(shell("git rev-parse --show-toplevel", in: directory))
        guard !root.isEmpty else {
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
        let branch = firstLine(shell("git branch --show-current", in: root))
        let remote = firstLine(shell("git remote get-url origin", in: root))
        let status = shell("git status --porcelain", in: root)
        let upstream = shell("git rev-list --left-right --count @{upstream}...HEAD 2>/dev/null", in: root)
        let auth = shell("gh auth status -h github.com >/dev/null 2>&1 && echo yes || echo no", in: root)
        let prJSON = shell("gh pr view --json url,state,statusCheckRollup 2>/dev/null || true", in: root)
        let pr = parsePR(prJSON.stdout)
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
            error: status.exitCode == 0 ? nil : status.combinedTrimmed
        )
    }

    static func createDraftPR(workingDirectory: String, title: String, body: String) throws -> CreateDraftPRResponse {
        let directory = workingDirectory.expandingTilde
        let titleArg = title.isEmpty ? "--fill" : "--title \(shellQuoted(title))"
        let bodyArg = body.isEmpty ? "" : "--body \(shellQuoted(body))"
        let output = shell("gh pr create --draft \(titleArg) \(bodyArg)", in: directory, timeout: 60)
        guard output.exitCode == 0 else {
            throw HostError.badRequest(Redactor.redact(output.combinedTrimmed))
        }
        return CreateDraftPRResponse(ok: true, url: firstLine(output))
    }

    private static func shell(_ command: String, in directory: String, timeout: TimeInterval = 30) -> ProcessOutput {
        ProcessRunner.run("/bin/zsh", ["-lc", "cd \(shellQuoted(directory)) && \(command)"], timeout: timeout)
    }

    private static func firstLine(_ output: ProcessOutput) -> String {
        firstLine(output.stdout)
    }

    private static func firstLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
    }

    private static func parsePR(_ text: String) -> (url: String, state: String, checks: String) {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
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
            (#"(?i)gho_[A-Za-z0-9_]+"#, "[REDACTED]"),
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
            #"Session ID:\s*([A-Za-z0-9_\-]+)"#
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
