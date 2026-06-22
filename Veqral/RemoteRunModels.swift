import Foundation

struct RemoteCreateRunResponse: Codable, Sendable {
    var runID: String
    var sessionID: String?
    var status: String
    var approvalRequired: Bool?
    var approvalReason: String?
    var approvalSeverity: String?
}

struct RemoteRunAttachment: Codable, Sendable {
    var id: UUID
    var fileName: String
    var mimeType: String
    var data: Data
}

struct RemoteRunRecord: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var prompt: String
    var workingDirectory: String
    var sessionID: String?
    var status: String
    var startedAt: Date
    var completedAt: Date?
    var exitCode: Int32?
    var pid: Int32?
    var approvalReason: String?
    var approvalSeverity: String?
    var engine: String?
    var resumeSessionID: String?
    var projectID: String?
    var chatID: String?
    var provider: String?
    var model: String?
    var usage: CommandRunUsage?
}

struct RemoteRunListResponse: Codable, Sendable {
    var runs: [RemoteRunRecord]
}

struct RemoteRunLogResponse: Codable, Sendable {
    var logs: [RemoteHostLogEvent]
}

struct RemoteRunSnapshotResponse: Codable, Sendable {
    var run: RemoteRunRecord
    var logs: [RemoteHostLogEvent]
    var diff: [RemoteGitDiffEntry]
    var artifacts: [RemoteArtifactRecord]
}
