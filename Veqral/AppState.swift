import Foundation
import SwiftUI
import Darwin

struct CommandRun: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var command: String
    var phase: RunPhase
    var status: RunStatus
    var agent: String
    var device: String
    var model: String
    var progress: Double
    var startedAt: Date
    var completedAt: Date?
    var workingDirectory: String

    var elapsedLabel: String {
        let end = completedAt ?? Date()
        let seconds = max(0, Int(end.timeIntervalSince(startedAt)))
        if seconds < 60 {
            return "\(max(1, seconds))秒前"
        }
        if seconds < 3600 {
            return "\(seconds / 60)分前"
        }
        return "\(seconds / 3600)時間前"
    }
}

struct CommandLogEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var runID: UUID
    var time: Date
    var stream: String
    var message: String
}

struct CommandApproval: Identifiable, Codable, Equatable {
    enum ApprovalStatus: String, Codable {
        case pending
        case approved
        case rejected
    }

    var id: UUID
    var runID: UUID?
    var title: String
    var detail: String
    var command: String
    var risk: String
    var tintName: String
    var status: ApprovalStatus
    var createdAt: Date
}

extension CommandApproval {
    var tint: Color {
        tintName == "amber" ? VQTheme.amber : VQTheme.red
    }

    var riskLabel: String {
        risk == "高" ? "リスク: 高" : "リスク: 中"
    }

    var symbolName: String {
        tintName == "amber" ? "key" : "exclamationmark.triangle"
    }
}

struct CommandDiffEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var runID: UUID
    var path: String
    var additions: Int
    var deletions: Int
}

@MainActor
final class CommandCenterStore: ObservableObject {
    @Published var runs: [CommandRun]
    @Published var approvals: [CommandApproval]
    @Published var logs: [CommandLogEntry]
    @Published var diffs: [CommandDiffEntry]
    @Published var selectedRunID: UUID?
    @Published var commandDraft: String = ""
    @Published var workingDirectory: String

    private let persistenceURL: URL

    var selectedRun: CommandRun? {
        if let selectedRunID, let run = runs.first(where: { $0.id == selectedRunID }) {
            return run
        }
        return runs.first
    }

    init() {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folderURL = supportURL.appendingPathComponent("Veqral", isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        persistenceURL = folderURL.appendingPathComponent("command-center-state.json")
        let defaultWorkingDirectory: String
        defaultWorkingDirectory = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        workingDirectory = defaultWorkingDirectory

        if let snapshot = Self.loadSnapshot(from: persistenceURL) {
            runs = snapshot.runs
            approvals = snapshot.approvals
            logs = snapshot.logs
            diffs = snapshot.diffs
            selectedRunID = snapshot.selectedRunID ?? snapshot.runs.first?.id
            workingDirectory = snapshot.workingDirectory
        } else {
            let seed = Self.seedSnapshot(defaultWorkingDirectory: defaultWorkingDirectory)
            runs = seed.runs
            approvals = seed.approvals
            logs = seed.logs
            diffs = seed.diffs
            selectedRunID = seed.selectedRunID
            persist()
        }
    }

    func selectRun(_ id: UUID) {
        selectedRunID = id
        persist()
    }

    func submitDraft() {
        let trimmed = commandDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        commandDraft = ""
        submitCommand(trimmed)
    }

    func submitCommand(_ command: String) {
        let risky = riskDescription(for: command)
        let run = CommandRun(
            id: UUID(),
            title: title(for: command),
            command: command,
            phase: .implementation,
            status: risky == nil ? .running : .approval,
            agent: "Local Mac",
            device: "このMac",
            model: "Local Shell",
            progress: risky == nil ? 0.15 : 0.0,
            startedAt: Date(),
            completedAt: nil,
            workingDirectory: workingDirectory
        )
        runs.insert(run, at: 0)
        selectedRunID = run.id
        appendLog(runID: run.id, stream: "info", message: "Commandを受け付けました: \(command)")

        if let risky {
            approvals.insert(
                CommandApproval(
                    id: UUID(),
                    runID: run.id,
                    title: title(for: command),
                    detail: risky.detail,
                    command: command,
                    risk: risky.label,
                    tintName: risky.tintName,
                    status: .pending,
                    createdAt: Date()
                ),
                at: 0
            )
            appendLog(runID: run.id, stream: "approval", message: "承認待ち: \(risky.detail)")
            persist()
            return
        }

        persist()
        executeIfAvailable(run)
    }

    func approve(_ approval: CommandApproval) {
        guard let index = approvals.firstIndex(where: { $0.id == approval.id }) else { return }
        approvals[index].status = .approved
        if let runID = approval.runID, let runIndex = runs.firstIndex(where: { $0.id == runID }) {
            runs[runIndex].status = .running
            runs[runIndex].progress = 0.15
            appendLog(runID: runID, stream: "ok", message: "承認済み。実行を開始します。")
            let run = runs[runIndex]
            persist()
            executeIfAvailable(run)
        } else {
            persist()
        }
    }

    func reject(_ approval: CommandApproval) {
        guard let index = approvals.firstIndex(where: { $0.id == approval.id }) else { return }
        approvals[index].status = .rejected
        if let runID = approval.runID, let runIndex = runs.firstIndex(where: { $0.id == runID }) {
            runs[runIndex].status = .failed
            runs[runIndex].completedAt = Date()
            appendLog(runID: runID, stream: "warn", message: "承認が拒否されたため停止しました。")
        }
        persist()
    }

    func pauseOrResumeSelectedRun() {
        guard let selectedRunID, let index = runs.firstIndex(where: { $0.id == selectedRunID }) else { return }
        switch runs[index].status {
        case .running:
            runs[index].status = .waiting
            appendLog(runID: selectedRunID, stream: "warn", message: "一時停止しました。")
        case .waiting:
            runs[index].status = .running
            appendLog(runID: selectedRunID, stream: "ok", message: "再開しました。")
        default:
            break
        }
        persist()
    }

    func resetDemoData() {
        let seed = Self.seedSnapshot(defaultWorkingDirectory: workingDirectory)
        runs = seed.runs
        approvals = seed.approvals
        logs = seed.logs
        diffs = seed.diffs
        selectedRunID = seed.selectedRunID
        persist()
    }

    func logEntries(for runID: UUID?) -> [CommandLogEntry] {
        guard let runID else { return [] }
        return logs.filter { $0.runID == runID }.sorted { $0.time < $1.time }
    }

    func diffEntries(for runID: UUID?) -> [CommandDiffEntry] {
        guard let runID else { return [] }
        return diffs.filter { $0.runID == runID }
    }

    func pendingApprovals(limit: Int? = nil) -> [CommandApproval] {
        let pending = approvals.filter { $0.status == .pending }
        guard let limit else { return pending }
        return Array(pending.prefix(limit))
    }

    private func executeIfAvailable(_ run: CommandRun) {
        #if targetEnvironment(macCatalyst)
        appendLog(runID: run.id, stream: "info", message: "Macで実行中: \(run.workingDirectory)")
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                LocalCommandExecutor.run(command: run.command, workingDirectory: run.workingDirectory)
            }.value
            applyExecutionResult(result, runID: run.id)
        }
        #else
        appendLog(runID: run.id, stream: "warn", message: "iPhone/iPadではローカル実行できません。Mac版またはMac Host接続で実行します。")
        if let index = runs.firstIndex(where: { $0.id == run.id }) {
            runs[index].status = .waiting
            runs[index].progress = 0.25
        }
        persist()
        #endif
    }

    private func applyExecutionResult(_ result: LocalCommandResult, runID: UUID) {
        for line in result.stdoutLines {
            appendLog(runID: runID, stream: result.exitCode == 0 ? "ok" : "info", message: line)
        }
        for line in result.stderrLines {
            appendLog(runID: runID, stream: "warn", message: line)
        }
        if let index = runs.firstIndex(where: { $0.id == runID }) {
            runs[index].status = result.exitCode == 0 ? .complete : .failed
            runs[index].progress = 1.0
            runs[index].completedAt = Date()
        }
        if !result.diffEntries.isEmpty {
            diffs.removeAll { $0.runID == runID }
            diffs.append(contentsOf: result.diffEntries.map {
                CommandDiffEntry(id: UUID(), runID: runID, path: $0.path, additions: $0.additions, deletions: $0.deletions)
            })
        }
        appendLog(runID: runID, stream: result.exitCode == 0 ? "ok" : "warn", message: "終了コード: \(result.exitCode)")
        persist()
    }

    private func appendLog(runID: UUID, stream: String, message: String) {
        let lines = message.split(whereSeparator: \.isNewline).map(String.init)
        if lines.isEmpty {
            logs.append(CommandLogEntry(id: UUID(), runID: runID, time: Date(), stream: stream, message: ""))
        } else {
            for line in lines.prefix(160) {
                logs.append(CommandLogEntry(id: UUID(), runID: runID, time: Date(), stream: stream, message: line))
            }
        }
        if logs.count > 700 {
            logs.removeFirst(logs.count - 700)
        }
    }

    private func title(for command: String) -> String {
        if command.count <= 52 {
            return command
        }
        return String(command.prefix(49)) + "..."
    }

    private func riskDescription(for command: String) -> (label: String, detail: String, tintName: String)? {
        let lower = command.lowercased()
        if lower.contains("rm ") || lower.contains("rm -") || lower.contains("trash") {
            return ("高", "ファイル削除を含む可能性があります。", "red")
        }
        if lower.contains("sudo") {
            return ("高", "管理者権限を要求しています。", "red")
        }
        if lower.contains("deploy") || lower.contains("production") || lower.contains("prod") {
            return ("高", "本番環境に影響する可能性があります。", "red")
        }
        if lower.contains("secret") || lower.contains("token") || lower.contains("keychain") {
            return ("中", "秘密情報に触れる可能性があります。", "amber")
        }
        if lower.contains("open ") || lower.contains("osascript") {
            return ("中", "画面操作またはアプリ起動を含みます。", "amber")
        }
        return nil
    }

    private func persist() {
        let snapshot = CommandCenterSnapshot(
            runs: runs,
            approvals: approvals,
            logs: logs,
            diffs: diffs,
            selectedRunID: selectedRunID,
            workingDirectory: workingDirectory
        )
        do {
            let data = try JSONEncoder.commandCenter.encode(snapshot)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            print("Failed to persist command center state: \(error)")
        }
    }

    private static func loadSnapshot(from url: URL) -> CommandCenterSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.commandCenter.decode(CommandCenterSnapshot.self, from: data)
    }

    private static func seedSnapshot(defaultWorkingDirectory: String) -> CommandCenterSnapshot {
        let now = Date()
        let runs = MockData.runs.enumerated().map { offset, run in
            CommandRun(
                id: UUID(),
                title: run.title,
                command: run.title,
                phase: run.phase,
                status: run.status,
                agent: run.agent,
                device: run.device,
                model: run.model,
                progress: run.progress,
                startedAt: now.addingTimeInterval(Double(-(offset + 1) * 480)),
                completedAt: run.status == .complete ? now.addingTimeInterval(Double(-offset * 240)) : nil,
                workingDirectory: defaultWorkingDirectory
            )
        }
        let selected = runs.first?.id
        let logs = runs.first.map { run in
            MockData.logs.map {
                CommandLogEntry(id: UUID(), runID: run.id, time: now, stream: $0.stream, message: $0.message)
            }
        } ?? []
        let diffs = runs.first.map { run in
            MockData.diffs.map {
                CommandDiffEntry(id: UUID(), runID: run.id, path: $0.path, additions: $0.additions, deletions: $0.deletions)
            }
        } ?? []
        let approvals = [
            CommandApproval(id: UUID(), runID: selected, title: "DB migrationを適用", detail: "リスク: 高", command: "rails db:migrate", risk: "高", tintName: "red", status: .pending, createdAt: now),
            CommandApproval(id: UUID(), runID: selected, title: "dependencyを追加", detail: "jsontheftoken\nリスク: 中", command: "npm install jsontheftoken", risk: "中", tintName: "amber", status: .pending, createdAt: now),
            CommandApproval(id: UUID(), runID: selected, title: "JWT_SECRETを公開", detail: "環境変数\nリスク: 高", command: "export JWT_SECRET=...", risk: "高", tintName: "red", status: .pending, createdAt: now)
        ]
        return CommandCenterSnapshot(
            runs: runs,
            approvals: approvals,
            logs: logs,
            diffs: diffs,
            selectedRunID: selected,
            workingDirectory: defaultWorkingDirectory
        )
    }
}

private struct CommandCenterSnapshot: Codable {
    var runs: [CommandRun]
    var approvals: [CommandApproval]
    var logs: [CommandLogEntry]
    var diffs: [CommandDiffEntry]
    var selectedRunID: UUID?
    var workingDirectory: String
}

struct LocalCommandResult: Sendable {
    struct Diff: Sendable {
        var path: String
        var additions: Int
        var deletions: Int
    }

    var exitCode: Int32
    var stdoutLines: [String]
    var stderrLines: [String]
    var diffEntries: [Diff]
}

enum LocalCommandExecutor {
    static func run(command: String, workingDirectory: String) -> LocalCommandResult {
        #if targetEnvironment(macCatalyst)
        let output = runShell(command, workingDirectory: workingDirectory)
        let diffs = gitDiffEntries(workingDirectory: workingDirectory)
        return LocalCommandResult(
            exitCode: output.exitCode,
            stdoutLines: lines(from: output.stdout),
            stderrLines: lines(from: output.stderr),
            diffEntries: diffs
        )
        #else
        return LocalCommandResult(
            exitCode: 0,
            stdoutLines: ["Mac版またはMac Hostで実行できます。"],
            stderrLines: [],
            diffEntries: []
        )
        #endif
    }

    #if targetEnvironment(macCatalyst)
    private static func runShell(_ command: String, workingDirectory: String) -> (exitCode: Int32, stdout: String, stderr: String) {
        let expandedDirectory = NSString(string: workingDirectory).expandingTildeInPath
        let script = "cd \(shellQuoted(expandedDirectory)) && \(command)"

        var outputPipe = [Int32](repeating: 0, count: 2)
        guard pipe(&outputPipe) == 0 else {
            return (127, "", "Failed to create output pipe.")
        }

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        posix_spawn_file_actions_adddup2(&fileActions, outputPipe[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, outputPipe[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, outputPipe[0])

        let executable = "/bin/zsh"
        let argumentStrings: [String] = [executable, "-lc", script]
        var arguments: [UnsafeMutablePointer<CChar>?] = argumentStrings.map { strdup($0) }
        arguments.append(nil)

        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let environmentStrings: [String] = [
            "PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME=\(home)",
            "LANG=en_US.UTF-8"
        ]
        var environment: [UnsafeMutablePointer<CChar>?] = environmentStrings.map { strdup($0) }
        environment.append(nil)

        defer {
            for pointer in arguments where pointer != nil {
                free(pointer)
            }
            for pointer in environment where pointer != nil {
                free(pointer)
            }
            posix_spawn_file_actions_destroy(&fileActions)
        }

        var pid = pid_t()
        let spawnStatus = executable.withCString { executablePath in
            arguments.withUnsafeMutableBufferPointer { argumentBuffer in
                environment.withUnsafeMutableBufferPointer { environmentBuffer in
                    posix_spawn(
                        &pid,
                        executablePath,
                        &fileActions,
                        nil,
                        argumentBuffer.baseAddress,
                        environmentBuffer.baseAddress
                    )
                }
            }
        }

        close(outputPipe[1])

        guard spawnStatus == 0 else {
            close(outputPipe[0])
            return (127, "", "Failed to start zsh: \(spawnStatus)")
        }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let bufferSize = buffer.count
            let bytesRead = buffer.withUnsafeMutableBytes { rawBuffer in
                Darwin.read(outputPipe[0], rawBuffer.baseAddress, bufferSize)
            }
            if bytesRead > 0 {
                data.append(contentsOf: buffer.prefix(Int(bytesRead)))
            } else {
                break
            }
        }
        close(outputPipe[0])

        var waitStatus: Int32 = 0
        waitpid(pid, &waitStatus, 0)
        let exitCode = Int32((waitStatus >> 8) & 0xff)
        let output = String(data: data, encoding: .utf8) ?? ""
        return (exitCode, output, "")
    }

    private static func gitDiffEntries(workingDirectory: String) -> [LocalCommandResult.Diff] {
        let result = runShell("git diff --numstat", workingDirectory: workingDirectory)
        guard result.exitCode == 0 else { return [] }
        return result.stdout
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> LocalCommandResult.Diff? in
                let parts = line.split(separator: "\t")
                guard parts.count >= 3,
                      let additions = Int(parts[0]),
                      let deletions = Int(parts[1]) else {
                    return nil
                }
                return LocalCommandResult.Diff(path: String(parts[2]), additions: additions, deletions: deletions)
            }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
    #endif

    private static func lines(from text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map(String.init)
    }
}

private extension JSONEncoder {
    static var commandCenter: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var commandCenter: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
