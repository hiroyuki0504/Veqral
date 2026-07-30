import Foundation

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
}

enum CommandInteractionKind: String, Codable, Equatable, Sendable {
    case choice
    case message
}

struct CommandInteractionChoice: Codable, Equatable, Sendable, Identifiable {
    var value: String
    var label: String

    var id: String { value }
}

struct CommandInteractionPrompt: Codable, Equatable, Sendable {
    var kind: CommandInteractionKind
    var prompt: String
    var choices: [CommandInteractionChoice]

    var isChoicePrompt: Bool {
        kind == .choice && !choices.isEmpty
    }
}
