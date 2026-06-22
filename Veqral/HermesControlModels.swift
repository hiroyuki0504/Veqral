import Foundation

struct HermesControlPreset: Codable, Identifiable, Equatable {
    var id: String
    var label: String
    var model: String
    var policy: String?
    var resolvedModel: String?
    var provider: String?
    var baseURL: String?
    var contextLength: String?
    var reasoning: String
    var isPlaceholder: Bool
}

struct HermesControlStatus: Codable {
    var configured: Bool
    var configPath: String
    var vaultPath: String?
    var provider: String?
    var model: String?
    var baseURL: String?
    var contextLength: String?
    var reasoning: String?
    var presets: [HermesControlPreset]
    var pendingApprovalCount: Int
    var note: String?
}

struct HermesControlUpdate: Codable {
    var presetID: String?
    var provider: String?
    var model: String?
    var baseURL: String?
    var contextLength: String?
    var reasoning: String?
}

struct HermesControlUpdateResult: Codable {
    var status: HermesControlStatus
    var applied: [String]
    var note: String
}

struct HermesApprovalItem: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var summary: String
    var createdAt: Date?
}

struct HermesApprovalList: Codable {
    var approvals: [HermesApprovalItem]
}
