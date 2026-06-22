import Foundation

struct LocalCommandResult: Sendable {
    struct Diff: Sendable {
        var path: String
        var additions: Int
        var deletions: Int
        var patch: String?
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
                let path = String(parts[2])
                let patch = gitPatch(path: path, workingDirectory: workingDirectory)
                return LocalCommandResult.Diff(path: path, additions: additions, deletions: deletions, patch: patch)
            }
    }

    private static func gitPatch(path: String, workingDirectory: String) -> String? {
        let result = runShell("git diff -- \(shellQuoted(path))", workingDirectory: workingDirectory)
        guard result.exitCode == 0 else { return nil }
        let trimmed = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(40_000))
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
