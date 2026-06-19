import Foundation

// MARK: - Wire models

struct HermesPresetWire: Codable, Sendable, Equatable {
    var id: String
    var label: String
    var model: String
    var provider: String?
    var baseURL: String?
    var contextLength: String?
    var reasoning: String
    var isPlaceholder: Bool
}

struct HermesControlStatusWire: Codable, Sendable {
    var configured: Bool
    var configPath: String
    var vaultPath: String?
    var provider: String?
    var model: String?
    var baseURL: String?
    var contextLength: String?
    var reasoning: String?
    var presets: [HermesPresetWire]
    var pendingApprovalCount: Int
    var note: String?
}

struct HermesControlUpdateRequest: Codable, Sendable {
    var presetID: String?
    var provider: String?
    var model: String?
    var baseURL: String?
    var contextLength: String?
    var reasoning: String?
}

struct HermesControlUpdateResponse: Codable, Sendable {
    var status: HermesControlStatusWire
    var applied: [String]
    var note: String
}

struct HermesApprovalWire: Codable, Sendable, Identifiable {
    var id: String
    var title: String
    var summary: String
    var createdAt: Date?
}

struct HermesApprovalListResponse: Codable, Sendable {
    var approvals: [HermesApprovalWire]
}

struct HermesApprovalDecisionRequest: Codable, Sendable {
    var id: String
    var decision: String
    var note: String?
}

struct HermesApprovalDecisionResponse: Codable, Sendable {
    var id: String
    var decision: String
    var movedTo: String
}

// MARK: - Store

/// Bridges Veqral clients to the Hermes Agent core (`~/.hermes/config.yaml`)
/// and the Obsidian vault approval queue (`90_Org/Approvals`).
/// File-based on purpose: no shell-outs, works while Hermes itself is idle,
/// and the vault stays the single source of truth for approvals/presets.
final class HermesControlStore: Sendable {
    static let reasoningLevels = ["none", "minimal", "low", "medium", "high", "xhigh"]

    private let configPath: String
    private let vaultRoot: String?

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        configPath = (environment["VEQRAL_HERMES_CONFIG"]?.nilIfBlank ?? "~/.hermes/config.yaml").expandingTilde
        vaultRoot = environment["VEQRAL_HERMES_VAULT"]?.nilIfBlank?.expandingTilde
    }

    // MARK: Status

    func status() throws -> HermesControlStatusWire {
        let configured = FileManager.default.fileExists(atPath: configPath)
        let selection = configured ? currentSelection() : (provider: nil, model: nil, baseURL: nil, contextLength: nil, reasoning: nil)
        let presets = loadPresets()
        var note: String?
        if !configured {
            note = "~/.hermes/config.yaml が見つかりません。Mac で hermes setup を実行してください。"
        } else if vaultRoot == nil {
            note = "VEQRAL_HERMES_VAULT が未設定のため、承認キューとプリセットは無効です。"
        }
        return HermesControlStatusWire(
            configured: configured,
            configPath: configPath,
            vaultPath: vaultRoot,
            provider: selection.provider,
            model: selection.model,
            baseURL: selection.baseURL,
            contextLength: selection.contextLength,
            reasoning: selection.reasoning ?? (configured ? "medium" : nil),
            presets: presets,
            pendingApprovalCount: (try? listPendingFiles().count) ?? 0,
            note: note
        )
    }

    // MARK: Update (model / provider / reasoning / preset)

    func update(_ request: HermesControlUpdateRequest) throws -> HermesControlUpdateResponse {
        var provider = request.provider?.nilIfBlank
        var model = request.model?.nilIfBlank
        var baseURL = request.baseURL
        var contextLength = request.contextLength
        var reasoning = request.reasoning?.nilIfBlank

        if let presetID = request.presetID?.nilIfBlank {
            guard let preset = loadPresets().first(where: { $0.id == presetID }) else {
                throw HostError.badRequest("プリセット \(presetID) が presets.md に見つかりません。")
            }
            guard !preset.isPlaceholder else {
                throw HostError.badRequest("プリセット「\(preset.label)」のモデルがプレースホルダのままです。vault の presets.md を編集してください。")
            }
            model = preset.model
            provider = preset.provider ?? provider
            baseURL = preset.baseURL ?? ""
            contextLength = preset.contextLength ?? ""
            reasoning = preset.reasoning
        }

        if let reasoning, !Self.reasoningLevels.contains(reasoning) {
            throw HostError.badRequest("reasoning は \(Self.reasoningLevels.joined(separator: "/")) のいずれかにしてください。")
        }
        guard model != nil || provider != nil || baseURL != nil || contextLength != nil || reasoning != nil else {
            throw HostError.badRequest("変更内容が空です。presetID か model/provider/baseURL/contextLength/reasoning を指定してください。")
        }
        guard FileManager.default.fileExists(atPath: configPath) else {
            throw HostError.badRequest("~/.hermes/config.yaml が見つかりません。先に hermes setup を実行してください。")
        }

        var lines = try String(contentsOfFile: configPath, encoding: .utf8)
            .components(separatedBy: "\n")
        try backupConfig()

        var applied: [String] = []
        if let model {
            lines = Self.settingTopLevelKey(lines, section: "model", key: "default", value: model)
            applied.append("model=\(model)")
        }
        if let provider {
            lines = Self.settingTopLevelKey(lines, section: "model", key: "provider", value: provider)
            applied.append("provider=\(provider)")
        }
        if let baseURL {
            lines = Self.settingTopLevelKey(lines, section: "model", key: "base_url", value: baseURL)
            applied.append(baseURL.nilIfBlank == nil ? "base_url=cleared" : "base_url=\(baseURL)")
        }
        if let contextLength {
            lines = Self.settingTopLevelKey(lines, section: "model", key: "context_length", value: contextLength)
            lines = Self.settingTopLevelKey(lines, section: "model", key: "ollama_num_ctx", value: contextLength)
            applied.append(contextLength.nilIfBlank == nil ? "context_length=cleared" : "context_length=\(contextLength)")
        }
        if let reasoning {
            lines = Self.settingTopLevelKey(lines, section: "agent", key: "reasoning_effort", value: reasoning)
            applied.append("reasoning=\(reasoning)")
        }

        try lines.joined(separator: "\n").write(toFile: configPath, atomically: true, encoding: .utf8)
        return HermesControlUpdateResponse(
            status: try status(),
            applied: applied,
            note: "新しい Hermes セッションから適用されます。実行中のチャットは /model・/reasoning で切り替えてください。"
        )
    }

    private func backupConfig() throws {
        let backupPath = configPath + ".veqral-bak"
        let manager = FileManager.default
        if manager.fileExists(atPath: backupPath) {
            try manager.removeItem(atPath: backupPath)
        }
        try manager.copyItem(atPath: configPath, toPath: backupPath)
    }

    /// Targeted YAML line edit for the two known top-level sections we touch
    /// (`model:` and `agent:`). Intentionally not a full YAML parser: it
    /// preserves untouched lines byte-for-byte and only rewrites/inserts the
    /// requested key. Handles the fresh-install scalar form `model: ""`.
    static func settingTopLevelKey(_ lines: [String], section: String, key: String, value: String) -> [String] {
        var lines = lines
        let quoted = "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""

        guard let sectionIndex = lines.firstIndex(where: { line in
            line == "\(section):" || line.hasPrefix("\(section):")
                && !line.hasPrefix(" ") && !line.hasPrefix("\t") && !line.hasPrefix("#")
        }) else {
            if lines.last?.isEmpty == true { lines.removeLast() }
            lines.append("")
            lines.append("\(section):")
            lines.append("  \(key): \(quoted)")
            lines.append("")
            return lines
        }

        // Legacy scalar form (e.g. `model: ""`): convert to a mapping.
        let header = lines[sectionIndex]
        let afterColon = header.dropFirst(section.count + 1).trimmingCharacters(in: .whitespaces)
        if !afterColon.isEmpty, !afterColon.hasPrefix("#") {
            lines[sectionIndex] = "\(section):"
        }

        var sectionEnd = lines.count
        for index in (sectionIndex + 1)..<lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty, !line.hasPrefix(" "), !line.hasPrefix("\t") {
                sectionEnd = index
                break
            }
        }

        for index in (sectionIndex + 1)..<sectionEnd {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key):") else { continue }
            let indent = lines[index].prefix { $0 == " " || $0 == "\t" }
            lines[index] = "\(indent)\(key): \(quoted)"
            return lines
        }

        lines.insert("  \(key): \(quoted)", at: sectionIndex + 1)
        return lines
    }

    /// Reads the current provider / model / base URL / context length / reasoning from config.yaml with
    /// the same section-aware line scan used for writing.
    func currentSelection() -> (provider: String?, model: String?, baseURL: String?, contextLength: String?, reasoning: String?) {
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return (nil, nil, nil, nil, nil)
        }
        var provider: String?
        var model: String?
        var baseURL: String?
        var contextLength: String?
        var reasoning: String?
        var section: String?
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if !line.hasPrefix(" "), !line.hasPrefix("\t"), let colon = trimmed.firstIndex(of: ":") {
                section = String(trimmed[..<colon])
                let inline = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if section == "model", !inline.isEmpty, !inline.hasPrefix("#") {
                    model = Self.unquoted(inline).nilIfBlank
                }
                continue
            }
            guard let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<colon])
            let rawValue = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            let value = Self.unquoted(rawValue).nilIfBlank
            switch (section, key) {
            case ("model", "default"): model = value ?? model
            case ("model", "provider"): provider = value ?? provider
            case ("model", "base_url"): baseURL = value
            case ("model", "context_length"): contextLength = value
            case ("agent", "reasoning_effort"): reasoning = value ?? reasoning
            default: break
            }
        }
        return (provider, model, baseURL, contextLength, reasoning)
    }

    private static func unquoted(_ value: String) -> String {
        var value = value
        if let comment = value.range(of: " #") { value = String(value[..<comment.lowerBound]) }
        value = value.trimmingCharacters(in: .whitespaces)
        if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        } else if value.count >= 2, value.hasPrefix("'"), value.hasSuffix("'") {
            value = String(value.dropFirst().dropLast())
        }
        return value
    }

    // MARK: Presets (vault/90_Org/presets.md)

    func loadPresets() -> [HermesPresetWire] {
        guard let path = presetsPath,
              let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        var presets: [HermesPresetWire] = []
        var columns: [String: Int]?
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("|") else { continue }
            let cells = trimmed
                .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 3, !Self.isMarkdownSeparatorRow(cells) else { continue }
            if columns == nil {
                let headerColumns = Self.presetColumnMap(cells)
                if headerColumns["label"] != nil, headerColumns["model"] != nil, headerColumns["reasoning"] != nil {
                    columns = headerColumns
                    continue
                }
            }
            let label = Self.tableCell(cells, columns?["label"] ?? 0)
            let model = Self.tableCell(cells, columns?["model"] ?? 1)
            let reasoning = Self.tableCell(cells, columns?["reasoning"] ?? 2).lowercased()
            guard Self.reasoningLevels.contains(reasoning), !label.isEmpty, !model.isEmpty else { continue }
            let provider = Self.tableCell(cells, columns?["provider"] ?? 3).nilIfBlank
            let baseURL = Self.tableCell(cells, columns?["baseURL"] ?? -1).nilIfBlank
            let contextLength = Self.tableCell(cells, columns?["contextLength"] ?? -1).nilIfBlank
            presets.append(HermesPresetWire(
                id: "preset-\(presets.count + 1)",
                label: label,
                model: model,
                provider: provider.flatMap { $0.contains("{{") ? nil : $0 },
                baseURL: baseURL.flatMap { $0.contains("{{") ? nil : $0 },
                contextLength: contextLength.flatMap { $0.contains("{{") ? nil : $0 },
                reasoning: reasoning,
                isPlaceholder: model.contains("{{") || model.contains("}}")
            ))
        }
        return presets
    }

    private static func presetColumnMap(_ headers: [String]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (index, rawHeader) in headers.enumerated() {
            switch rawHeader.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "label", "ラベル":
                result["label"] = index
            case "model", "モデル":
                result["model"] = index
            case "provider", "プロバイダ":
                result["provider"] = index
            case "base url", "base_url", "baseurl":
                result["baseURL"] = index
            case "context length", "context_length", "contextlength":
                result["contextLength"] = index
            case "reasoning", "reasoning_effort", "reasoning effort", "思考深度":
                result["reasoning"] = index
            default:
                continue
            }
        }
        return result
    }

    private static func tableCell(_ cells: [String], _ index: Int) -> String {
        guard index >= 0, index < cells.count else { return "" }
        return cells[index]
    }

    private static func isMarkdownSeparatorRow(_ cells: [String]) -> Bool {
        cells.allSatisfy { cell in
            let stripped = cell.replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "-", with: "")
                .trimmingCharacters(in: .whitespaces)
            return stripped.isEmpty
        }
    }

    // MARK: Approvals (vault/90_Org/Approvals)

    func pendingApprovals() throws -> HermesApprovalListResponse {
        let approvals = try listPendingFiles().map { url -> HermesApprovalWire in
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            return HermesApprovalWire(
                id: url.lastPathComponent,
                title: Self.title(from: content, fallback: url.deletingPathExtension().lastPathComponent),
                summary: Redactor.redact(Self.summary(from: content)),
                createdAt: attributes?[.creationDate] as? Date
            )
        }
        return HermesApprovalListResponse(approvals: approvals)
    }

    func decide(_ request: HermesApprovalDecisionRequest) throws -> HermesApprovalDecisionResponse {
        guard ["approve", "reject"].contains(request.decision) else {
            throw HostError.badRequest("decision は approve / reject のみです。")
        }
        guard let approvalsDir else {
            throw HostError.badRequest("VEQRAL_HERMES_VAULT が未設定です。Host の環境変数に vault ルートを設定してください。")
        }
        let fileName = request.id
        guard !fileName.contains("/"), !fileName.contains(".."), fileName.hasSuffix(".md") else {
            throw HostError.badRequest("不正な承認 ID です。")
        }
        let source = approvalsDir.appendingPathComponent("pending").appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw HostError.badRequest("承認 \(fileName) は既に処理済みか存在しません。")
        }
        let destinationName = request.decision == "approve" ? "approved" : "rejected"
        let destinationDir = approvalsDir.appendingPathComponent(destinationName)
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        let destination = destinationDir.appendingPathComponent(fileName)

        var content = (try? String(contentsOf: source, encoding: .utf8)) ?? ""
        let timestamp = ISO8601DateFormatter().string(from: Date())
        content += "\n\n---\ndecision: \(request.decision)\ndecided_at: \(timestamp)\ndecided_via: veqral\n"
        if let note = request.note?.nilIfBlank {
            content += "note: \(note)\n"
        }
        try content.write(to: destination, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(at: source)

        return HermesApprovalDecisionResponse(
            id: fileName,
            decision: request.decision,
            movedTo: "\(destinationName)/\(fileName)"
        )
    }

    private var approvalsDir: URL? {
        guard let vaultRoot else { return nil }
        return URL(fileURLWithPath: vaultRoot)
            .appendingPathComponent("90_Org")
            .appendingPathComponent("Approvals")
    }

    private var presetsPath: String? {
        guard let vaultRoot else { return nil }
        return URL(fileURLWithPath: vaultRoot)
            .appendingPathComponent("90_Org")
            .appendingPathComponent("presets.md")
            .path
    }

    private func listPendingFiles() throws -> [URL] {
        guard let approvalsDir else { return [] }
        let pending = approvalsDir.appendingPathComponent("pending")
        guard FileManager.default.fileExists(atPath: pending.path) else { return [] }
        return try FileManager.default
            .contentsOfDirectory(at: pending, includingPropertiesForKeys: [.creationDateKey])
            .filter { $0.pathExtension == "md" }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return lhsDate > rhsDate
            }
    }

    private static func title(from content: String, fallback: String) -> String {
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("title:") {
                let value = trimmed.dropFirst("title:".count).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { return unquoted(value) }
            }
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2))
            }
        }
        return fallback
    }

    private static func summary(from content: String) -> String {
        var lines = content.components(separatedBy: "\n")
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---",
           let closing = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
            lines = Array(lines[(closing + 1)...])
        }
        let body = lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("# ") }
            .prefix(12)
            .joined(separator: "\n")
        return String(body.prefix(800))
    }
}
