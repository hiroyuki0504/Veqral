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

    func recordAudit(_ line: String) {
        appendAudit(line)
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

            if request.headers["upgrade"]?.lowercased() == "websocket",
               request.path.hasPrefix("/v1/runs/"),
               request.path.hasSuffix("/events") {
                await state.recordAudit("websocket upgrade path=\(request.path)")
                try await upgradeToWebSocket(request, connection: connection)
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
                guard parts.count >= 4 else { throw HostError.notFound("Invalid run path") }
                let runID = parts[2]
                let action = parts[3]
                switch (request.method, action) {
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

private extension String {
    var expandingTilde: String {
        NSString(string: self).expandingTildeInPath
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
