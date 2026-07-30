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

struct RemoteRunApprovalProvenance: Codable, Equatable, Sendable {
    var state: String
    var grantedAt: Date?
    var grantedByDeviceID: String?
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
    var interaction: CommandInteractionPrompt? = nil
    var statusUpdatedAt: Date? = nil
    var taskID: String? = nil
    var approvalProvenance: RemoteRunApprovalProvenance? = nil
}

struct RemoteHandoffRecord: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var taskID: String
    var runID: String
    var sourceWorkstreamID: String
    var targetWorkstreamID: String?
    var artifactIDs: [String]
    var summary: String
    var state: ForgeHandoffState
    var createdAt: Date
    var reviewedAt: Date?
}

struct RemoteRunListResponse: Codable, Sendable {
    var runs: [RemoteRunRecord]
    var handoffs: [RemoteHandoffRecord]
}

struct RemoteRunLogResponse: Codable, Sendable {
    var logs: [RemoteHostLogEvent]
}

struct RemoteRunSnapshotResponse: Codable, Sendable {
    var run: RemoteRunRecord
    var logs: [RemoteHostLogEvent]
    var diff: [RemoteGitDiffEntry]
    var artifacts: [RemoteArtifactRecord]
    var handoffs: [RemoteHandoffRecord]
}
