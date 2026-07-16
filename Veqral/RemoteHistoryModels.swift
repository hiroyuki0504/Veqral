import Foundation

enum RemoteHistoryTool: String, Codable, CaseIterable, Identifiable, Sendable {
    case hermes
    case claude
    case codex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hermes:
            "Hermes"
        case .claude:
            "Claude"
        case .codex:
            "Codex"
        }
    }
}

struct RemoteHistorySession: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var tool: RemoteHistoryTool
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
    var provider: String?
    var billingMode: String?
    var canContinue: Bool?
    var continueBlockedReason: String?
}

struct RemoteHistoryListResponse: Codable, Sendable {
    var sessions: [RemoteHistorySession]
    var total: Int
    var page: Int
    var limit: Int
    var projects: [String]
    var tools: [RemoteHistoryTool]
    var warnings: [String]?
}

struct RemoteHistoryTurn: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var role: String
    var kind: String
    var timestamp: Date?
    var text: String
    var metadata: String?
}

struct RemoteHistoryDetailResponse: Codable, Sendable {
    var session: RemoteHistorySession
    var turns: [RemoteHistoryTurn]
    var truncated: Bool
    var returnedBytes: Int?
    var truncationReason: String?
}
