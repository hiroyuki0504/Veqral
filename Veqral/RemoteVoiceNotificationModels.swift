import Foundation

struct RemoteVoiceCleanupRequest: Codable, Sendable {
    var rawText: String
    var ruleBasedText: String
    var preferredEngine: String?
    var workingDirectory: String?
    var provider: String?
    var model: String?
}

struct RemoteVoiceCleanupResponse: Codable, Sendable {
    var cleanedText: String
    var engine: String?
    var fallbackUsed: Bool
}

struct RemoteNotificationTestResponse: Codable, Sendable {
    var ok: Bool
    var message: String
}
