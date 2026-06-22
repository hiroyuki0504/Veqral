import Foundation

struct RemoteProjectCostSummary: Codable, Identifiable, Equatable, Sendable {
    var projectKey: String
    var projectID: String?
    var workingDirectory: String?
    var displayName: String
    var runCount: Int
    var inputTokens: Int
    var outputTokens: Int
    var reasoningTokens: Int
    var totalTokens: Int
    var estimatedCostUSD: Double
    var actualCostUSD: Double
    var costUSD: Double
    var budgetLimitUSD: Double?
    var thresholdPercent: Double
    var paused: Bool
    var isNearLimit: Bool
    var isOverLimit: Bool

    var id: String { projectKey }
}

struct RemoteProjectBudgetListResponse: Codable, Sendable {
    var summaries: [RemoteProjectCostSummary]
}

struct RemoteProjectBudgetUpdateRequest: Codable, Sendable {
    var projectKey: String?
    var projectID: String?
    var workingDirectory: String?
    var displayName: String?
    var limitUSD: Double?
    var thresholdPercent: Double?
    var paused: Bool?
}
