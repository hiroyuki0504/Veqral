import Foundation

/// The only execution engines exposed by the Forge data layer.
enum ForgeRuntime: String, Codable, CaseIterable, Identifiable, Sendable {
    case hermes
    case codex
    case claude

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hermes: "Hermes"
        case .codex: "Codex"
        case .claude: "Claude"
        }
    }
}

struct ForgeRunAttachment: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var fileName: String
    var mimeType: String
    var data: Data

    init(id: UUID = UUID(), fileName: String, mimeType: String, data: Data) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = data
    }
}

/// A remote run request. Provider and model stay optional so routing remains host/user configured.
struct ForgeRunRequest: Equatable, Sendable {
    var prompt: String
    var workingDirectory: String
    var runtime: ForgeRuntime
    var resumeSessionID: String?
    var projectID: String?
    var taskID: String
    var chatID: String?
    var provider: String?
    var model: String?
    var attachments: [ForgeRunAttachment]

    init(
        prompt: String,
        workingDirectory: String,
        runtime: ForgeRuntime,
        resumeSessionID: String? = nil,
        projectID: String? = nil,
        taskID: String = "task:\(UUID().uuidString.lowercased())",
        chatID: String? = nil,
        provider: String? = nil,
        model: String? = nil,
        attachments: [ForgeRunAttachment] = []
    ) {
        self.prompt = prompt
        self.workingDirectory = workingDirectory
        self.runtime = runtime
        self.resumeSessionID = resumeSessionID
        self.projectID = projectID
        self.taskID = taskID
        self.chatID = chatID
        self.provider = provider
        self.model = model
        self.attachments = attachments
    }
}

typealias ForgeCreateRunRequest = ForgeRunRequest

/// Persistable host metadata. The device token is deliberately not part of this type.
struct ForgeHostConfiguration: Codable, Equatable, Sendable {
    var endpoint: String
    var deviceID: String
    var name: String
    var apiProtocolVersion: Int?
    var minimumAuthVersion: Int?

    var isConfigured: Bool {
        !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !deviceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
