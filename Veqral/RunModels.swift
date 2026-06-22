import Foundation
import SwiftUI

enum CommandRuntime: String, Codable, CaseIterable, Identifiable {
    case hermesAgent
    case codexDirect
    case claudeDirect
    case localShell

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hermesAgent: L10n.tr("Hermes Agent")
        case .codexDirect: L10n.tr("Codex Direct")
        case .claudeDirect: L10n.tr("Claude Direct")
        case .localShell: L10n.tr("Local Shell")
        }
    }

    var shortTitle: String {
        switch self {
        case .hermesAgent: "Hermes"
        case .codexDirect: "Codex"
        case .claudeDirect: "Claude"
        case .localShell: "Shell"
        }
    }

    var symbol: String {
        switch self {
        case .hermesAgent: "sparkles"
        case .codexDirect: "curlybraces.square"
        case .claudeDirect: "text.bubble"
        case .localShell: "terminal"
        }
    }

    var remoteEngine: String {
        switch self {
        case .hermesAgent:
            "hermes"
        case .codexDirect:
            "codex"
        case .claudeDirect:
            "claude"
        case .localShell:
            "shell"
        }
    }

    var usesRemoteAgent: Bool {
        self != .localShell
    }

    var contextModeDescription: String {
        switch self {
        case .hermesAgent:
            L10n.tr("Unified Hermes project memory")
        case .codexDirect, .claudeDirect:
            L10n.tr("Siloed native tool history")
        case .localShell:
            L10n.tr("No agent memory")
        }
    }
}

struct CommandRunUsage: Codable, Equatable, Sendable {
    var inputTokens: Int? = nil
    var outputTokens: Int? = nil
    var cacheReadTokens: Int? = nil
    var cacheWriteTokens: Int? = nil
    var reasoningTokens: Int? = nil
    var totalTokens: Int? = nil
    var estimatedCostUSD: Double? = nil
    var actualCostUSD: Double? = nil
    var source: String? = nil
    var model: String? = nil

    var totalTokensOrDerived: Int? {
        if let totalTokens { return totalTokens }
        let total = [inputTokens, outputTokens, reasoningTokens].compactMap { $0 }.reduce(0, +)
        return total > 0 ? total : nil
    }

    var costUSD: Double? {
        actualCostUSD ?? estimatedCostUSD
    }

    var hasDisplayValues: Bool {
        inputTokens != nil
            || outputTokens != nil
            || cacheReadTokens != nil
            || cacheWriteTokens != nil
            || reasoningTokens != nil
            || totalTokensOrDerived != nil
            || costUSD != nil
    }
}

struct SavedCommandDraft: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var command: String
    var runtime: CommandRuntime?
    var createdAt: Date
    var updatedAt: Date
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
    var resumeSessionID: String? = nil
    var agentProjectID: String? = nil
    var agentChatID: String? = nil
    var provider: String? = nil
    var providerModel: String? = nil
    var usage: CommandRunUsage? = nil

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
        risk == "高" ? L10n.tr("Risk: High") : L10n.tr("Risk: Medium")
    }

    var symbolName: String {
        tintName == "amber" ? "key" : "exclamationmark.triangle"
    }

    var requiresPreApprovalReview: Bool {
        risk == "高" || tintName == "red"
    }
}

struct CommandDiffEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var runID: UUID
    var path: String
    var additions: Int
    var deletions: Int
    var patch: String?
}

struct CommandAttachment: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var fileName: String
    var mimeType: String
    var data: Data
    var createdAt: Date

    var byteCount: Int {
        data.count
    }
}
