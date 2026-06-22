import Foundation

enum PortfolioAssetKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case app
    case engagement
    case content

    var id: String { rawValue }

    var title: String {
        switch self {
        case .app: L10n.tr("App")
        case .engagement: L10n.tr("Engagement")
        case .content: L10n.tr("Content")
        }
    }
}

enum PortfolioAssetStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case running
    case stopped
    case unknown
    case notApplicable = "n/a"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .running: L10n.tr("Running")
        case .stopped: L10n.tr("Stopped")
        case .unknown: L10n.tr("Unknown")
        case .notApplicable: L10n.tr("N/A")
        }
    }
}

enum PortfolioBackupState: String, Codable, Sendable {
    case git
    case localOnly = "local-only"
}

struct PortfolioLocalPath: Codable, Equatable, Sendable {
    var machineId: String
    var path: String
}

struct PortfolioSourceRefs: Codable, Equatable, Sendable {
    var github: String?
    var driveUrl: String?
    var localPaths: [PortfolioLocalPath]
}

struct PortfolioHealthSpec: Codable, Equatable, Sendable {
    var type: String
    var target: String
}

struct PortfolioLogSource: Codable, Equatable, Sendable {
    var path: String?
    var cmd: String?
}

struct PortfolioControls: Codable, Equatable, Sendable {
    var start: String?
    var stop: String?
    var restart: String?
    var deploy: String?
}

struct PortfolioDeliverable: Codable, Identifiable, Equatable, Sendable {
    var id: String { "\(name):\(ref)" }
    var name: String
    var ref: String
}

struct PortfolioAsset: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var kind: PortfolioAssetKind
    var name: String
    var summary: String
    var status: PortfolioAssetStatus
    var sourceRefs: PortfolioSourceRefs
    var tags: [String]
    var runtimeHost: String?
    var healthSpec: PortfolioHealthSpec?
    var logSource: PortfolioLogSource?
    var controls: PortfolioControls?
    var linkedProjectId: String?
    var backupState: PortfolioBackupState
    var client: String?
    var phase: String?
    var deliverables: [PortfolioDeliverable]
    var timeline: String?
    var relatedAssetIds: [String]
    var createdAt: Date
    var updatedAt: Date

    static func empty(kind: PortfolioAssetKind = .app) -> PortfolioAsset {
        let now = Date()
        return PortfolioAsset(
            id: UUID().uuidString.lowercased(),
            kind: kind,
            name: "",
            summary: "",
            status: kind == .content ? .notApplicable : .unknown,
            sourceRefs: PortfolioSourceRefs(github: nil, driveUrl: nil, localPaths: []),
            tags: [],
            runtimeHost: nil,
            healthSpec: nil,
            logSource: nil,
            controls: PortfolioControls(start: nil, stop: nil, restart: nil, deploy: nil),
            linkedProjectId: nil,
            backupState: .localOnly,
            client: nil,
            phase: nil,
            deliverables: [],
            timeline: nil,
            relatedAssetIds: [],
            createdAt: now,
            updatedAt: now
        )
    }
}

struct RemotePortfolioAssetListResponse: Codable, Sendable {
    var assets: [PortfolioAsset]
}

struct RemotePortfolioStatusResponse: Codable, Equatable, Sendable {
    var assetID: String
    var status: PortfolioAssetStatus
    var health: String
    var pid: Int32?
    var cpuPercent: Double?
    var memoryMB: Double?
    var checkedAt: Date
}

struct RemotePortfolioLogsResponse: Codable, Sendable {
    var assetID: String
    var lines: [String]
}

struct RemotePortfolioSummaryResponse: Codable, Sendable {
    var assetID: String
    var summary: String
    var generatedAt: Date
}

struct PortfolioRecentCommit: Codable, Identifiable, Equatable, Sendable {
    var sha: String
    var message: String
    var author: String
    var date: Date

    var id: String { sha }
    var shortSHA: String { String(sha.prefix(7)) }
}

struct RemotePortfolioCommitsResponse: Codable, Sendable {
    var assetID: String
    var commits: [PortfolioRecentCommit]
}

struct RemotePortfolioControlResponse: Codable, Sendable {
    var runID: String
    var approvalRequired: Bool
    var status: String
}

struct RemotePortfolioPromoteResponse: Codable, Sendable {
    var runID: String
    var approvalRequired: Bool
}
