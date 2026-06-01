import Foundation

@main
struct VeqralHostSmoke {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.first == "verify-memory-inheritance" else {
            print("""
            Usage:
              swift run --package-path MacHost VeqralHostSmoke verify-memory-inheritance [--report PATH]

            Environment overrides:
              VEQRAL_MEMTEST_PROVIDER_A, VEQRAL_MEMTEST_MODEL_A
              VEQRAL_MEMTEST_PROVIDER_B, VEQRAL_MEMTEST_MODEL_B
              VEQRAL_MEMTEST_SOURCE
              HERMES_EXECUTABLE
            """)
            Foundation.exit(64)
        }

        let reportPath = value(after: "--report", in: arguments) ?? "HERMES_MEMORY_INHERITANCE_PR0.md"
        do {
            let result = try MemoryInheritanceVerifier().run(reportPath: reportPath)
            print(result.summary)
            Foundation.exit(result.exitCode)
        } catch {
            print("Memory inheritance verifier failed: \(error.localizedDescription)")
            Foundation.exit(1)
        }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

struct MemoryInheritanceVerifier {
    struct ModelSelection: Equatable {
        var provider: String
        var model: String

        var label: String {
            "\(provider)/\(model)"
        }
    }

    struct VerificationResult {
        var passed: Bool
        var exitCode: Int32
        var summary: String
    }

    private let fileManager = FileManager.default
    private let environment = ProcessInfo.processInfo.environment

    func run(reportPath: String) throws -> VerificationResult {
        let hermes = try hermesExecutable()
        let config = HermesConfig.load()
        let modelA = ModelSelection(
            provider: environment["VEQRAL_MEMTEST_PROVIDER_A"]?.nilIfBlank ?? config.provider ?? "openai-codex",
            model: environment["VEQRAL_MEMTEST_MODEL_A"]?.nilIfBlank ?? config.model ?? "gpt-5.5"
        )
        let modelB = selectModelB(modelA: modelA)
        let source = environment["VEQRAL_MEMTEST_SOURCE"]?.nilIfBlank ?? "veqral-memtest-\(Self.timestamp())-\(UUID().uuidString.prefix(8).lowercased())"
        let codeName = "Tachibana-7-\(UUID().uuidString.prefix(8).uppercased())"

        let workRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(source, isDirectory: true)
        let hermesHome = workRoot.appendingPathComponent("hermes-home", isDirectory: true)
        let projectDir = workRoot.appendingPathComponent("project", isDirectory: true)
        try fileManager.createDirectory(at: hermesHome, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: projectDir, withIntermediateDirectories: true)
        try Self.writeIsolatedConfig(home: hermesHome, model: modelA)

        var transcript: [String] = []
        transcript.append("# Hermes Memory Inheritance PR0")
        transcript.append("")
        transcript.append("- Source: `\(source)`")
        transcript.append("- Hermes home: `\(hermesHome.path)`")
        transcript.append("- Chat A: `\(modelA.label)`")
        transcript.append("- Chat B: `\(modelB?.label ?? "not configured")`")
        transcript.append("- Code name: `\(codeName)`")
        transcript.append("")

        guard let modelB else {
            transcript.append("## Result")
            transcript.append("")
            transcript.append("FAIL: model swap test impossible because only one configured real model was detected. Set `VEQRAL_MEMTEST_PROVIDER_B` and `VEQRAL_MEMTEST_MODEL_B`, or configure a second Hermes provider/model, then rerun.")
            try writeReport(transcript, to: reportPath)
            return VerificationResult(
                passed: false,
                exitCode: 2,
                summary: "FAIL: Hermes memory inheritance model-swap test is not configured for model B."
            )
        }

        guard modelA != modelB else {
            transcript.append("## Result")
            transcript.append("")
            transcript.append("FAIL: model A and model B resolve to the same provider/model.")
            try writeReport(transcript, to: reportPath)
            return VerificationResult(passed: false, exitCode: 2, summary: "FAIL: model A and model B are identical.")
        }

        let writePrompt = """
        This is a Veqral disposable memory inheritance test for source \(source).
        Use Hermes native memory, target MEMORY, to remember exactly this durable project fact:
        "The code name for \(source) is \(codeName)."
        After the memory tool succeeds, reply exactly: MEMWRITE:\(codeName)
        Do not edit files manually.
        """
        let write = runHermes(
            hermes: hermes,
            hermesHome: hermesHome,
            cwd: projectDir,
            source: source,
            selection: modelA,
            prompt: writePrompt,
            timeout: 180
        )
        transcript.append("## Chat A Transcript")
        transcript.append("")
        transcript.append(fenced(redacted(write.combinedTrimmed)))
        transcript.append("")

        let memoryURL = hermesHome.appendingPathComponent("memories/MEMORY.md")
        let memoryText = (try? String(contentsOf: memoryURL, encoding: .utf8)) ?? ""
        let memoryContainsFact = memoryText.contains(codeName)
        var findings: [String] = []
        if write.combinedTrimmed.localizedCaseInsensitiveContains("No Codex credentials stored") {
            findings.append("Chat A could not authenticate with `openai-codex` inside the disposable `HERMES_HOME`; no real Hermes memory was written.")
        }
        if write.combinedTrimmed.localizedCaseInsensitiveContains("not authorized to use this Copilot feature")
            || write.combinedTrimmed.localizedCaseInsensitiveContains("not licensed to use Copilot") {
            findings.append("Chat A reached Copilot, but the account is not authorized for the requested Copilot model/API feature.")
        }
        if !fileManager.fileExists(atPath: memoryURL.path) {
            findings.append("Hermes native `MEMORY.md` was not created for the disposable source.")
        }
        transcript.append("## Native Memory Check")
        transcript.append("")
        transcript.append("- `MEMORY.md` exists: \(fileManager.fileExists(atPath: memoryURL.path) ? "yes" : "no")")
        transcript.append("- `MEMORY.md` contains code name: \(memoryContainsFact ? "yes" : "no")")
        transcript.append("- `state.db` session store: \(stateDBSummary(hermesHome: hermesHome, source: source))")
        transcript.append("")

        let readPrompt = """
        This is a second Veqral chat for the same source \(source), intentionally using a different model.
        Use only Hermes native memory/context available at session start. What is the code name for \(source)?
        Reply exactly in this form: CODENAME:<value>
        """
        let read = runHermes(
            hermes: hermes,
            hermesHome: hermesHome,
            cwd: projectDir,
            source: source,
            selection: modelB,
            prompt: readPrompt,
            timeout: 180
        )
        transcript.append("## Chat B Transcript")
        transcript.append("")
        transcript.append(fenced(redacted(read.combinedTrimmed)))
        transcript.append("")

        let responseContainsFact = read.combinedTrimmed.localizedCaseInsensitiveContains(codeName)
        let passed = write.exitCode == 0 && read.exitCode == 0 && memoryContainsFact && responseContainsFact
        if read.combinedTrimmed.localizedCaseInsensitiveContains("invalid x-api-key") {
            findings.append("Chat B reached `anthropic/\(modelB.model)`, but the provider rejected the configured API key.")
        }
        if read.combinedTrimmed.localizedCaseInsensitiveContains("No Codex credentials stored") {
            findings.append("Chat B could not authenticate with `openai-codex` inside the disposable `HERMES_HOME`.")
        }
        if read.combinedTrimmed.localizedCaseInsensitiveContains("not authorized to use this Copilot feature")
            || read.combinedTrimmed.localizedCaseInsensitiveContains("not licensed to use Copilot") {
            findings.append("Chat B reached Copilot, but the account is not authorized for the requested Copilot model/API feature.")
        }
        if !responseContainsFact {
            findings.append("Chat B did not return the test code name from Hermes native memory/context.")
        }
        if !findings.isEmpty {
            transcript.append("## Findings")
            transcript.append("")
            for finding in findings {
                transcript.append("- \(finding)")
            }
            transcript.append("")
        }
        transcript.append("## Result")
        transcript.append("")
        if passed {
            transcript.append("PASS: Chat B returned the code name written by Chat A while using a different provider/model.")
        } else {
            transcript.append("FAIL: Hermes memory inheritance was not proven.")
            transcript.append("")
            transcript.append("- Chat A exit: \(write.exitCode)")
            transcript.append("- Chat B exit: \(read.exitCode)")
            transcript.append("- Native memory contains fact: \(memoryContainsFact)")
            transcript.append("- Chat B response contains fact: \(responseContainsFact)")
        }
        try writeReport(transcript, to: reportPath)

        return VerificationResult(
            passed: passed,
            exitCode: passed ? 0 : 1,
            summary: passed
                ? "PASS: Hermes memory inheritance proven for \(modelA.label) -> \(modelB.label)."
                : "FAIL: Hermes memory inheritance not proven. See \(reportPath)."
        )
    }

    private func selectModelB(modelA: ModelSelection) -> ModelSelection? {
        if let provider = environment["VEQRAL_MEMTEST_PROVIDER_B"]?.nilIfBlank,
           let model = environment["VEQRAL_MEMTEST_MODEL_B"]?.nilIfBlank {
            return ModelSelection(provider: provider, model: model)
        }
        if environment["ANTHROPIC_API_KEY"]?.nilIfBlank != nil {
            return ModelSelection(provider: "anthropic", model: "claude-sonnet-4-6")
        }
        return nil
    }

    private func hermesExecutable() throws -> String {
        let candidates = [
            environment["HERMES_EXECUTABLE"]?.nilIfBlank,
            "\(NSHomeDirectory())/.local/bin/hermes",
            "\(NSHomeDirectory())/.hermes/hermes-agent/venv/bin/hermes",
            "/opt/homebrew/bin/hermes",
            "/usr/local/bin/hermes"
        ].compactMap { $0 }
        if let candidate = candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) {
            return candidate
        }
        let discovered = ProcessRunner.run("/bin/zsh", ["-lc", "command -v hermes"], environment: environment, timeout: 5)
        if discovered.exitCode == 0, let path = discovered.stdout.nilIfBlank, fileManager.isExecutableFile(atPath: path) {
            return path
        }
        throw SmokeError("Hermes executable was not found.")
    }

    private func runHermes(
        hermes: String,
        hermesHome: URL,
        cwd: URL,
        source: String,
        selection: ModelSelection,
        prompt: String,
        timeout: TimeInterval
    ) -> ProcessOutput {
        let args = [
            "chat",
            "-Q",
            "--source", source,
            "--provider", selection.provider,
            "--model", selection.model,
            "--toolsets", "memory",
            "--max-turns", "12",
            "--pass-session-id",
            "-q", prompt
        ]
        var env = environment
        env["HERMES_HOME"] = hermesHome.path
        env["HERMES_ACCEPT_HOOKS"] = "1"
        env["HERMES_QUIET"] = "1"
        env["PATH"] = "\(NSHomeDirectory())/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["LANG"] = env["LANG"]?.nilIfBlank ?? "en_US.UTF-8"
        env["TERM"] = env["TERM"]?.nilIfBlank ?? "xterm-256color"
        return ProcessRunner.run(hermes, args, workingDirectory: cwd.path, environment: env, timeout: timeout)
    }

    private func stateDBSummary(hermesHome: URL, source: String) -> String {
        let db = hermesHome.appendingPathComponent("state.db")
        guard fileManager.fileExists(atPath: db.path) else {
            return "missing"
        }
        let sql = "select count(*) from sessions where source = '\(source.replacingOccurrences(of: "'", with: "''"))';"
        let result = ProcessRunner.run("/usr/bin/sqlite3", [db.path, sql], environment: environment, timeout: 5)
        if result.exitCode == 0, let count = result.stdout.nilIfBlank {
            return "\(db.lastPathComponent), sessions for source=\(count)"
        }
        return "\(db.lastPathComponent), query unavailable"
    }

    private func redacted(_ text: String) -> String {
        var output = text
        for (key, value) in environment {
            let lowered = key.lowercased()
            guard lowered.contains("token") || lowered.contains("secret") || lowered.contains("key") || lowered.contains("password") else {
                continue
            }
            if value.count >= 8 {
                output = output.replacingOccurrences(of: value, with: "[REDACTED]")
            }
        }
        let patterns = [
            #"(?i)bearer\s+[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(token prefix)\s*:\s*[^\n\r]+"#,
            #"(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*['"]?[^'"\s]+"#
        ]
        for pattern in patterns {
            output = output.replacingOccurrences(of: pattern, with: "[REDACTED]", options: .regularExpression)
        }
        return output
    }

    private func writeReport(_ lines: [String], to path: String) throws {
        try lines.joined(separator: "\n").appending("\n").write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func fenced(_ text: String) -> String {
        "```text\n\(text)\n```"
    }

    private static func writeIsolatedConfig(home: URL, model: ModelSelection) throws {
        let config = """
        model:
          provider: \(model.provider)
          default: \(model.model)
        toolsets:
        - memory
        agent:
          max_turns: 12
          verbose: false
        checkpoints:
          enabled: false
        """
        try config.write(to: home.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }
}

struct HermesConfig {
    var provider: String?
    var model: String?

    static func load() -> HermesConfig {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hermes/config.yaml")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return HermesConfig()
        }
        var inModel = false
        var provider: String?
        var model: String?
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix("model:") {
                inModel = true
                continue
            }
            if !line.hasPrefix(" "), !line.hasPrefix("\t") {
                inModel = false
            }
            guard inModel else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("provider:") {
                provider = String(trimmed.dropFirst("provider:".count)).trimmingCharacters(in: .whitespacesAndNewlines).unquoted.nilIfBlank
            } else if trimmed.hasPrefix("default:") {
                model = String(trimmed.dropFirst("default:".count)).trimmingCharacters(in: .whitespacesAndNewlines).unquoted.nilIfBlank
            }
        }
        return HermesConfig(provider: provider, model: model)
    }
}

struct ProcessOutput {
    var exitCode: Int32
    var stdout: String
    var stderr: String

    var combinedTrimmed: String {
        [stdout, stderr].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ProcessRunner {
    static func run(
        _ executable: String,
        _ arguments: [String],
        workingDirectory: String = "/",
        environment: [String: String],
        timeout: TimeInterval
    ) -> ProcessOutput {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        process.environment = environment
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return ProcessOutput(exitCode: 127, stdout: "", stderr: error.localizedDescription)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Date() >= deadline {
                process.terminate()
                Thread.sleep(forTimeInterval: 0.3)
                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
                break
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        process.waitUntilExit()
        let out = stdout.fileHandleForReading.readDataToEndOfFile()
        let err = stderr.fileHandleForReading.readDataToEndOfFile()
        return ProcessOutput(
            exitCode: process.terminationStatus,
            stdout: String(data: out, encoding: .utf8) ?? "",
            stderr: String(data: err, encoding: .utf8) ?? ""
        )
    }
}

struct SmokeError: LocalizedError {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var unquoted: String {
        var result = self
        if (result.hasPrefix("\"") && result.hasSuffix("\"")) || (result.hasPrefix("'") && result.hasSuffix("'")) {
            result.removeFirst()
            result.removeLast()
        }
        return result
    }
}
