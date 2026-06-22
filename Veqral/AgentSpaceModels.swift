import Foundation

struct AgentChatSpace: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var sessionID: String?
    var provider: String
    var model: String
    var createdAt: Date
    var updatedAt: Date
}

struct AgentProjectSpace: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var workingDirectory: String
    var createdAt: Date
    var chats: [AgentChatSpace]
}

struct HermesModelChoice: Codable, Equatable, Identifiable {
    var id: String { provider.isEmpty ? model : "\(provider):\(model)" }
    var provider: String
    var model: String
    var title: String

    static let defaults: [HermesModelChoice] = [
        HermesModelChoice(provider: "auto", model: "", title: "Hermes Auto"),
        HermesModelChoice(provider: "anthropic", model: "claude-sonnet-4", title: "Claude Sonnet"),
        HermesModelChoice(provider: "openai", model: "gpt-5", title: "GPT-5"),
        HermesModelChoice(provider: "openai", model: "codex", title: "Codex")
    ]
}
