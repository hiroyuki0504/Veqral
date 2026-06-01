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
              VEQRAL_MEMTEST_BASE_URL_A, VEQRAL_MEMTEST_API_MODE_A
              VEQRAL_MEMTEST_API_KEY_A, VEQRAL_MEMTEST_API_KEY_ACCOUNT_A
              VEQRAL_MEMTEST_PROVIDER_B, VEQRAL_MEMTEST_MODEL_B
              VEQRAL_MEMTEST_BASE_URL_B, VEQRAL_MEMTEST_API_MODE_B
              VEQRAL_MEMTEST_API_KEY_B, VEQRAL_MEMTEST_API_KEY_ACCOUNT_B
              VEQRAL_MEMTEST_SOURCE
              VEQRAL_MEMTEST_KEYCHAIN_SERVICE
              VEQRAL_MEMTEST_OPENROUTER_KEY_ACCOUNT
              VEQRAL_MEMTEST_ANTHROPIC_KEY_ACCOUNT
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
        var baseURL: String?
        var apiMode: String?
        var apiKey: String?
        var apiKeyEnvironmentName: String?
        var credentialDescription: String

        var label: String {
            "\(provider)/\(model)"
        }

        static func == (lhs: ModelSelection, rhs: ModelSelection) -> Bool {
            lhs.provider == rhs.provider
                && lhs.model == rhs.model
                && lhs.baseURL == rhs.baseURL
                && lhs.apiMode == rhs.apiMode
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
        let modelA = modelSelection(
            suffix: "A",
            fallbackProvider: config.provider ?? "openai-codex",
            fallbackModel: config.model ?? "gpt-5.5",
            fallbackBaseURL: config.baseURL
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
        transcript.append("- Hermes home: isolated temporary home (`\(hermesHome.lastPathComponent)`)")
        transcript.append("- Chat A: `\(modelA.label)`")
        transcript.append("- Chat B: `\(modelB?.label ?? "not configured")`")
        transcript.append("- Chat A credential source: \(modelA.credentialDescription)")
        transcript.append("- Chat B credential source: \(modelB?.credentialDescription ?? "not configured")")
        transcript.append("- Code name: `\(codeName)`")
        transcript.append("")

        guard let modelB else {
            transcript.append("## Result")
            transcript.append("")
            transcript.append("FAIL: model swap test impossible because only one configured real model was detected. Set `VEQRAL_MEMTEST_PROVIDER_B` and `VEQRAL_MEMTEST_MODEL_B`, or configure a second Hermes provider/model, then rerun.")
            transcript.append("")
            transcript.append("Required credential receivers are documented in `PROGRESS.md` and `README.md`. 偽 pass は作っていません。")
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

        let preflightFindings = preflightFindings(modelA: modelA, modelB: modelB)
        if !preflightFindings.isEmpty {
            transcript.append("## Credential / Provider Preflight")
            transcript.append("")
            for finding in preflightFindings {
                transcript.append("- \(finding)")
            }
            transcript.append("")
            transcript.append("## Result")
            transcript.append("")
            transcript.append("FAIL: Hermes memory inheritance was not run because at least one real provider/model route is not ready. 偽 pass は作っていません。")
            try writeReport(transcript, to: reportPath)
            return VerificationResult(
                passed: false,
                exitCode: 2,
                summary: "FAIL: Hermes memory inheritance preflight is missing real provider credentials or a reachable local model. See \(reportPath)."
            )
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
        transcript.append(fenced(redacted(write.combinedTrimmed, extraSecrets: [modelA.apiKey, modelB.apiKey].compactMap { $0 })))
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
        transcript.append(fenced(redacted(read.combinedTrimmed, extraSecrets: [modelA.apiKey, modelB.apiKey].compactMap { $0 })))
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
            return modelSelection(suffix: "B", fallbackProvider: provider, fallbackModel: model, fallbackBaseURL: nil)
        }
        if hasCredential(environmentName: "OPENROUTER_API_KEY", keychainAccount: openRouterKeychainAccount()) {
            return modelSelection(
                suffix: "B",
                fallbackProvider: "openrouter",
                fallbackModel: "google/gemini-2.5-flash",
                fallbackBaseURL: nil
            )
        }
        if hasCredential(environmentName: "ANTHROPIC_API_KEY", keychainAccount: anthropicKeychainAccount()) {
            return modelSelection(
                suffix: "B",
                fallbackProvider: "anthropic",
                fallbackModel: "claude-haiku-4-5",
                fallbackBaseURL: nil
            )
        }
        return nil
    }

    private func modelSelection(
        suffix: String,
        fallbackProvider: String,
        fallbackModel: String,
        fallbackBaseURL: String?
    ) -> ModelSelection {
        let provider = environment["VEQRAL_MEMTEST_PROVIDER_\(suffix)"]?.nilIfBlank ?? fallbackProvider
        let model = environment["VEQRAL_MEMTEST_MODEL_\(suffix)"]?.nilIfBlank ?? fallbackModel
        let baseURL = environment["VEQRAL_MEMTEST_BASE_URL_\(suffix)"]?.nilIfBlank ?? fallbackBaseURL
        let apiMode = environment["VEQRAL_MEMTEST_API_MODE_\(suffix)"]?.nilIfBlank
        let credential = credential(forProvider: provider, suffix: suffix, baseURL: baseURL)
        return ModelSelection(
            provider: provider,
            model: model,
            baseURL: baseURL,
            apiMode: apiMode,
            apiKey: credential.value,
            apiKeyEnvironmentName: credential.environmentName,
            credentialDescription: credential.description
        )
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
        if let apiKey = selection.apiKey?.nilIfBlank,
           let apiKeyEnvironmentName = selection.apiKeyEnvironmentName?.nilIfBlank {
            env[apiKeyEnvironmentName] = apiKey
        }
        return ProcessRunner.run(hermes, args, workingDirectory: cwd.path, environment: env, timeout: timeout)
    }

    private func preflightFindings(modelA: ModelSelection, modelB: ModelSelection) -> [String] {
        [("Chat A", modelA), ("Chat B", modelB)].flatMap { pair in
            preflightFindings(label: pair.0, selection: pair.1)
        }
    }

    private func preflightFindings(label: String, selection: ModelSelection) -> [String] {
        var findings: [String] = []
        switch selection.provider {
        case "openrouter":
            if selection.apiKey?.nilIfBlank == nil {
                findings.append("\(label) uses `openrouter`, but `OPENROUTER_API_KEY` is not set and Keychain account `\(openRouterKeychainAccount())` is empty.")
            }
        case "anthropic":
            if selection.apiKey?.nilIfBlank == nil {
                findings.append("\(label) uses `anthropic`, but `ANTHROPIC_API_KEY` is not set and Keychain account `\(anthropicKeychainAccount())` is empty.")
            }
        case "custom":
            guard let baseURL = selection.baseURL?.nilIfBlank else {
                findings.append("\(label) uses `custom`, but `VEQRAL_MEMTEST_BASE_URL_\(labelSuffix(label))` is not set.")
                return findings
            }
            if isLocalOllamaBaseURL(baseURL) {
                let tags = ProcessRunner.run(
                    "/usr/bin/curl",
                    ["--silent", "--show-error", "--max-time", "2", "http://127.0.0.1:11434/api/tags"],
                    environment: environment,
                    timeout: 3
                )
                if tags.exitCode != 0 {
                    findings.append("\(label) points at local Ollama, but `http://127.0.0.1:11434/api/tags` is not reachable. Start Ollama and pull the configured model before rerunning.")
                } else if !tags.combinedTrimmed.contains("\"\(selection.model)\"") {
                    findings.append("\(label) points at local Ollama, but model `\(selection.model)` was not listed by `/api/tags`. Pull it with `ollama pull \(selection.model)` or set `VEQRAL_MEMTEST_MODEL_\(labelSuffix(label))` to an installed model.")
                }
            } else if selection.apiKey?.nilIfBlank == nil {
                findings.append("\(label) uses a non-local custom endpoint, but no `VEQRAL_MEMTEST_API_KEY_\(labelSuffix(label))` or Keychain account was provided.")
            }
        default:
            break
        }
        return findings
    }

    private func labelSuffix(_ label: String) -> String {
        label.hasSuffix("A") ? "A" : "B"
    }

    private func credential(forProvider provider: String, suffix: String, baseURL: String?) -> (value: String?, environmentName: String?, description: String) {
        switch provider {
        case "openrouter":
            return credential(
                environmentName: "OPENROUTER_API_KEY",
                explicitValueName: nil,
                explicitAccountName: nil,
                defaultAccount: openRouterKeychainAccount()
            )
        case "anthropic":
            return credential(
                environmentName: "ANTHROPIC_API_KEY",
                explicitValueName: nil,
                explicitAccountName: nil,
                defaultAccount: anthropicKeychainAccount()
            )
        case "custom":
            let explicitValueName = "VEQRAL_MEMTEST_API_KEY_\(suffix)"
            let explicitAccountName = "VEQRAL_MEMTEST_API_KEY_ACCOUNT_\(suffix)"
            if let baseURL, isLocalOllamaBaseURL(baseURL), environment[explicitValueName]?.nilIfBlank == nil, environment[explicitAccountName]?.nilIfBlank == nil {
                return (value: "ollama", environmentName: "OPENAI_API_KEY", description: "local Ollama placeholder (`OPENAI_API_KEY=ollama`)")
            }
            return credential(
                environmentName: "OPENAI_API_KEY",
                explicitValueName: explicitValueName,
                explicitAccountName: explicitAccountName,
                defaultAccount: nil
            )
        default:
            return (value: nil, environmentName: nil, description: "provider-managed auth")
        }
    }

    private func credential(
        environmentName: String,
        explicitValueName: String?,
        explicitAccountName: String?,
        defaultAccount: String?
    ) -> (value: String?, environmentName: String?, description: String) {
        if let explicitValueName,
           let value = environment[explicitValueName]?.nilIfBlank {
            return (value: value, environmentName: environmentName, description: "env `\(explicitValueName)`")
        }
        if let value = environment[environmentName]?.nilIfBlank {
            return (value: value, environmentName: environmentName, description: "env `\(environmentName)`")
        }
        let account = explicitAccountName.flatMap { environment[$0]?.nilIfBlank } ?? defaultAccount
        if let account,
           let value = keychainValue(account: account)?.nilIfBlank {
            return (value: value, environmentName: environmentName, description: "Keychain account `\(account)`")
        }
        if let account {
            return (value: nil, environmentName: environmentName, description: "missing env `\(environmentName)` / Keychain account `\(account)`")
        }
        return (value: nil, environmentName: environmentName, description: "missing env `\(environmentName)`")
    }

    private func hasCredential(environmentName: String, keychainAccount: String) -> Bool {
        environment[environmentName]?.nilIfBlank != nil || keychainValue(account: keychainAccount)?.nilIfBlank != nil
    }

    private func keychainValue(account: String) -> String? {
        let service = environment["VEQRAL_MEMTEST_KEYCHAIN_SERVICE"]?.nilIfBlank ?? "dev.hiroyuki.veqral.host"
        let result = ProcessRunner.run(
            "/usr/bin/security",
            ["find-generic-password", "-s", service, "-a", account, "-w"],
            environment: environment,
            timeout: 5
        )
        guard result.exitCode == 0 else {
            return nil
        }
        return result.stdout.nilIfBlank
    }

    private func openRouterKeychainAccount() -> String {
        environment["VEQRAL_MEMTEST_OPENROUTER_KEY_ACCOUNT"]?.nilIfBlank ?? "openrouter:api-key"
    }

    private func anthropicKeychainAccount() -> String {
        environment["VEQRAL_MEMTEST_ANTHROPIC_KEY_ACCOUNT"]?.nilIfBlank ?? "anthropic:api-key"
    }

    private func isLocalOllamaBaseURL(_ baseURL: String) -> Bool {
        baseURL.contains("127.0.0.1:11434") || baseURL.contains("localhost:11434")
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

    private func redacted(_ text: String, extraSecrets: [String] = []) -> String {
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
        for secret in extraSecrets where secret.count >= 8 {
            output = output.replacingOccurrences(of: secret, with: "[REDACTED]")
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
        var lines = [
            "model:",
            "  provider: \(model.provider)",
            "  default: \(model.model)"
        ]
        if let baseURL = model.baseURL?.nilIfBlank {
            lines.append("  base_url: \(baseURL)")
        }
        if let apiMode = model.apiMode?.nilIfBlank {
            lines.append("  api_mode: \(apiMode)")
        }
        lines.append(contentsOf: [
            "toolsets:",
            "- memory",
            "agent:",
            "  max_turns: 12",
            "  verbose: false",
            "checkpoints:",
            "  enabled: false"
        ])
        let config = lines.joined(separator: "\n") + "\n"
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
    var baseURL: String?

    static func load() -> HermesConfig {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".hermes/config.yaml")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return HermesConfig()
        }
        var inModel = false
        var provider: String?
        var model: String?
        var baseURL: String?
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
            } else if trimmed.hasPrefix("base_url:") {
                baseURL = String(trimmed.dropFirst("base_url:".count)).trimmingCharacters(in: .whitespacesAndNewlines).unquoted.nilIfBlank
            }
        }
        return HermesConfig(provider: provider, model: model, baseURL: baseURL)
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
