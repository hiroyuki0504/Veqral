import Foundation

struct RemoteMemoryFile: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var kind: String
    var path: String
    var relativePath: String
    var updatedAt: Date?
    var bytes: Int
    var isEditable: Bool
}

struct RemoteMemoryListResponse: Codable, Sendable {
    var files: [RemoteMemoryFile]
}

struct RemoteMemoryContentResponse: Codable, Sendable {
    var file: RemoteMemoryFile
    var content: String
}

struct RemoteProjectMemoryRequest: Codable, Sendable {
    var projectID: String
    var projectName: String?
}

struct RemoteProjectMemorySession: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var model: String?
    var title: String?
    var startedAt: Date?
    var endedAt: Date?
    var messageCount: Int
    var inputTokens: Int
    var outputTokens: Int
    var estimatedCostUSD: Double?
}

struct RemoteProjectMemoryResponse: Codable, Equatable, Sendable {
    var projectID: String
    var projectName: String
    var source: String
    var memoryFile: RemoteMemoryFile
    var memoryContent: String
    var sessions: [RemoteProjectMemorySession]
    var warnings: [String]
}

struct RemoteMemoryDiffResponse: Codable, Sendable {
    var id: String
    var diff: String
    var hasChanges: Bool
}

struct RemoteMemoryWriteResponse: Codable, Sendable {
    var file: RemoteMemoryFile
    var diff: String
    var hasChanges: Bool
}
