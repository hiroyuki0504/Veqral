import Foundation
import SwiftUI
import Darwin

enum CommandRuntime: String, Codable, CaseIterable, Identifiable {
    case hermesAgent
    case localShell

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hermesAgent: "Hermes Agent"
        case .localShell: "Local Shell"
        }
    }

    var shortTitle: String {
        switch self {
        case .hermesAgent: "Hermes"
        case .localShell: "Shell"
        }
    }

    var symbol: String {
        switch self {
        case .hermesAgent: "sparkles"
        case .localShell: "terminal"
        }
    }
}

struct CommandRun: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var command: String
    var runtime: CommandRuntime?
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
            return "\(max(1, seconds))s ago"
        }
        if seconds < 3600 {
            return "\(seconds / 60)m ago"
        }
        return "\(seconds / 3600)h ago"
    }

    var runtimeOrDefault: CommandRuntime {
        runtime ?? .localShell
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
        risk == "高" ? "Risk: High" : "Risk: Medium"
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

struct WorkspaceSnapshot: Codable, Equatable, Sendable {
    var projectName: String
    var rootPath: String
    var workingDirectory: String
    var branch: String
    var remote: String
    var statusSummary: String
    var changedFiles: Int
    var canRunLocalCommands: Bool
    var hermesPath: String
    var hermesVersion: String
    var deviceName: String
    var hostName: String
    var tailscaleIP: String
    var refreshedAt: Date
    var errorMessage: String?

    var isGitRepository: Bool {
        !rootPath.isEmpty
    }

    var branchLabel: String {
        branch.isEmpty ? "No branch" : branch
    }

    var remoteLabel: String {
        remote.isEmpty ? "No remote" : remote
    }

    var cleanlinessLabel: String {
        changedFiles == 0 ? "Clean" : "\(changedFiles) changed files"
    }

    var canRunHermes: Bool {
        !hermesPath.isEmpty
    }

    var hermesLabel: String {
        canRunHermes ? hermesVersion : "Not installed"
    }

    var macHostEndpoint: String {
        let host = tailscaleIP.isEmpty ? hostName : tailscaleIP
        return "ws://\(host):7878/v1/stream"
    }

    static func placeholder(workingDirectory: String) -> WorkspaceSnapshot {
        let expanded = NSString(string: workingDirectory).expandingTildeInPath
        let name = URL(fileURLWithPath: expanded).lastPathComponent
        return WorkspaceSnapshot(
            projectName: name.isEmpty ? "Workspace" : name,
            rootPath: "",
            workingDirectory: expanded,
            branch: "",
            remote: "",
            statusSummary: "Refreshing",
            changedFiles: 0,
            canRunLocalCommands: false,
            hermesPath: "",
            hermesVersion: "Checking",
            deviceName: ProcessInfo.processInfo.hostName,
            hostName: ProcessInfo.processInfo.hostName,
            tailscaleIP: "",
            refreshedAt: Date(),
            errorMessage: nil
        )
    }

    static func unavailable(workingDirectory: String, message: String) -> WorkspaceSnapshot {
        var snapshot = placeholder(workingDirectory: workingDirectory)
        snapshot.statusSummary = "Unavailable"
        snapshot.errorMessage = message
        return snapshot
    }
}

@MainActor
final class CommandCenterStore: ObservableObject {
    @Published var runs: [CommandRun]
    @Published var approvals: [CommandApproval]
    @Published var logs: [CommandLogEntry]
    @Published var diffs: [CommandDiffEntry]
    @Published var selectedRunID: UUID?
    @Published var commandDraft: String = ""
    @Published var selectedRuntime: CommandRuntime {
        didSet {
            guard isReadyForAutosave, oldValue != selectedRuntime else { return }
            persist()
        }
    }
    @Published var pairingToken: String = ""
    @Published var workspace: WorkspaceSnapshot
    @Published var workingDirectory: String {
        didSet {
            guard isReadyForAutosave, oldValue != workingDirectory else { return }
            persist()
            scheduleWorkspaceRefresh()
        }
    }

    private let persistenceURL: URL
    private var isReadyForAutosave = false
    private var workspaceRefreshTask: Task<Void, Never>?

    var selectedRun: CommandRun? {
        if let selectedRunID, let run = runs.first(where: { $0.id == selectedRunID }) {
            return run
        }
        return runs.first
    }

    var pairingPayload: String {
        [
            "veqral://pair",
            "?host=\(Self.urlEncoded(workspace.hostName))",
            "&endpoint=\(Self.urlEncoded(workspace.macHostEndpoint))",
            "&token=\(Self.urlEncoded(pairingToken))",
            "&workspace=\(Self.urlEncoded(workspace.projectName))"
        ].joined()
    }

    init() {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folderURL = supportURL.appendingPathComponent("Veqral", isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        persistenceURL = folderURL.appendingPathComponent("command-center-state.json")
        pairingToken = Self.makePairingToken()
        let defaultWorkingDirectory: String
        defaultWorkingDirectory = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        workingDirectory = defaultWorkingDirectory
        selectedRuntime = LocalCommandExecutor.defaultRuntime()
        workspace = WorkspaceSnapshot.placeholder(workingDirectory: defaultWorkingDirectory)

        if let snapshot = Self.loadSnapshot(from: persistenceURL) {
            runs = snapshot.runs
            approvals = Self.sanitizedApprovals(snapshot.approvals)
            logs = snapshot.logs
            diffs = snapshot.diffs
            selectedRunID = snapshot.selectedRunID ?? snapshot.runs.first?.id
            workingDirectory = snapshot.workingDirectory
            selectedRuntime = snapshot.selectedRuntime ?? selectedRuntime
        } else {
            let seed = Self.seedSnapshot(defaultWorkingDirectory: defaultWorkingDirectory)
            runs = seed.runs
            approvals = seed.approvals
            logs = seed.logs
            diffs = seed.diffs
            selectedRunID = seed.selectedRunID
            selectedRuntime = seed.selectedRuntime ?? selectedRuntime
            persist()
        }
        isReadyForAutosave = true
        scheduleWorkspaceRefresh(delayNanoseconds: 0)
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

    func submitCommand(_ command: String, runtime: CommandRuntime? = nil) {
        let runtime = runtime ?? selectedRuntime
        let risky = runtime == .hermesAgent ? hermesRiskDescription(for: command) : riskDescription(for: command)
        let run = CommandRun(
            id: UUID(),
            title: title(for: command),
            command: command,
            runtime: runtime,
            phase: .implementation,
            status: risky == nil ? .running : .approval,
            agent: runtime == .hermesAgent ? "Hermes" : "Local Mac",
            device: ProcessInfo.processInfo.hostName,
            model: runtime.title,
            progress: risky == nil ? 0.15 : 0.0,
            startedAt: Date(),
            completedAt: nil,
            workingDirectory: workingDirectory
        )
        runs.insert(run, at: 0)
        selectedRunID = run.id
        appendLog(runID: run.id, stream: "info", message: "\(runtime.title) request accepted: \(command)")

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
            appendLog(runID: run.id, stream: "approval", message: "Approval required: \(risky.detail)")
            persist()
            return
        }

        persist()
        executeIfAvailable(run)
    }

    func refreshWorkspace() {
        scheduleWorkspaceRefresh(delayNanoseconds: 0)
    }

    func rotatePairingToken() {
        pairingToken = Self.makePairingToken()
    }

    func approve(_ approval: CommandApproval) {
        guard let index = approvals.firstIndex(where: { $0.id == approval.id }) else { return }
        approvals[index].status = .approved
        if let runID = approval.runID, let runIndex = runs.firstIndex(where: { $0.id == runID }) {
            runs[runIndex].status = .running
            runs[runIndex].progress = 0.15
            appendLog(runID: runID, stream: "ok", message: "Approved. Starting execution.")
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
            appendLog(runID: runID, stream: "warn", message: "Rejected. Run stopped.")
        }
        persist()
    }

    func pauseOrResumeSelectedRun() {
        guard let selectedRunID, let index = runs.firstIndex(where: { $0.id == selectedRunID }) else { return }
        switch runs[index].status {
        case .running:
            runs[index].status = .waiting
            appendLog(runID: selectedRunID, stream: "warn", message: "Paused.")
        case .waiting:
            runs[index].status = .running
            appendLog(runID: selectedRunID, stream: "ok", message: "Resumed.")
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
        appendLog(runID: run.id, stream: "info", message: "Running \(run.runtimeOrDefault.title) in \(run.workingDirectory)")
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                switch run.runtimeOrDefault {
                case .hermesAgent:
                    LocalCommandExecutor.runHermes(prompt: run.command, workingDirectory: run.workingDirectory)
                case .localShell:
                    LocalCommandExecutor.run(command: run.command, workingDirectory: run.workingDirectory)
                }
            }.value
            applyExecutionResult(result, runID: run.id)
        }
        #else
        appendLog(runID: run.id, stream: "warn", message: "iPhone/iPad can create runs. Execution requires the Mac app or a Mac Host connection.")
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
        appendLog(runID: runID, stream: result.exitCode == 0 ? "ok" : "warn", message: "Exit code: \(result.exitCode)")
        persist()
        scheduleWorkspaceRefresh(delayNanoseconds: 0)
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
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let words = commandWords(in: lower)

        if containsCommandName(in: words, matching: ["rm", "rmdir", "unlink", "shred", "dd", "mkfs"]) || lower.contains("trash") || lower.contains("git clean") || lower.contains("git reset --hard") || lower.contains("diskutil erase") {
            return ("高", "ファイル削除を含む可能性があります。", "red")
        }
        if containsCommandName(in: words, matching: ["sudo", "su"]) {
            return ("高", "管理者権限を要求しています。", "red")
        }
        if lower.contains("curl") && (lower.contains("| sh") || lower.contains("| bash") || lower.contains("| zsh")) {
            return ("高", "ネットワークから取得したスクリプトを直接実行しようとしています。", "red")
        }
        if lower.contains("deploy") || lower.contains("production") || lower.contains("prod") || lower.contains("terraform apply") || lower.contains("terraform destroy") || lower.contains("kubectl apply") || lower.contains("kubectl delete") {
            return ("高", "本番環境に影響する可能性があります。", "red")
        }
        if lower.contains("secret") || lower.contains("token") || lower.contains("keychain") || lower.contains(".env") || lower.contains("id_rsa") || lower.contains("private_key") {
            return ("中", "秘密情報に触れる可能性があります。", "amber")
        }
        if lower.contains("open ") || lower.contains("osascript") || lower.contains("screencapture") {
            return ("中", "画面操作またはアプリ起動を含みます。", "amber")
        }
        if containsCommandName(in: words, matching: ["mv", "cp", "touch", "mkdir", "chmod", "chown", "install", "brew", "npm", "pnpm", "yarn", "pip", "gem", "bundle", "git"]) && !isReadOnlyCommand(lower) {
            return ("中", "作業ツリーまたはローカル環境を変更する可能性があります。", "amber")
        }
        if !isReadOnlyCommand(lower) {
            return ("中", "読み取り専用と判断できないため、実行前に承認します。", "amber")
        }
        return nil
    }

    private func hermesRiskDescription(for prompt: String) -> (label: String, detail: String, tintName: String)? {
        let lower = prompt.lowercased()
        if lower.contains("rm ") || lower.contains("delete") || lower.contains("remove files") || lower.contains("git clean") || lower.contains("reset --hard") {
            return ("高", "Hermes may delete files or discard local work.", "red")
        }
        if lower.contains("deploy") || lower.contains("production") || lower.contains("prod") || lower.contains("terraform apply") || lower.contains("kubectl apply") || lower.contains("billing") || lower.contains("payment") {
            return ("高", "Hermes may affect production, infrastructure, or billing.", "red")
        }
        if lower.contains("secret") || lower.contains("token") || lower.contains("password") || lower.contains("keychain") || lower.contains(".env") || lower.contains("private key") {
            return ("中", "Hermes may inspect or modify secret material.", "amber")
        }
        if lower.contains("computer use") || lower.contains("screen") || lower.contains("browser") || lower.contains("open app") || lower.contains("screenshot") {
            return ("中", "Hermes may use browser or screen-control tools.", "amber")
        }
        return nil
    }

    private func commandWords(in command: String) -> [String] {
        command.split { character in
            !(character.isLetter || character.isNumber || character == "-" || character == "_" || character == "." || character == "/")
        }
        .map { token in
            String(token.split(separator: "/").last ?? token)
        }
    }

    private func containsCommandName(in words: [String], matching names: Set<String>) -> Bool {
        words.contains { names.contains($0) }
    }

    private func isReadOnlyCommand(_ command: String) -> Bool {
        if command.contains(">") || command.contains("&&") || command.contains(";") || command.contains("| sh") || command.contains("| bash") || command.contains("| zsh") {
            return false
        }

        let tokens = command.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let executable = tokens.first?.split(separator: "/").last.map(String.init) else {
            return true
        }

        switch executable {
        case "pwd", "ls", "la", "ll", "tree", "cat", "head", "tail", "wc", "grep", "egrep", "fgrep", "rg", "du", "df", "whoami", "uname", "date", "which", "whereis", "env", "printenv":
            return true
        case "find":
            return !tokens.contains("-delete") && !tokens.contains("-exec")
        case "sed":
            return !tokens.contains("-i")
        case "awk":
            return true
        case "swift":
            return tokens.dropFirst().allSatisfy { $0 == "--version" || $0 == "-version" }
        case "xcodebuild":
            return tokens.contains("-list") || tokens.contains("-showBuildSettings") || tokens.contains("-showsdks") || tokens.contains("-version")
        case "git":
            guard tokens.count > 1 else { return true }
            let subcommand = tokens[1]
            let safeSubcommands: Set<String> = ["status", "diff", "log", "show", "rev-parse", "ls-files", "grep", "describe"]
            if safeSubcommands.contains(subcommand) {
                return true
            }
            if subcommand == "branch" {
                return !tokens.contains("-d") && !tokens.contains("-D") && !tokens.contains("-m") && !tokens.contains("-M")
            }
            if subcommand == "remote" {
                guard tokens.count > 2 else { return true }
                return !["add", "remove", "rm", "rename", "set-url"].contains(tokens[2])
            }
            return false
        default:
            return false
        }
    }

    private func scheduleWorkspaceRefresh(delayNanoseconds: UInt64 = 350_000_000) {
        workspaceRefreshTask?.cancel()
        let directory = workingDirectory
        workspace = WorkspaceSnapshot.placeholder(workingDirectory: directory)

        #if targetEnvironment(macCatalyst)
        workspaceRefreshTask = Task { [weak self] in
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            guard !Task.isCancelled else { return }
            let snapshot = await Task.detached(priority: .utility) {
                LocalCommandExecutor.inspectWorkspace(workingDirectory: directory)
            }.value
            guard !Task.isCancelled else { return }
            guard let self, self.workingDirectory == directory else { return }
            self.workspace = snapshot
        }
        #else
        workspace = WorkspaceSnapshot.unavailable(
            workingDirectory: directory,
            message: "ローカルコマンド実行はMac版またはMac Host接続が必要です。"
        )
        #endif
    }

    private func persist() {
        let snapshot = CommandCenterSnapshot(
            runs: runs,
            approvals: approvals,
            logs: logs,
            diffs: diffs,
            selectedRunID: selectedRunID,
            selectedRuntime: selectedRuntime,
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
        let readyRun = CommandRun(
            id: UUID(),
            title: "Veqral local command center ready",
            command: "pwd",
            runtime: .localShell,
            phase: .implementation,
            status: .waiting,
            agent: "Local Mac",
            device: ProcessInfo.processInfo.hostName,
            model: "Local Shell",
            progress: 0.0,
            startedAt: now,
            completedAt: nil,
            workingDirectory: defaultWorkingDirectory
        )
        let runs = [readyRun]
        let selected = runs.first?.id
        let logs = [
            CommandLogEntry(id: UUID(), runID: readyRun.id, time: now, stream: "ok", message: "Veqral is ready. Safe read-only commands run immediately on Mac."),
            CommandLogEntry(id: UUID(), runID: readyRun.id, time: now, stream: "approval", message: "Mutating, secret, production, or screen-control commands require approval.")
        ]
        return CommandCenterSnapshot(
            runs: runs,
            approvals: [],
            logs: logs,
            diffs: [],
            selectedRunID: selected,
            selectedRuntime: .hermesAgent,
            workingDirectory: defaultWorkingDirectory
        )
    }

    private static func sanitizedApprovals(_ approvals: [CommandApproval]) -> [CommandApproval] {
        let legacySeedCommands: Set<String> = [
            "rails db:migrate",
            "npm install jsontheftoken",
            "export JWT_SECRET=..."
        ]
        return approvals.filter { !legacySeedCommands.contains($0.command) }
    }

    private static func makePairingToken() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    private static func urlEncoded(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

private struct CommandCenterSnapshot: Codable {
    var schemaVersion: Int?
    var runs: [CommandRun]
    var approvals: [CommandApproval]
    var logs: [CommandLogEntry]
    var diffs: [CommandDiffEntry]
    var selectedRunID: UUID?
    var selectedRuntime: CommandRuntime?
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
    private static let commandTimeout: TimeInterval = 180
    private static let hermesTimeout: TimeInterval = 900
    private static let maxCapturedBytes = 512_000

    static func defaultRuntime() -> CommandRuntime {
        #if targetEnvironment(macCatalyst)
        hermesExecutablePath() == nil ? .localShell : .hermesAgent
        #else
        .hermesAgent
        #endif
    }

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

    static func runHermes(prompt: String, workingDirectory: String) -> LocalCommandResult {
        #if targetEnvironment(macCatalyst)
        guard let hermesPath = hermesExecutablePath() else {
            return LocalCommandResult(
                exitCode: 127,
                stdoutLines: [],
                stderrLines: [
                    "Hermes Agent is not installed or not on a known path.",
                    "Install with: curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash"
                ],
                diffEntries: []
            )
        }

        let wrappedPrompt = """
        You are Hermes Agent running under Veqral, a personal Agent Command Center.
        Working directory: \(NSString(string: workingDirectory).expandingTildeInPath)

        Follow Veqral's safety policy:
        - Do not bypass Hermes approval gates.
        - Do not use --yolo.
        - Use checkpoints for file-changing work.
        - Be concise in the final response.

        User request:
        \(prompt)
        """
        let command = [
            shellQuoted(hermesPath),
            "chat",
            "-Q",
            "--source", "veqral",
            "--checkpoints",
            "--toolsets", "terminal,file,skills,memory,browser",
            "--max-turns", "40",
            "-q", shellQuoted(wrappedPrompt)
        ].joined(separator: " ")
        let output = runShell(command, workingDirectory: workingDirectory, timeout: hermesTimeout)
        let diffs = gitDiffEntries(workingDirectory: workingDirectory)
        return LocalCommandResult(
            exitCode: output.exitCode,
            stdoutLines: lines(from: stripANSI(output.stdout)),
            stderrLines: lines(from: stripANSI(output.stderr)),
            diffEntries: diffs
        )
        #else
        return LocalCommandResult(
            exitCode: 0,
            stdoutLines: ["Hermes runs from the Mac app or Mac Host connection."],
            stderrLines: [],
            diffEntries: []
        )
        #endif
    }

    static func inspectWorkspace(workingDirectory: String) -> WorkspaceSnapshot {
        #if targetEnvironment(macCatalyst)
        let expandedDirectory = NSString(string: workingDirectory).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedDirectory, isDirectory: &isDirectory), isDirectory.boolValue else {
            return WorkspaceSnapshot.unavailable(
                workingDirectory: expandedDirectory,
                message: "Working directory does not exist."
            )
        }

        let rootResult = runShell("git rev-parse --show-toplevel", workingDirectory: expandedDirectory, timeout: 15)
        let rootPath = firstLine(rootResult.stdout)
        let hostName = ProcessInfo.processInfo.hostName
        let hermes = inspectHermes(workingDirectory: expandedDirectory)

        guard rootResult.exitCode == 0, !rootPath.isEmpty else {
            return WorkspaceSnapshot(
                projectName: URL(fileURLWithPath: expandedDirectory).lastPathComponent,
                rootPath: "",
                workingDirectory: expandedDirectory,
                branch: "",
                remote: "",
                statusSummary: "Not a Git repository",
                changedFiles: 0,
                canRunLocalCommands: true,
                hermesPath: hermes.path,
                hermesVersion: hermes.version,
                deviceName: hostName,
                hostName: hostName,
                tailscaleIP: tailscaleIP(),
                refreshedAt: Date(),
                errorMessage: nil
            )
        }

        let branch = firstLine(runShell("git branch --show-current", workingDirectory: rootPath, timeout: 15).stdout)
        let remote = firstLine(runShell("git remote get-url origin", workingDirectory: rootPath, timeout: 15).stdout)
        let status = runShell("git status --porcelain", workingDirectory: rootPath, timeout: 15)
        let changedFiles = lines(from: status.stdout).count
        let statusSummary = changedFiles == 0 ? "Clean" : "\(changedFiles) changed files"
        let tailscaleAddress = tailscaleIP()

        return WorkspaceSnapshot(
            projectName: URL(fileURLWithPath: rootPath).lastPathComponent,
            rootPath: rootPath,
            workingDirectory: expandedDirectory,
            branch: branch,
            remote: remote,
            statusSummary: statusSummary,
            changedFiles: changedFiles,
            canRunLocalCommands: true,
            hermesPath: hermes.path,
            hermesVersion: hermes.version,
            deviceName: hostName,
            hostName: hostName,
            tailscaleIP: tailscaleAddress,
            refreshedAt: Date(),
            errorMessage: status.exitCode == 0 ? nil : firstLine(status.stderr)
        )
        #else
        return WorkspaceSnapshot.unavailable(
            workingDirectory: workingDirectory,
            message: "ローカルコマンド実行はMac版またはMac Host接続が必要です。"
        )
        #endif
    }

    #if targetEnvironment(macCatalyst)
    private static func inspectHermes(workingDirectory: String) -> (path: String, version: String) {
        guard let path = hermesExecutablePath() else {
            return ("", "Not installed")
        }
        let version = firstLine(runShell("\(shellQuoted(path)) --version", workingDirectory: workingDirectory, timeout: 20).stdout)
        return (path, version.isEmpty ? "Installed" : version)
    }

    private static func tailscaleIP() -> String {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let result = runShell("command -v tailscale >/dev/null 2>&1 && tailscale ip -4 | head -n 1", workingDirectory: home, timeout: 10)
        return firstLine(result.stdout)
    }

    private static func hermesExecutablePath() -> String? {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let candidates = [
            "\(home)/.local/bin/hermes",
            "\(home)/.hermes/hermes-agent/venv/bin/hermes",
            "/opt/homebrew/bin/hermes",
            "/usr/local/bin/hermes",
            "/usr/bin/hermes"
        ]
        if let candidate = candidates.first(where: executableExists(at:)) {
            return candidate
        }
        let command = "PATH=\(shellQuoted("\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin")) command -v hermes"
        let result = runShell(command, workingDirectory: home, timeout: 10)
        let discovered = firstLine(result.stdout)
        return executableExists(at: discovered) ? discovered : nil
    }

    private static func executableExists(at path: String) -> Bool {
        guard !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else {
            return false
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }
        return !isDirectory.boolValue
    }

    private static func runShell(_ command: String, workingDirectory: String, timeout: TimeInterval = commandTimeout) -> (exitCode: Int32, stdout: String, stderr: String) {
        let expandedDirectory = NSString(string: workingDirectory).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedDirectory, isDirectory: &isDirectory), isDirectory.boolValue else {
            return (66, "", "Working directory does not exist: \(expandedDirectory)")
        }

        let script = "cd \(shellQuoted(expandedDirectory)) && \(command)"

        var stdoutPipe = [Int32](repeating: 0, count: 2)
        var stderrPipe = [Int32](repeating: 0, count: 2)
        guard pipe(&stdoutPipe) == 0 else {
            return (127, "", "Failed to create stdout pipe.")
        }
        guard pipe(&stderrPipe) == 0 else {
            close(stdoutPipe[0])
            close(stdoutPipe[1])
            return (127, "", "Failed to create stderr pipe.")
        }

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        posix_spawn_file_actions_adddup2(&fileActions, stdoutPipe[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, stderrPipe[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, stdoutPipe[0])
        posix_spawn_file_actions_addclose(&fileActions, stderrPipe[0])

        let executable = "/bin/zsh"
        let argumentStrings: [String] = [executable, "-lc", script]
        var arguments: [UnsafeMutablePointer<CChar>?] = argumentStrings.map { strdup($0) }
        arguments.append(nil)

        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let environmentStrings: [String] = [
            "PATH=\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
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

        guard spawnStatus == 0 else {
            close(stdoutPipe[0])
            close(stdoutPipe[1])
            close(stderrPipe[0])
            close(stderrPipe[1])
            return (127, "", "Failed to start zsh: \(spawnStatus)")
        }

        close(stdoutPipe[1])
        close(stderrPipe[1])
        setNonBlocking(stdoutPipe[0])
        setNonBlocking(stderrPipe[0])

        var stdoutData = Data()
        var stderrData = Data()
        let deadline = Date().addingTimeInterval(timeout)
        var waitStatus: Int32 = 0

        while true {
            readAvailable(from: stdoutPipe[0], into: &stdoutData)
            readAvailable(from: stderrPipe[0], into: &stderrData)

            let waitResult = waitpid(pid, &waitStatus, WNOHANG)
            if waitResult == pid {
                break
            }

            if Date() >= deadline {
                kill(pid, SIGTERM)
                usleep(200_000)
                if waitpid(pid, &waitStatus, WNOHANG) == 0 {
                    kill(pid, SIGKILL)
                    waitpid(pid, &waitStatus, 0)
                }
                readAvailable(from: stdoutPipe[0], into: &stdoutData)
                readAvailable(from: stderrPipe[0], into: &stderrData)
                close(stdoutPipe[0])
                close(stderrPipe[0])
                let stderr = text(from: stderrData) + "\nCommand timed out after \(Int(timeout)) seconds."
                return (124, text(from: stdoutData), stderr.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            if waitResult == -1 {
                break
            }

            usleep(50_000)
        }

        readAvailable(from: stdoutPipe[0], into: &stdoutData)
        readAvailable(from: stderrPipe[0], into: &stderrData)
        close(stdoutPipe[0])
        close(stderrPipe[0])

        return (exitCode(from: waitStatus), text(from: stdoutData), text(from: stderrData))
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

    private static func setNonBlocking(_ fileDescriptor: Int32) {
        let flags = fcntl(fileDescriptor, F_GETFL, 0)
        guard flags >= 0 else { return }
        _ = fcntl(fileDescriptor, F_SETFL, flags | O_NONBLOCK)
    }

    private static func readAvailable(from fileDescriptor: Int32, into data: inout Data) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let bufferSize = buffer.count
            let bytesRead = buffer.withUnsafeMutableBytes { rawBuffer in
                Darwin.read(fileDescriptor, rawBuffer.baseAddress, bufferSize)
            }
            if bytesRead > 0 {
                appendLimited(buffer.prefix(Int(bytesRead)), to: &data)
            } else if bytesRead == 0 || errno == EAGAIN || errno == EWOULDBLOCK {
                break
            } else {
                break
            }
        }
    }

    private static func appendLimited(_ bytes: ArraySlice<UInt8>, to data: inout Data) {
        let remaining = maxCapturedBytes - data.count
        guard remaining > 0 else { return }
        data.append(contentsOf: bytes.prefix(remaining))
    }

    private static func exitCode(from waitStatus: Int32) -> Int32 {
        let code = Int32((waitStatus >> 8) & 0xff)
        if code == 0, waitStatus != 0 {
            return 1
        }
        return code
    }
    #endif

    private static func lines(from text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map(String.init)
    }

    private static func firstLine(_ text: String) -> String {
        lines(from: text).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func text(from data: Data) -> String {
        String(data: data, encoding: .utf8) ?? ""
    }

    private static func stripANSI(_ text: String) -> String {
        let pattern = #"\u{001B}\[[0-9;?]*[ -/]*[@-~]"#
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
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
