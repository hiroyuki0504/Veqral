import Foundation
import SwiftUI
import Darwin
import CryptoKit
import Security
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

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

enum SalesLeadStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case new
    case auditReady = "audit_ready"
    case proposalReady = "proposal_ready"
    case contacted
    case won
    case lost
    case doNotContact = "do_not_contact"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .new: "未対応"
        case .auditReady: "監査済み"
        case .proposalReady: "提案準備"
        case .contacted: "連絡済み"
        case .won: "受注"
        case .lost: "失注"
        case .doNotContact: "連絡しない"
        }
    }

    var tint: Color {
        switch self {
        case .new: VQTheme.steel
        case .auditReady: VQTheme.accent
        case .proposalReady: VQTheme.amber
        case .contacted: VQTheme.ink
        case .won: VQTheme.green
        case .lost, .doNotContact: VQTheme.unavailable
        }
    }
}

struct SalesLead: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var businessName: String
    var category: String
    var area: String
    var officialWebsiteURL: String?
    var googleMapsURL: String?
    var googlePlaceID: String?
    var phone: String?
    var email: String?
    var status: SalesLeadStatus
    var notes: String
    var latestAudit: WebsiteAudit?
    var latestRedesignMock: RedesignMock?
    var latestProposal: Proposal?
    var portfolioAssetID: String?
    var hermesHandoffPath: String?
    var outreachLogs: [OutreachLog]
    var createdAt: Date
    var updatedAt: Date

    static func empty() -> SalesLead {
        let now = Date()
        return SalesLead(
            id: UUID().uuidString.lowercased(),
            businessName: "",
            category: "",
            area: "",
            officialWebsiteURL: nil,
            googleMapsURL: nil,
            googlePlaceID: nil,
            phone: nil,
            email: nil,
            status: .new,
            notes: "",
            latestAudit: nil,
            latestRedesignMock: nil,
            latestProposal: nil,
            portfolioAssetID: nil,
            hermesHandoffPath: nil,
            outreachLogs: [],
            createdAt: now,
            updatedAt: now
        )
    }
}

struct WebsiteAudit: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var leadID: String
    var url: String
    var mobileViewport: String
    var score: Int
    var summary: String
    var findings: [WebsiteAuditFinding]
    var businessImpacts: [String]
    var screenshotPath: String
    var lighthouseSummaryPath: String?
    var createdAt: Date
}

struct WebsiteAuditFinding: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var severity: String
    var title: String
    var detail: String
    var recommendation: String
}

struct RedesignMock: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var leadID: String
    var headline: String
    var subheadline: String
    var cta: String
    var htmlPath: String
    var screenshotPath: String
    var notes: String
    var createdAt: Date
    var approvedAt: Date?
}

struct Proposal: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var leadID: String
    var title: String
    var htmlPath: String
    var pdfPath: String?
    var imagePath: String?
    var summary: String
    var pricing: [String]
    var emailDraft: String
    var dmDraft: String
    var phoneScript: String
    var approvalStatus: String
    var createdAt: Date
    var approvedAt: Date?
}

struct OutreachLog: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var channel: String
    var note: String
    var createdAt: Date
}

struct RemoteSalesLeadListResponse: Codable, Sendable {
    var leads: [SalesLead]
}

struct RemoteSalesCSVImportResponse: Codable, Sendable {
    var imported: Int
    var skipped: Int
    var leads: [SalesLead]
}

struct RemoteSalesLeadAsset: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var kind: String
    var path: String
    var createdAt: Date?
}

struct RemoteSalesLeadAssetsResponse: Codable, Sendable {
    var leadID: String
    var assets: [RemoteSalesLeadAsset]
}

struct RemoteSalesPortfolioPromotionResponse: Codable, Sendable {
    var lead: SalesLead
    var asset: PortfolioAsset
}

struct RemoteSalesHermesHandoffResponse: Codable, Sendable {
    var lead: SalesLead
    var notePath: String
    var note: String
}

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

enum RemoteHistoryTool: String, Codable, CaseIterable, Identifiable, Sendable {
    case claude
    case codex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claude:
            "Claude"
        case .codex:
            "Codex"
        }
    }
}

struct RemoteHistorySession: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var tool: RemoteHistoryTool
    var resumeID: String?
    var project: String
    var projectPath: String
    var startedAt: Date?
    var updatedAt: Date?
    var messageCount: Int
    var model: String?
    var summary: String
    var filePath: String
    var bytes: Int
}

struct RemoteHistoryListResponse: Codable, Sendable {
    var sessions: [RemoteHistorySession]
    var total: Int
    var page: Int
    var limit: Int
    var projects: [String]
    var tools: [RemoteHistoryTool]
    var warnings: [String]?
}

struct RemoteHistoryTurn: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var role: String
    var kind: String
    var timestamp: Date?
    var text: String
    var metadata: String?
}

struct RemoteHistoryDetailResponse: Codable, Sendable {
    var session: RemoteHistorySession
    var turns: [RemoteHistoryTurn]
    var truncated: Bool
}

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

@MainActor
final class CommandCenterStore: ObservableObject {
    @Published var runs: [CommandRun]
    @Published var approvals: [CommandApproval]
    @Published var logs: [CommandLogEntry]
    @Published var diffs: [CommandDiffEntry]
    @Published var selectedRunID: UUID?
    @Published var commandDraft: String = ""
    @Published var selectedRuntime: CommandRuntime {
        didSet {
            guard isReadyForAutosave, oldValue != selectedRuntime else { return }
            persist()
        }
    }
    @Published var remoteHost: RemoteHostConfiguration {
        didSet {
            guard isReadyForAutosave, oldValue != remoteHost else { return }
            persist()
        }
    }
    @Published var pairingToken: String = ""
    @Published var workspace: WorkspaceSnapshot
    @Published var remoteMemoryFiles: [RemoteMemoryFile] = []
    @Published var selectedRemoteMemoryID: String?
    @Published var remoteMemoryContent: String = ""
    @Published var remoteMemoryDiff: String = ""
    @Published var remoteMemoryMessage: String = ""
    @Published var isLoadingRemoteMemory = false
    @Published var remoteProjectMemory: RemoteProjectMemoryResponse?
    @Published var remoteProjectMemoryMessage: String = ""
    @Published var remoteProjectMemoryLastFetchedAt: Date?
    @Published var isLoadingRemoteProjectMemory = false
    @Published var remoteHostMessage: String = ""
    @Published var remoteHostHealth: RemoteHealthResponse?
    @Published var authOnboardingStatus: RemoteAuthOnboardingStatus?
    @Published var authOnboardingMessage: String = ""
    @Published var remoteHostTelemetry: RemoteHostTelemetry?
    @Published var remoteHostTelemetryMessage: String = ""
    @Published var discordTestMessage: String = ""
    @Published var remoteStreamStatus: RemoteStreamStatus = .idle
    @Published var remoteDevices: [RemoteDeviceRecord] = []
    @Published var remoteAuditLines: [String] = []
    @Published var remoteGitHubStatus: RemoteGitHubStatus = .empty
    @Published var remoteArtifacts: [RemoteArtifactRecord] = []
    @Published var artifactImageData: [String: Data] = [:]
    @Published var portfolioAssets: [PortfolioAsset] = []
    @Published var selectedPortfolioAssetID: String?
    @Published var selectedPortfolioStatus: RemotePortfolioStatusResponse?
    @Published var portfolioLogLines: [String] = []
    @Published var portfolioLogSummary: String = ""
    @Published var portfolioCommits: [PortfolioRecentCommit] = []
    @Published var portfolioMessage: String = ""
    @Published var salesLeads: [SalesLead] = []
    @Published var selectedSalesLeadID: String?
    @Published var salesLeadAssets: [RemoteSalesLeadAsset] = []
    @Published var salesLabMessage: String = ""
    @Published var salesHermesHandoffNote: String = ""
    @Published var projectCostSummaries: [RemoteProjectCostSummary] = []
    @Published var costGovernanceMessage: String = ""
    @Published var isLoadingPortfolio = false
    @Published var isLoadingSalesLab = false
    @Published var remoteHistorySessions: [RemoteHistorySession] = []
    @Published var remoteHistoryProjects: [String] = []
    @Published var selectedHistorySession: RemoteHistorySession?
    @Published var remoteHistoryTurns: [RemoteHistoryTurn] = []
    @Published var remoteHistoryTotal: Int = 0
    @Published var remoteHistoryMessage: String = ""
    @Published var isLoadingRemoteHistory = false
    @Published var agentProjects: [AgentProjectSpace] = [] {
        didSet {
            guard isReadyForAutosave, oldValue != agentProjects else { return }
            persist()
        }
    }
    @Published var selectedAgentProjectID: String? {
        didSet {
            guard isReadyForAutosave, oldValue != selectedAgentProjectID else { return }
            persist()
        }
    }
    @Published var selectedAgentChatID: String? {
        didSet {
            guard isReadyForAutosave, oldValue != selectedAgentChatID else { return }
            persist()
        }
    }
    @Published var selectedHermesProvider: String = "auto" {
        didSet {
            guard isReadyForAutosave, oldValue != selectedHermesProvider else { return }
            persist()
        }
    }
    @Published var selectedHermesModel: String = "" {
        didSet {
            guard isReadyForAutosave, oldValue != selectedHermesModel else { return }
            persist()
        }
    }
    @Published var isRefreshingRemoteHost = false
    @Published var pendingAttachments: [CommandAttachment] = []
    @Published var attachmentMessage: String = ""
    @Published var pushNotificationMessage: String = ""
    @Published var requestedSection: AppSection?
    @Published var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: "appLanguage")
            guard isReadyForAutosave, oldValue != appLanguage else { return }
            persist()
            syncPushTokenWithRemoteHost()
        }
    }
    @Published var sessionTitles: [String: String] {
        didSet {
            guard isReadyForAutosave, oldValue != sessionTitles else { return }
            persist()
        }
    }
    @Published var archivedRunIDs: Set<UUID> {
        didSet {
            guard isReadyForAutosave, oldValue != archivedRunIDs else { return }
            persist()
        }
    }
    @Published var savedCommandDrafts: [SavedCommandDraft] = []
    @Published var savedCommandDraftMessage: String = ""
    @Published var workingDirectory: String {
        didSet {
            guard isReadyForAutosave, oldValue != workingDirectory else { return }
            persist()
            scheduleWorkspaceRefresh()
            ensureProjectWithoutChatCreation()
        }
    }

    private let persistenceURL: URL
    private var isReadyForAutosave = false

    var visibleRemoteDevices: [RemoteDeviceRecord] {
        let currentDeviceID = remoteHost.deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentDeviceNames = Self.currentDeviceNameCandidates()
        return remoteDevices.filter { device in
            let deviceID = device.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if !currentDeviceID.isEmpty, deviceID == currentDeviceID {
                return false
            }

            let deviceName = Self.normalizedDeviceName(device.name)
            if !deviceName.isEmpty, currentDeviceNames.contains(deviceName) {
                return false
            }

            return true
        }
    }
    private var workspaceRefreshTask: Task<Void, Never>?
    private var remoteStreamTasks: [UUID: Task<Void, Never>] = [:]
    private var remoteStreamTokens: [UUID: UUID] = [:]
    private var remoteRunIDs: [String: String]
    private var remoteNotificationToken: String?
    private var remoteNotificationEnvironment: String?

    var selectedRun: CommandRun? {
        if let selectedRunID, let run = runs.first(where: { $0.id == selectedRunID }) {
            return run
        }
        return runs.first
    }

    var selectedPortfolioAsset: PortfolioAsset? {
        if let selectedPortfolioAssetID,
           let asset = portfolioAssets.first(where: { $0.id == selectedPortfolioAssetID }) {
            return asset
        }
        return portfolioAssets.first
    }

    var selectedSalesLead: SalesLead? {
        if let selectedSalesLeadID,
           let lead = salesLeads.first(where: { $0.id == selectedSalesLeadID }) {
            return lead
        }
        return salesLeads.first
    }

    var selectedAgentProject: AgentProjectSpace? {
        guard let selectedAgentProjectID else { return agentProjects.first }
        return agentProjects.first { $0.id == selectedAgentProjectID } ?? agentProjects.first
    }

    var selectedAgentChat: AgentChatSpace? {
        guard let project = selectedAgentProject else { return nil }
        guard let selectedAgentChatID else { return project.chats.first }
        return project.chats.first { $0.id == selectedAgentChatID } ?? project.chats.first
    }

    var canSaveCurrentCommandDraft: Bool {
        !commandDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedHermesChoiceTitle: String {
        HermesModelChoice.defaults.first {
            $0.provider == selectedHermesProvider && $0.model == selectedHermesModel
        }?.title ?? [selectedHermesProvider, selectedHermesModel].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var pairingPayload: String {
        [
            "veqral://pair",
            "?host=\(Self.urlEncoded(workspace.hostName))",
            "&endpoint=\(Self.urlEncoded(workspace.macHostEndpoint))",
            "&code=\(Self.urlEncoded(pairingToken))",
            "&workspace=\(Self.urlEncoded(workspace.projectName))"
        ].joined()
    }

    init() {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folderURL = supportURL.appendingPathComponent("Veqral", isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        persistenceURL = folderURL.appendingPathComponent("command-center-state.json")
        if Self.uiTestingResetRequested {
            try? FileManager.default.removeItem(at: persistenceURL)
            SavedCommandDraftCache.clearLocal(cacheFolder: folderURL)
        }
        pairingToken = Self.makePairingToken()
        let defaultWorkingDirectory: String
        defaultWorkingDirectory = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        workingDirectory = defaultWorkingDirectory
        selectedRuntime = LocalCommandExecutor.defaultRuntime()
        remoteHost = .empty
        remoteRunIDs = [:]
        workspace = WorkspaceSnapshot.empty(workingDirectory: defaultWorkingDirectory)
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage").flatMap(AppLanguage.init(rawValue:)) ?? .system
        appLanguage = savedLanguage
        sessionTitles = [:]
        archivedRunIDs = []

        if let snapshot = Self.loadSnapshot(from: persistenceURL) {
            let cleaned = Self.productionCleanedSnapshot(snapshot)
            runs = cleaned.runs
            approvals = Self.sanitizedApprovals(cleaned.approvals)
            logs = cleaned.logs
            diffs = cleaned.diffs
            selectedRunID = cleaned.selectedRunID ?? cleaned.runs.first?.id
            workingDirectory = snapshot.workingDirectory
            selectedRuntime = cleaned.selectedRuntime ?? selectedRuntime
            remoteHost = Self.hydrateRemoteHost(cleaned.remoteHost ?? .empty)
            remoteRunIDs = cleaned.remoteRunIDs ?? [:]
            agentProjects = cleaned.agentProjects ?? []
            selectedAgentProjectID = cleaned.selectedAgentProjectID
            selectedAgentChatID = cleaned.selectedAgentChatID
            selectedHermesProvider = cleaned.selectedHermesProvider ?? "auto"
            selectedHermesModel = cleaned.selectedHermesModel ?? ""
            appLanguage = cleaned.appLanguage ?? savedLanguage
            sessionTitles = cleaned.sessionTitles ?? [:]
            archivedRunIDs = cleaned.archivedRunIDs ?? []
            savedCommandDrafts = Self.mergedSavedCommandDrafts(
                primary: SavedCommandDraftCache.load(cacheFolder: folderURL),
                fallback: cleaned.savedCommandDrafts ?? []
            )
            if cleaned.runs.count != snapshot.runs.count || cleaned.approvals.count != snapshot.approvals.count || cleaned.logs.count != snapshot.logs.count || cleaned.diffs.count != snapshot.diffs.count {
                persist()
            }
        } else {
            let empty = Self.emptySnapshot(defaultWorkingDirectory: defaultWorkingDirectory)
            runs = empty.runs
            approvals = empty.approvals
            logs = empty.logs
            diffs = empty.diffs
            selectedRunID = empty.selectedRunID
            selectedRuntime = empty.selectedRuntime ?? selectedRuntime
            remoteHost = empty.remoteHost ?? .empty
            remoteRunIDs = empty.remoteRunIDs ?? [:]
            agentProjects = empty.agentProjects ?? []
            selectedAgentProjectID = empty.selectedAgentProjectID
            selectedAgentChatID = empty.selectedAgentChatID
            selectedHermesProvider = empty.selectedHermesProvider ?? "auto"
            selectedHermesModel = empty.selectedHermesModel ?? ""
            appLanguage = empty.appLanguage ?? savedLanguage
            sessionTitles = empty.sessionTitles ?? [:]
            archivedRunIDs = empty.archivedRunIDs ?? []
            savedCommandDrafts = SavedCommandDraftCache.load(cacheFolder: folderURL)
            persist()
        }
        applyUITestLaunchOverrides()
        isReadyForAutosave = true
        ensureAgentProjectForCurrentWorkspace()
        scheduleWorkspaceRefresh(delayNanoseconds: 0)
        requestNotificationPermission()
        reconnectRemoteRuns()
        refreshRemoteHostStatus()
    }

    private static var uiTestingResetRequested: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["VEQRAL_UI_TEST_RESET"] == "1"
    }

    private func applyUITestLaunchOverrides() {
        let env = ProcessInfo.processInfo.environment
        guard CommandLine.arguments.contains("-veqral-ui-testing") || env["VEQRAL_UI_TESTING"] == "1" else {
            return
        }

        runs = []
        approvals = []
        logs = []
        diffs = []
        selectedRunID = nil
        remoteRunIDs = [:]
        savedCommandDrafts = []
        if let directory = env["VEQRAL_UI_TEST_WORKING_DIRECTORY"]?.nilIfBlank {
            workingDirectory = NSString(string: directory).expandingTildeInPath
        }
        if let runtimeValue = env["VEQRAL_UI_TEST_RUNTIME"]?.nilIfBlank,
           let runtime = CommandRuntime(rawValue: runtimeValue) {
            selectedRuntime = runtime
        }
        if let projectID = env["VEQRAL_UI_TEST_PROJECT_ID"]?.nilIfBlank {
            let name = env["VEQRAL_UI_TEST_PROJECT_NAME"]?.nilIfBlank ?? "Gate2 XCUITest"
            let chat = AgentChatSpace(
                id: "gate2-xcuitest-chat",
                title: "Gate2 Chat",
                sessionID: nil,
                provider: selectedHermesProvider,
                model: selectedHermesModel,
                createdAt: Date(),
                updatedAt: Date()
            )
            agentProjects = [
                AgentProjectSpace(
                    id: projectID,
                    name: name,
                    workingDirectory: workingDirectory,
                    createdAt: Date(),
                    chats: [chat]
                )
            ]
            selectedAgentProjectID = projectID
            selectedAgentChatID = chat.id
        }
    }

    func selectRun(_ id: UUID) {
        selectedRunID = id
        persist()
    }

    func submitDraft() {
        let trimmed = commandDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        commandDraft = ""
        if selectedRuntime == .hermesAgent {
            submitHermesProjectCommand(trimmed)
            return
        }
        submitCommand(trimmed)
    }

    func saveCurrentCommandDraft() {
        let trimmed = commandDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            savedCommandDraftMessage = L10n.tr("Command draft is empty.")
            return
        }

        let now = Date()
        let key = Self.savedCommandKey(command: trimmed, runtime: selectedRuntime)
        var drafts = savedCommandDrafts.filter {
            Self.savedCommandKey(command: $0.command, runtime: $0.runtime) != key
        }
        let existing = savedCommandDrafts.first {
            Self.savedCommandKey(command: $0.command, runtime: $0.runtime) == key
        }
        drafts.insert(
            SavedCommandDraft(
                id: existing?.id ?? UUID(),
                title: title(for: trimmed),
                command: trimmed,
                runtime: selectedRuntime,
                createdAt: existing?.createdAt ?? now,
                updatedAt: now
            ),
            at: 0
        )
        savedCommandDrafts = Array(drafts.prefix(24))
        savedCommandDraftMessage = existing == nil ? L10n.tr("Saved command draft.") : L10n.tr("Updated saved command draft.")
        persistSavedCommandDrafts()
    }

    func insertSavedCommandDraft(_ draft: SavedCommandDraft) {
        if let runtime = draft.runtime {
            selectedRuntime = runtime
        }
        commandDraft = draft.command
        savedCommandDraftMessage = L10n.tr("Inserted saved command draft.")
    }

    func deleteSavedCommandDraft(_ draft: SavedCommandDraft) {
        savedCommandDrafts.removeAll { $0.id == draft.id }
        savedCommandDraftMessage = L10n.tr("Deleted saved command draft.")
        persistSavedCommandDrafts()
    }

    func submitCommand(
        _ command: String,
        runtime: CommandRuntime? = nil,
        attachments explicitAttachments: [CommandAttachment]? = nil,
        workingDirectory explicitWorkingDirectory: String? = nil,
        resumeSessionID: String? = nil,
        agentProjectID: String? = nil,
        agentChatID: String? = nil,
        provider: String? = nil,
        providerModel: String? = nil
    ) {
        let runtime = runtime ?? selectedRuntime
        let runWorkingDirectory = explicitWorkingDirectory?.nilIfBlank ?? workingDirectory
        let attachments = explicitAttachments ?? pendingAttachments
        if explicitAttachments == nil {
            pendingAttachments = []
            attachmentMessage = ""
        }
        let remoteWillClassifyRisk = remoteHost.isEnabled && remoteHost.isPaired
        let risky = remoteWillClassifyRisk ? nil : (runtime.usesRemoteAgent ? hermesRiskDescription(for: command) : riskDescription(for: command))
        let run = CommandRun(
            id: UUID(),
            title: title(for: command),
            command: command,
            runtime: runtime,
            phase: .implementation,
            status: risky == nil ? .running : .approval,
            agent: agentLabel(for: runtime),
            device: ProcessInfo.processInfo.hostName,
            model: providerModel?.nilIfBlank ?? provider?.nilIfBlank ?? runtime.title,
            progress: risky == nil ? 0.15 : 0.0,
            startedAt: Date(),
            completedAt: nil,
            workingDirectory: runWorkingDirectory,
            resumeSessionID: resumeSessionID,
            agentProjectID: agentProjectID,
            agentChatID: agentChatID,
            provider: provider,
            providerModel: providerModel
        )
        runs.insert(run, at: 0)
        selectedRunID = run.id
        appendLog(runID: run.id, stream: "info", message: "\(runtime.title) request accepted: \(command)")
        if !attachments.isEmpty {
            appendLog(runID: run.id, stream: "attachment", message: "\(attachments.count) image attachment(s) queued.")
        }

        if let risky {
            approvals.insert(
                CommandApproval(
                    id: UUID(),
                    runID: run.id,
                    title: title(for: command),
                    detail: risky.detail,
                    command: command,
                    risk: risky.label,
                    tintName: risky.tintName,
                    status: .pending,
                    createdAt: Date()
                ),
                at: 0
            )
            appendLog(runID: run.id, stream: "approval", message: "Approval required: \(risky.detail)")
            persist()
            return
        }

        persist()
        executeIfAvailable(run, attachments: attachments)
    }

    func addImageAttachment(data: Data, fileExtension: String = "jpg", mimeType: String = "image/jpeg") {
        let safeExtension = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ".")).isEmpty ? "jpg" : fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let attachment = CommandAttachment(
            id: UUID(),
            fileName: "veqral-\(Self.attachmentTimestamp()).\(safeExtension.lowercased())",
            mimeType: mimeType,
            data: data,
            createdAt: Date()
        )
        pendingAttachments.append(attachment)
        attachmentMessage = "\(pendingAttachments.count) attachment(s) ready for the next run."
    }

    func removeAttachment(_ attachment: CommandAttachment) {
        pendingAttachments.removeAll { $0.id == attachment.id }
        attachmentMessage = pendingAttachments.isEmpty ? "" : "\(pendingAttachments.count) attachment(s) ready for the next run."
    }

    func clearAttachments() {
        pendingAttachments = []
        attachmentMessage = ""
    }

    func refreshWorkspace() {
        scheduleWorkspaceRefresh(delayNanoseconds: 0)
    }

    func rotatePairingToken() {
        pairingToken = Self.makePairingToken()
    }

    func configureRemoteHost(endpoint: String, deviceID: String, token: String, name: String = "Mac Host") {
        let cleanDeviceID = deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanDeviceID.isEmpty, !cleanToken.isEmpty {
            try? AppKeychainStore.set(cleanToken, account: Self.remoteTokenAccount(deviceID: cleanDeviceID))
        }
        remoteHost = RemoteHostConfiguration(
            isEnabled: true,
            endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            deviceID: cleanDeviceID,
            token: cleanToken,
            name: name
        )
        persist()
        syncPushTokenWithRemoteHost()
    }

    func pairRemoteHost(endpoint: String, pairingCode: String, pairingSignature: String? = nil, deviceName: String) async throws {
        let cleanEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCode = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSignature = pairingSignature?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        let response = try await RemoteHostClient.pair(
            endpoint: cleanEndpoint,
            deviceName: deviceName,
            pairingCode: cleanCode,
            pairingSignature: cleanSignature
        )
        configureRemoteHost(endpoint: cleanEndpoint, deviceID: response.deviceID, token: response.token, name: "Mac Host")
        refreshRemoteHostTelemetry()
        refreshRemoteHostStatus()
    }

    func disableRemoteHost() {
        remoteHost.isEnabled = false
        remoteHostHealth = nil
        persist()
    }

    func handleAppURL(_ url: URL) {
        guard url.scheme == "veqral" else {
            return
        }
        if url.host == "pair" {
            handlePairingURL(url)
            return
        }
        handleNotificationDeepLink(url: url)
    }

    func handlePairingURL(_ url: URL) {
        guard url.scheme == "veqral",
              url.host == "pair",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }
        var values: [String: String] = [:]
        components.queryItems?.forEach { item in
            if let value = item.value {
                values[item.name] = value
            }
        }
        guard let endpoint = values["endpoint"], let code = values["code"] else {
            remoteHostMessage = "Pairing URL is missing endpoint or code."
            return
        }
        let signature = values["signature"] ?? values["sig"]
        remoteHostMessage = "Pairing from QR link..."
        Task { @MainActor in
            do {
                try await pairRemoteHost(endpoint: endpoint, pairingCode: code, pairingSignature: signature, deviceName: ProcessInfo.processInfo.hostName)
                remoteHostMessage = "Paired from QR link."
            } catch {
                remoteHostMessage = "QR pairing failed: \(error.localizedDescription)"
            }
        }
    }

    func receiveRemoteNotificationToken(_ token: String, environment: String) {
        guard VeqralFeatureFlags.pushNotificationsEnabled else {
            pushNotificationMessage = VeqralFeatureFlags.pushUnavailableMessage
            return
        }
        remoteNotificationToken = token
        remoteNotificationEnvironment = environment
        pushNotificationMessage = L10n.tr("Push token ready.")
        syncPushTokenWithRemoteHost()
    }

    func syncPushTokenWithRemoteHost() {
        guard VeqralFeatureFlags.pushNotificationsEnabled else {
            pushNotificationMessage = VeqralFeatureFlags.pushUnavailableMessage
            return
        }
        guard remoteHost.isEnabled,
              remoteHost.isPaired,
              let token = remoteNotificationToken?.nilIfBlank else {
            return
        }
        let environment = remoteNotificationEnvironment ?? "development"
        let configuration = remoteHost
        let localeID = appLanguage.locale.identifier
        Task { @MainActor in
            do {
                _ = try await RemoteHostClient(configuration: configuration).registerPushToken(
                    deviceToken: token,
                    environment: environment,
                    bundleID: Bundle.main.bundleIdentifier ?? "dev.hiroyuki.veqral",
                    locale: localeID
                )
                pushNotificationMessage = L10n.tr("Push notifications connected.")
            } catch {
                pushNotificationMessage = Self.remoteFailureMessage(error, context: "Push notifications")
            }
        }
    }

    func handlePushNotificationResponse(actionIdentifier: String, userInfo: [String: String]) async {
        let remoteRunID = userInfo["veqral_run_id"]
        let event = userInfo["veqral_event"]
        let severity = userInfo["veqral_severity"]

        if actionIdentifier == VeqralPushAction.approve || actionIdentifier == VeqralPushAction.reject {
            guard severity != "high", let remoteRunID else {
                focusPushTarget(remoteRunID: remoteRunID, event: event)
                return
            }
            await handleLowRiskPushAction(actionIdentifier: actionIdentifier, remoteRunID: remoteRunID)
            return
        }

        focusPushTarget(remoteRunID: remoteRunID, event: event)
    }

    private func handleNotificationDeepLink(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let values = Dictionary(uniqueKeysWithValues: components.queryItems?.compactMap { item in
            item.value.map { (item.name, $0) }
        } ?? [])
        focusPushTarget(remoteRunID: values["remoteRunID"] ?? values["runID"], event: url.host)
    }

    private func handleLowRiskPushAction(actionIdentifier: String, remoteRunID: String) async {
        guard remoteHost.isEnabled, remoteHost.isPaired else { return }
        do {
            let client = RemoteHostClient(configuration: remoteHost)
            if actionIdentifier == VeqralPushAction.approve {
                try await client.approve(remoteRunID: remoteRunID)
                pushNotificationMessage = L10n.tr("Approved from notification.")
            } else {
                try await client.reject(remoteRunID: remoteRunID)
                pushNotificationMessage = L10n.tr("Rejected from notification.")
            }
            updateLocalApprovalAfterPush(actionIdentifier: actionIdentifier, remoteRunID: remoteRunID)
            refreshRemoteHostStatus()
        } catch {
            pushNotificationMessage = Self.remoteFailureMessage(error, context: "Notification action")
            focusPushTarget(remoteRunID: remoteRunID, event: "approval")
        }
    }

    private func updateLocalApprovalAfterPush(actionIdentifier: String, remoteRunID: String) {
        guard let localID = localRunID(forRemoteRunID: remoteRunID) else { return }
        if let approvalIndex = approvals.firstIndex(where: { $0.runID == localID && $0.status == .pending }) {
            approvals[approvalIndex].status = actionIdentifier == VeqralPushAction.approve ? .approved : .rejected
        }
        if let runIndex = runs.firstIndex(where: { $0.id == localID }) {
            runs[runIndex].status = actionIdentifier == VeqralPushAction.approve ? .running : .failed
            runs[runIndex].progress = actionIdentifier == VeqralPushAction.approve ? 0.2 : 1
            if actionIdentifier == VeqralPushAction.reject {
                runs[runIndex].completedAt = Date()
            }
            let run = runs[runIndex]
            if actionIdentifier == VeqralPushAction.approve {
                startRemoteStream(localRun: run, remoteRunID: remoteRunID)
            }
        }
        persist()
    }

    private func focusPushTarget(remoteRunID: String?, event: String?) {
        if let remoteRunID, let localID = localRunID(forRemoteRunID: remoteRunID) {
            selectedRunID = localID
        } else if remoteHost.isPaired {
            refreshRemoteHostStatus()
        }
        requestedSection = event == "approval" ? .approvals : .home
    }

    private func localRunID(forRemoteRunID remoteRunID: String) -> UUID? {
        remoteRunIDs.first { $0.value == remoteRunID }.flatMap { UUID(uuidString: $0.key) }
    }

    func refreshRemoteHostStatus() {
        guard remoteHost.isEnabled, remoteHost.isPaired else { return }
        isRefreshingRemoteHost = true
        remoteHostMessage = "Refreshing Mac Host..."
        let configuration = remoteHost
        let directory = workingDirectory
        Task { @MainActor in
            let client = RemoteHostClient(configuration: configuration)
            do {
                async let health = client.health()
                async let runList = client.runList()
                async let devices = client.devices()
                async let audit = client.audit()
                async let github = client.githubStatus(workingDirectory: directory)
                async let budgets = client.costBudgets()
                async let auth = client.authOnboardingStatus()
                let healthResponse = try await health
                let runListResponse = try await runList
                let deviceResponse = try await devices
                let auditResponse = try await audit
                let githubResponse = try await github
                let budgetResponse = try? await budgets
                let authResponse = try? await auth
                remoteHostHealth = healthResponse
                authOnboardingStatus = authResponse
                authOnboardingMessage = authResponse?.message ?? ""
                remoteHostTelemetry = healthResponse.telemetry
                remoteHostTelemetryMessage = healthResponse.telemetry == nil ? "Host health にテレメトリが含まれていません。手動更新で再取得してください。" : "Host health からテレメトリを取得しました。"
                await mergeRemoteRuns(runListResponse.runs, client: client)
                remoteDevices = deviceResponse.devices
                remoteAuditLines = auditResponse.lines
                remoteGitHubStatus = githubResponse
                projectCostSummaries = budgetResponse?.summaries ?? localCostSummaries()
                remoteHostMessage = "Mac Host online."
            } catch {
                remoteHostHealth = nil
                if remoteHostTelemetry == nil {
                    remoteHostTelemetryMessage = Self.remoteFailureMessage(error, context: "Mac Host telemetry")
                }
                remoteHostMessage = Self.remoteFailureMessage(error, context: "Mac Host")
            }
            isRefreshingRemoteHost = false
        }
    }

    func refreshAuthOnboarding(persistReadyMarkers: Bool = false) {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            authOnboardingMessage = L10n.tr("Mac Host pairing is required.")
            return
        }
        let configuration = remoteHost
        authOnboardingMessage = persistReadyMarkers ? "ログイン状態を確認しています..." : "認証状態を更新しています..."
        Task { @MainActor in
            do {
                let client = RemoteHostClient(configuration: configuration)
                authOnboardingStatus = persistReadyMarkers
                    ? try await client.refreshAuthOnboarding()
                    : try await client.authOnboardingStatus()
                authOnboardingMessage = authOnboardingStatus?.message ?? "認証状態を更新しました。"
            } catch {
                authOnboardingMessage = Self.remoteFailureMessage(error, context: "Auth onboarding")
            }
        }
    }

    func refreshRemoteHostTelemetry() {
        guard remoteHost.isEnabled, remoteHost.isPaired else { return }
        let configuration = remoteHost
        Task { @MainActor in
            do {
                remoteHostTelemetry = try await RemoteHostClient(configuration: configuration).telemetry()
                remoteHostTelemetryMessage = "ホスト状態を更新しました。"
            } catch {
                remoteHostTelemetryMessage = Self.remoteFailureMessage(error, context: "Mac Host telemetry")
                if remoteHostTelemetry == nil {
                    remoteHostMessage = Self.remoteFailureMessage(error, context: "Mac Host telemetry")
                }
            }
        }
    }

    func sendDiscordTestNotification() {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            discordTestMessage = "Mac Host とペアリングすると Discord テスト通知を送れます。"
            return
        }
        discordTestMessage = "Discord テスト通知を送信中..."
        let configuration = remoteHost
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).testDiscordNotification()
                discordTestMessage = response.ok ? "Discord テスト通知を送信しました。届いたか Discord 側で確認してください。" : response.message
            } catch {
                discordTestMessage = Self.remoteFailureMessage(error, context: "Discord test")
            }
        }
    }

    func refreshCostGovernance() {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            projectCostSummaries = localCostSummaries()
            costGovernanceMessage = "Mac Host 未接続のため、この端末にある Run から概算しています。"
            return
        }
        let configuration = remoteHost
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).costBudgets()
                projectCostSummaries = response.summaries
                costGovernanceMessage = "コスト集計を更新しました。"
            } catch {
                costGovernanceMessage = Self.remoteFailureMessage(error, context: "Cost governance")
            }
        }
    }

    func saveCostBudget(summary: RemoteProjectCostSummary, limitUSD: Double?, paused: Bool? = nil) {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            costGovernanceMessage = "予算設定には Mac Host ペアリングが必要です。"
            return
        }
        let configuration = remoteHost
        let request = RemoteProjectBudgetUpdateRequest(
            projectKey: summary.projectKey,
            projectID: summary.projectID,
            workingDirectory: summary.workingDirectory,
            displayName: summary.displayName,
            limitUSD: limitUSD,
            thresholdPercent: summary.thresholdPercent,
            paused: paused
        )
        Task { @MainActor in
            do {
                let updated = try await RemoteHostClient(configuration: configuration).updateCostBudget(request)
                upsertCostSummary(updated)
                costGovernanceMessage = "予算を保存しました。"
            } catch {
                costGovernanceMessage = Self.remoteFailureMessage(error, context: "Cost budget")
            }
        }
    }

    func costSummary(for run: CommandRun) -> RemoteProjectCostSummary {
        let key = Self.costProjectKey(projectID: run.agentProjectID, workingDirectory: run.workingDirectory)
        if let remote = projectCostSummaries.first(where: { $0.projectKey == key }) {
            return remote
        }
        return localCostSummary(projectKey: key, projectID: run.agentProjectID, workingDirectory: run.workingDirectory)
    }

    func costSummary(for asset: PortfolioAsset) -> RemoteProjectCostSummary? {
        let workingDirectory = asset.sourceRefs.localPaths.first?.path
        let key: String
        if let projectID = asset.linkedProjectId?.nilIfBlank {
            key = Self.costProjectKey(projectID: projectID, workingDirectory: workingDirectory ?? "")
        } else if let workingDirectory {
            key = Self.costProjectKey(projectID: nil, workingDirectory: workingDirectory)
        } else {
            return nil
        }
        return projectCostSummaries.first(where: { $0.projectKey == key })
            ?? localCostSummary(projectKey: key, projectID: asset.linkedProjectId, workingDirectory: workingDirectory ?? "")
    }

    func refreshGitHubStatus() {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            remoteHostMessage = "GitHub status requires Mac Host pairing."
            return
        }
        let configuration = remoteHost
        let directory = workingDirectory
        remoteHostMessage = "Refreshing GitHub status..."
        Task { @MainActor in
            do {
                remoteGitHubStatus = try await RemoteHostClient(configuration: configuration).githubStatus(workingDirectory: directory)
                remoteHostMessage = "GitHub status refreshed."
            } catch {
                remoteHostMessage = Self.remoteFailureMessage(error, context: "GitHub status")
            }
        }
    }

    func createDraftPRFromHost() {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            remoteHostMessage = "Draft PR requires Mac Host pairing."
            return
        }
        let configuration = remoteHost
        let title = selectedRun?.title ?? "Veqral update"
        let body = "Created from Veqral Mac Host."
        remoteHostMessage = "Creating draft PR..."
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).createDraftPR(
                    workingDirectory: workingDirectory,
                    title: title,
                    body: body
                )
                remoteHostMessage = "Draft PR created: \(response.url)"
                refreshGitHubStatus()
            } catch {
                remoteHostMessage = Self.remoteFailureMessage(error, context: "Draft PR")
            }
        }
    }

    func refreshPortfolio() {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            portfolioMessage = L10n.tr("Mac Host pairing is required.")
            return
        }
        let configuration = remoteHost
        isLoadingPortfolio = true
        portfolioMessage = L10n.tr("Loading portfolio...")
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).portfolioAssets()
                portfolioAssets = response.assets
                selectedPortfolioAssetID = selectedPortfolioAssetID ?? response.assets.first?.id
                portfolioMessage = response.assets.isEmpty ? L10n.tr("No assets registered yet.") : "\(response.assets.count) \(L10n.tr("assets loaded"))"
                if selectedPortfolioAssetID != nil {
                    refreshSelectedPortfolioDetail()
                }
            } catch {
                portfolioMessage = Self.remoteFailureMessage(error, context: "Portfolio")
            }
            isLoadingPortfolio = false
        }
    }

    func discoverPortfolio() {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            portfolioMessage = L10n.tr("Mac Host pairing is required.")
            return
        }
        let configuration = remoteHost
        isLoadingPortfolio = true
        portfolioMessage = L10n.tr("Discovering assets...")
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).discoverPortfolio()
                portfolioAssets = response.assets
                selectedPortfolioAssetID = selectedPortfolioAssetID ?? response.assets.first?.id
                portfolioMessage = "\(response.assets.count) \(L10n.tr("assets loaded"))"
            } catch {
                portfolioMessage = Self.remoteFailureMessage(error, context: "Portfolio discover")
            }
            isLoadingPortfolio = false
        }
    }

    func savePortfolioAsset(_ asset: PortfolioAsset) {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            portfolioMessage = L10n.tr("Mac Host pairing is required.")
            return
        }
        let configuration = remoteHost
        portfolioMessage = L10n.tr("Saving asset...")
        Task { @MainActor in
            do {
                let saved = try await RemoteHostClient(configuration: configuration).savePortfolioAsset(asset)
                if let index = portfolioAssets.firstIndex(where: { $0.id == saved.id }) {
                    portfolioAssets[index] = saved
                } else {
                    portfolioAssets.insert(saved, at: 0)
                }
                selectedPortfolioAssetID = saved.id
                portfolioMessage = L10n.tr("Asset saved.")
            } catch {
                portfolioMessage = Self.remoteFailureMessage(error, context: "Portfolio save")
            }
        }
    }

    func selectPortfolioAsset(_ asset: PortfolioAsset) {
        selectedPortfolioAssetID = asset.id
        refreshSelectedPortfolioDetail()
    }

    func refreshSelectedPortfolioDetail() {
        guard remoteHost.isEnabled, remoteHost.isPaired, let asset = selectedPortfolioAsset else { return }
        let configuration = remoteHost
        Task { @MainActor in
            do {
                async let status = RemoteHostClient(configuration: configuration).portfolioStatus(assetID: asset.id)
                async let logs = RemoteHostClient(configuration: configuration).portfolioLogs(assetID: asset.id)
                async let commits = RemoteHostClient(configuration: configuration).portfolioCommits(assetID: asset.id)
                let statusResponse = try await status
                let logsResponse = try await logs
                let commitsResponse = try await commits
                selectedPortfolioStatus = statusResponse
                portfolioLogLines = logsResponse.lines
                portfolioCommits = commitsResponse.commits
            } catch {
                portfolioMessage = Self.remoteFailureMessage(error, context: "Portfolio detail")
            }
        }
    }

    func summarizePortfolioLogs() {
        guard remoteHost.isEnabled, remoteHost.isPaired, let asset = selectedPortfolioAsset else { return }
        let configuration = remoteHost
        portfolioMessage = L10n.tr("Summarizing logs...")
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).portfolioLogSummary(assetID: asset.id)
                portfolioLogSummary = response.summary
                portfolioMessage = L10n.tr("Summary updated.")
            } catch {
                portfolioMessage = Self.remoteFailureMessage(error, context: "Log summary")
            }
        }
    }

    func runPortfolioControl(_ action: String) {
        guard remoteHost.isEnabled, remoteHost.isPaired, let asset = selectedPortfolioAsset else { return }
        let configuration = remoteHost
        portfolioMessage = L10n.tr("Queued for approval.")
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).portfolioControl(assetID: asset.id, action: action)
                portfolioMessage = "\(L10n.tr("Approval required")): \(response.runID.prefix(8))"
                refreshRemoteHostStatus()
            } catch {
                portfolioMessage = Self.remoteFailureMessage(error, context: "Portfolio control")
            }
        }
    }

    func promotePortfolioAsset() {
        guard remoteHost.isEnabled, remoteHost.isPaired, let asset = selectedPortfolioAsset else { return }
        let configuration = remoteHost
        portfolioMessage = L10n.tr("Queued for approval.")
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).portfolioPromote(assetID: asset.id)
                portfolioMessage = "\(L10n.tr("Approval required")): \(response.runID.prefix(8))"
                refreshRemoteHostStatus()
            } catch {
                portfolioMessage = Self.remoteFailureMessage(error, context: "Promote")
            }
        }
    }

    func linkSelectedPortfolioAssetToProject() {
        guard var asset = selectedPortfolioAsset else { return }
        ensureAgentProjectForCurrentWorkspace()
        asset.linkedProjectId = selectedAgentProject?.id
        savePortfolioAsset(asset)
        requestedSection = .projects
    }

    func refreshSalesLeads() {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            salesLabMessage = "Mac Host とペアリングすると営業ラボを読み込めます。"
            return
        }
        let configuration = remoteHost
        isLoadingSalesLab = true
        salesLabMessage = "営業案件を読み込み中..."
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).salesLeads()
                salesLeads = response.leads
                selectedSalesLeadID = selectedSalesLeadID ?? response.leads.first?.id
                salesLabMessage = response.leads.isEmpty ? "案件はまだありません。" : "\(response.leads.count)件の案件を読み込みました。"
                refreshSalesLeadAssets()
            } catch {
                salesLabMessage = Self.remoteFailureMessage(error, context: "Sales Lab")
            }
            isLoadingSalesLab = false
        }
    }

    func saveSalesLead(_ lead: SalesLead) {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            salesLabMessage = "Mac Host とペアリングしてください。"
            return
        }
        let configuration = remoteHost
        salesLabMessage = "案件を保存中..."
        Task { @MainActor in
            do {
                let saved = try await RemoteHostClient(configuration: configuration).saveSalesLead(lead)
                upsertSalesLeadLocally(saved)
                selectedSalesLeadID = saved.id
                salesLabMessage = "案件を保存しました。"
                refreshSalesLeadAssets()
            } catch {
                salesLabMessage = Self.remoteFailureMessage(error, context: "Sales lead save")
            }
        }
    }

    func importSalesCSV(_ csv: String) {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            salesLabMessage = "Mac Host とペアリングしてください。"
            return
        }
        let configuration = remoteHost
        isLoadingSalesLab = true
        salesLabMessage = "CSVを取り込み中..."
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).importSalesCSV(csv)
                refreshSalesLeads()
                salesLabMessage = "\(response.imported)件を取り込みました。スキップ \(response.skipped)件。"
            } catch {
                salesLabMessage = Self.remoteFailureMessage(error, context: "Sales CSV")
            }
            isLoadingSalesLab = false
        }
    }

    func selectSalesLead(_ lead: SalesLead) {
        selectedSalesLeadID = lead.id
        salesHermesHandoffNote = ""
        refreshSalesLeadAssets()
    }

    func auditSelectedSalesLead() {
        guard let lead = selectedSalesLead else { return }
        performSalesAction(message: "公式サイトを監査中...") { client in
            let audit = try await client.auditSalesLead(id: lead.id)
            var updated = lead
            updated.latestAudit = audit
            updated.status = updated.status == .new ? .auditReady : updated.status
            return updated
        }
    }

    func generateSelectedSalesRedesign() {
        guard let lead = selectedSalesLead else { return }
        performSalesAction(message: "スマホ改善案を生成中...") { client in
            let mock = try await client.generateSalesRedesign(id: lead.id)
            var updated = lead
            updated.latestRedesignMock = mock
            return updated
        }
    }

    func generateSelectedSalesProposal() {
        guard let lead = selectedSalesLead else { return }
        performSalesAction(message: "提案書を生成中...") { client in
            let proposal = try await client.generateSalesProposal(id: lead.id)
            var updated = lead
            updated.latestProposal = proposal
            updated.status = .proposalReady
            return updated
        }
    }

    func approveSelectedSalesProposal() {
        guard let lead = selectedSalesLead else { return }
        performSalesAction(message: "提案書を承認中...") { client in
            let proposal = try await client.approveSalesProposal(id: lead.id)
            var updated = lead
            updated.latestProposal = proposal
            return updated
        }
    }

    func markSelectedSalesLeadContacted(channel: String, note: String?) {
        guard let lead = selectedSalesLead else { return }
        performSalesAction(message: "連絡済みに更新中...") { client in
            try await client.markSalesLeadContacted(id: lead.id, channel: channel, note: note)
        }
    }

    func updateSelectedSalesLeadStatus(_ status: SalesLeadStatus) {
        guard var lead = selectedSalesLead else { return }
        lead.status = status
        saveSalesLead(lead)
    }

    func promoteSelectedSalesLeadToPortfolio() {
        guard let lead = selectedSalesLead else { return }
        performSalesAction(message: "Portfolioへ昇格中...") { [self] client in
            let response = try await client.promoteSalesLeadToPortfolio(id: lead.id)
            self.portfolioAssets.insert(response.asset, at: 0)
            return response.lead
        }
    }

    func createSelectedSalesHermesHandoff() {
        guard let lead = selectedSalesLead else { return }
        performSalesAction(message: "Hermes Desktop向けメモを作成中...") { [self] client in
            let response = try await client.createSalesHermesHandoff(id: lead.id)
            self.salesHermesHandoffNote = response.note
            return response.lead
        }
    }

    func refreshSalesLeadAssets() {
        guard remoteHost.isEnabled, remoteHost.isPaired, let lead = selectedSalesLead else { return }
        let configuration = remoteHost
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).salesLeadAssets(id: lead.id)
                salesLeadAssets = response.assets
            } catch {
                salesLabMessage = Self.remoteFailureMessage(error, context: "Sales assets")
            }
        }
    }

    private func performSalesAction(message: String, action: @escaping (RemoteHostClient) async throws -> SalesLead) {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            salesLabMessage = "Mac Host とペアリングしてください。"
            return
        }
        let configuration = remoteHost
        isLoadingSalesLab = true
        salesLabMessage = message
        Task { @MainActor in
            do {
                let updated = try await action(RemoteHostClient(configuration: configuration))
                upsertSalesLeadLocally(updated)
                selectedSalesLeadID = updated.id
                salesLabMessage = "更新しました。"
                refreshSalesLeadAssets()
            } catch {
                salesLabMessage = Self.remoteFailureMessage(error, context: "Sales Lab")
            }
            isLoadingSalesLab = false
        }
    }

    private func upsertSalesLeadLocally(_ lead: SalesLead) {
        if let index = salesLeads.firstIndex(where: { $0.id == lead.id }) {
            salesLeads[index] = lead
        } else {
            salesLeads.insert(lead, at: 0)
        }
        salesLeads.sort { $0.updatedAt > $1.updatedAt }
    }

    func revokeRemoteDevice(_ device: RemoteDeviceRecord) {
        guard remoteHost.isEnabled, remoteHost.isPaired else { return }
        let configuration = remoteHost
        Task { @MainActor in
            do {
                try await RemoteHostClient(configuration: configuration).revokeDevice(deviceID: device.id)
                remoteDevices.removeAll { $0.id == device.id }
                remoteHostMessage = "Revoked \(device.name)."
                if device.id == configuration.deviceID {
                    disableRemoteHost()
                }
            } catch {
                remoteHostMessage = "Revoke failed: \(error.localizedDescription)"
            }
        }
    }

    func refreshRemoteMemory() {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            remoteMemoryMessage = "Mac HostとペアリングするとHermesメモリを読み込めます。"
            return
        }
        isLoadingRemoteMemory = true
        remoteMemoryMessage = "Loading Hermes memory files..."
        let configuration = remoteHost
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).memoryList()
                remoteMemoryFiles = response.files
                if selectedRemoteMemoryID == nil || !response.files.contains(where: { $0.id == selectedRemoteMemoryID ?? "" }) {
                    selectedRemoteMemoryID = response.files.first?.id
                }
                remoteMemoryMessage = "\(response.files.count) files loaded from Mac Host."
                isLoadingRemoteMemory = false
                if let selectedRemoteMemoryID {
                    loadRemoteMemory(id: selectedRemoteMemoryID)
                }
            } catch {
                isLoadingRemoteMemory = false
                remoteMemoryMessage = "Memory load failed: \(error.localizedDescription)"
            }
        }
    }

    func refreshRemoteProjectMemory() {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            remoteProjectMemoryMessage = "Mac Host とペアリングするとプロジェクト記憶を読み込めます。"
            return
        }
        ensureProjectWithoutChatCreation()
        guard let project = selectedAgentProject else {
            remoteProjectMemoryMessage = "Hermes Project がまだありません。"
            return
        }
        isLoadingRemoteProjectMemory = true
        remoteProjectMemoryMessage = "プロジェクト記憶を読み込み中..."
        let configuration = remoteHost
        let request = RemoteProjectMemoryRequest(projectID: project.id, projectName: project.name)
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).projectMemory(request)
                remoteProjectMemory = response
                remoteProjectMemoryLastFetchedAt = Date()
                let memoryState = response.memoryContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "記憶ファイルは空です" : "記憶ファイルを読み込みました"
                remoteProjectMemoryMessage = "\(memoryState)。\(response.sessions.count) 件の Hermes セッション。"
            } catch {
                remoteProjectMemoryMessage = "プロジェクト記憶の読み込みに失敗しました: \(error.localizedDescription)"
            }
            isLoadingRemoteProjectMemory = false
        }
    }

    func selectRemoteMemory(_ file: RemoteMemoryFile) {
        selectedRemoteMemoryID = file.id
        remoteMemoryDiff = ""
        loadRemoteMemory(id: file.id)
    }

    func loadRemoteMemory(id: String) {
        guard remoteHost.isEnabled, remoteHost.isPaired else { return }
        isLoadingRemoteMemory = true
        remoteMemoryMessage = "Loading \(id)..."
        let configuration = remoteHost
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).readMemory(id: id)
                selectedRemoteMemoryID = response.file.id
                remoteMemoryContent = response.content
                remoteMemoryDiff = ""
                remoteMemoryMessage = "Loaded \(response.file.relativePath)."
            } catch {
                remoteMemoryMessage = "Memory read failed: \(error.localizedDescription)"
            }
            isLoadingRemoteMemory = false
        }
    }

    func previewRemoteMemoryDiff() {
        guard let selectedRemoteMemoryID, remoteHost.isEnabled, remoteHost.isPaired else { return }
        isLoadingRemoteMemory = true
        remoteMemoryMessage = "Generating diff..."
        let configuration = remoteHost
        let content = remoteMemoryContent
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).diffMemory(id: selectedRemoteMemoryID, content: content)
                remoteMemoryDiff = response.diff.isEmpty ? "No changes." : response.diff
                remoteMemoryMessage = response.hasChanges ? "Review diff, then save." : "No changes to save."
            } catch {
                remoteMemoryMessage = "Diff failed: \(error.localizedDescription)"
            }
            isLoadingRemoteMemory = false
        }
    }

    func saveRemoteMemory() {
        guard let selectedRemoteMemoryID, remoteHost.isEnabled, remoteHost.isPaired else { return }
        isLoadingRemoteMemory = true
        remoteMemoryMessage = "Saving memory file..."
        let configuration = remoteHost
        let content = remoteMemoryContent
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).writeMemory(id: selectedRemoteMemoryID, content: content)
                remoteMemoryDiff = response.diff.isEmpty ? "No changes." : response.diff
                remoteMemoryMessage = response.hasChanges ? "Saved \(response.file.relativePath)." : "No changes. File left as-is."
                refreshRemoteMemory()
            } catch {
                remoteMemoryMessage = "Save failed: \(error.localizedDescription)"
                isLoadingRemoteMemory = false
            }
        }
    }

    func refreshRemoteHistory(
        tool: RemoteHistoryTool? = nil,
        project: String? = nil,
        query: String? = nil,
        date: String? = nil,
        page: Int = 0
    ) {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            remoteHistoryMessage = "Mac Host pairing is required to load Claude/Codex history."
            return
        }
        isLoadingRemoteHistory = true
        remoteHistoryMessage = "Loading agent history..."
        let configuration = remoteHost
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).historySessions(
                    tool: tool,
                    project: project,
                    query: query,
                    date: date,
                    page: page,
                    limit: 50
                )
                remoteHistorySessions = response.sessions
                remoteHistoryProjects = response.projects
                remoteHistoryTotal = response.total
                let previousSelection = selectedHistorySession
                var sessionToLoad: RemoteHistorySession?
                if let selectedHistorySession, !response.sessions.contains(where: { $0.id == selectedHistorySession.id }) {
                    self.selectedHistorySession = response.sessions.first
                    remoteHistoryTurns = []
                    sessionToLoad = response.sessions.first
                } else if selectedHistorySession == nil {
                    selectedHistorySession = response.sessions.first
                    sessionToLoad = response.sessions.first
                } else if remoteHistoryTurns.isEmpty,
                          let selectedHistorySession,
                          response.sessions.contains(where: { $0.id == selectedHistorySession.id }),
                          previousSelection?.id == selectedHistorySession.id {
                    sessionToLoad = selectedHistorySession
                }
                let warningText = (response.warnings ?? []).joined(separator: "\n")
                let loadMessage = response.sessions.isEmpty ? "No Claude/Codex history found on Mac Host." : "\(response.total) sessions loaded."
                remoteHistoryMessage = warningText.isEmpty ? loadMessage : "\(loadMessage)\n\(warningText)"
                isLoadingRemoteHistory = false
                if let sessionToLoad {
                    loadRemoteHistoryDetail(sessionToLoad)
                }
            } catch {
                remoteHistoryMessage = Self.remoteFailureMessage(error, context: "History")
                isLoadingRemoteHistory = false
            }
        }
    }

    func loadRemoteHistoryDetail(_ session: RemoteHistorySession) {
        guard remoteHost.isEnabled, remoteHost.isPaired else {
            remoteHistoryMessage = "Mac Host pairing is required to load history detail."
            return
        }
        selectedHistorySession = session
        isLoadingRemoteHistory = true
        remoteHistoryMessage = "Loading \(session.tool.title) session..."
        let configuration = remoteHost
        Task { @MainActor in
            do {
                let response = try await RemoteHostClient(configuration: configuration).historyDetail(id: session.id, tool: session.tool)
                selectedHistorySession = response.session
                remoteHistoryTurns = response.turns
                remoteHistoryMessage = response.truncated ? "Session loaded. Some old events were truncated." : "Session loaded."
            } catch {
                remoteHistoryMessage = Self.remoteFailureMessage(error, context: "History detail")
            }
            isLoadingRemoteHistory = false
        }
    }

    func selectRuntime(_ runtime: CommandRuntime) {
        selectedRuntime = runtime
    }

    func selectHermesModel(_ choice: HermesModelChoice) {
        selectedHermesProvider = choice.provider
        selectedHermesModel = choice.model
        if var chat = selectedAgentChat {
            chat.provider = choice.provider
            chat.model = choice.model
            updateAgentChat(chat)
        }
    }

    func ensureAgentProjectForCurrentWorkspace() {
        let directory = workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSHomeDirectory() : workingDirectory
        let expanded = NSString(string: directory).expandingTildeInPath
        let id = Self.stableAgentProjectID(for: expanded)
        if !agentProjects.contains(where: { $0.id == id }) {
            agentProjects.insert(
                AgentProjectSpace(
                    id: id,
                    name: URL(fileURLWithPath: expanded).lastPathComponent.nilIfBlank ?? "Project",
                    workingDirectory: expanded,
                    createdAt: Date(),
                    chats: []
                ),
                at: 0
            )
        }
        selectedAgentProjectID = selectedAgentProjectID ?? id
        if selectedAgentProjectID == id, selectedAgentChatID == nil {
            createHermesChat(title: "Chat \(agentProjectChatCount(projectID: id) + 1)", select: true)
        }
        persist()
    }

    func useCurrentWorkspaceForHermes() {
        let directory = workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSHomeDirectory() : workingDirectory
        let expanded = NSString(string: directory).expandingTildeInPath
        let id = Self.stableAgentProjectID(for: expanded)
        ensureProjectWithoutChatCreation()
        selectedAgentProjectID = id
        if agentProjects.first(where: { $0.id == id })?.chats.isEmpty != false {
            createHermesChat(title: "Chat 1", select: true)
        } else {
            selectedAgentChatID = agentProjects.first(where: { $0.id == id })?.chats.first?.id
        }
        persist()
    }

    func selectAgentProject(_ project: AgentProjectSpace) {
        selectedAgentProjectID = project.id
        selectedAgentChatID = project.chats.first?.id
    }

    func createHermesChat(title: String? = nil, select: Bool = true) {
        ensureProjectWithoutChatCreation()
        guard let projectIndex = agentProjects.firstIndex(where: { $0.id == (selectedAgentProjectID ?? agentProjects.first?.id) }) else { return }
        let count = agentProjects[projectIndex].chats.count + 1
        let chat = AgentChatSpace(
            id: UUID().uuidString,
            title: title?.nilIfBlank ?? "Chat \(count)",
            sessionID: nil,
            provider: selectedHermesProvider,
            model: selectedHermesModel,
            createdAt: Date(),
            updatedAt: Date()
        )
        agentProjects[projectIndex].chats.insert(chat, at: 0)
        if select {
            selectedAgentProjectID = agentProjects[projectIndex].id
            selectedAgentChatID = chat.id
        }
        persist()
    }

    func selectAgentChat(_ chat: AgentChatSpace) {
        selectedAgentChatID = chat.id
        selectedHermesProvider = chat.provider
        selectedHermesModel = chat.model
    }

    func submitHermesProjectCommand(_ command: String? = nil) {
        ensureAgentProjectForCurrentWorkspace()
        guard let project = selectedAgentProject else { return }
        if selectedAgentChat == nil {
            createHermesChat(select: true)
        }
        guard let chat = selectedAgentChat else { return }
        let text = (command ?? commandDraft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if command == nil {
            commandDraft = ""
        }
        submitCommand(
            text,
            runtime: .hermesAgent,
            workingDirectory: project.workingDirectory,
            resumeSessionID: chat.sessionID,
            agentProjectID: project.id,
            agentChatID: chat.id,
            provider: chat.provider,
            providerModel: chat.model
        )
    }

    func askSelectedProjectMemory(_ question: String) {
        let cleanQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuestion.isEmpty else { return }
        guard selectedAgentProject != nil else {
            remoteProjectMemoryMessage = "Hermes Project を選択すると、記憶へ問い合わせできます。"
            return
        }
        createHermesChat(title: "記憶質問 \(Self.shortDateTimeFormatter.string(from: Date()))", select: true)
        let prompt = """
        選択中の Hermes Project の native memory と、この source に紐づく session 履歴だけを根拠に答えてください。
        - Veqral 用の別 memory store は作らない。
        - 根拠が薄い場合は「記憶からは断定できない」と明記する。
        - 事実、関連する作業、次に見るべき点を短く整理する。

        質問:
        \(cleanQuestion)
        """
        submitHermesProjectCommand(prompt)
        remoteProjectMemoryMessage = "記憶への問い合わせを新しい Hermes Chat に送信しました。"
        requestedSection = .home
    }

    func handoffRunContextToHermes(_ run: CommandRun) {
        selectOrCreateAgentProject(workingDirectory: run.workingDirectory, chatTitle: "引き継ぎ \(Self.shortRunID(run))")
        let prompt = hermesHandoffPrompt(for: run)
        submitHermesProjectCommand(prompt)
        requestedSection = .home
    }

    func continueHistorySession(_ session: RemoteHistorySession, command: String? = nil) {
        let text = (command ?? commandDraft).trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = text.isEmpty ? "Continue this session from Veqral. Briefly orient me to the current state and wait for the next instruction." : text
        if command == nil {
            commandDraft = ""
        }
        let runtime: CommandRuntime = session.tool == .codex ? .codexDirect : .claudeDirect
        submitCommand(
            prompt,
            runtime: runtime,
            workingDirectory: session.projectPath.nilIfBlank ?? workingDirectory,
            resumeSessionID: session.resumeID ?? session.id,
            agentProjectID: nil,
            agentChatID: nil,
            provider: nil,
            providerModel: session.model
        )
    }

    @discardableResult
    private func selectOrCreateAgentProject(workingDirectory directory: String, chatTitle: String?) -> AgentProjectSpace? {
        let cleanDirectory = directory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSHomeDirectory() : directory
        let expanded = NSString(string: cleanDirectory).expandingTildeInPath
        let id = Self.stableAgentProjectID(for: expanded)
        if !agentProjects.contains(where: { $0.id == id }) {
            agentProjects.insert(
                AgentProjectSpace(
                    id: id,
                    name: URL(fileURLWithPath: expanded).lastPathComponent.nilIfBlank ?? "Project",
                    workingDirectory: expanded,
                    createdAt: Date(),
                    chats: []
                ),
                at: 0
            )
        }
        selectedAgentProjectID = id
        if let chatTitle {
            createHermesChat(title: chatTitle, select: true)
        } else if let project = selectedAgentProject {
            if let currentChatID = selectedAgentChatID,
               project.chats.contains(where: { $0.id == currentChatID }) {
                return project
            }
            if let firstChat = project.chats.first {
                selectedAgentChatID = firstChat.id
                selectedHermesProvider = firstChat.provider
                selectedHermesModel = firstChat.model
            } else {
                createHermesChat(select: true)
            }
        }
        persist()
        return selectedAgentProject
    }

    private func hermesHandoffPrompt(for run: CommandRun) -> String {
        let logSummary = handoffLogSummary(for: run.id)
        let diffSummary = handoffDiffSummary(for: run.id)
        let usageLine = run.usage.flatMap(Self.handoffUsageLine) ?? "記録なし"
        return """
        以下は Veqral の直接モードまたは Shell 実行から Hermes Project へ引き継ぐ文脈です。
        Hermes native memory / session history の範囲で整理し、同じ Project の別 Chat・別モデル（Claude/Codex など）が続きから作業できるようにしてください。
        Veqral 用の別 memory store や MCP は作らないでください。

        Run:
        - ID: \(Self.shortRunID(run))
        - Runtime: \(run.runtimeOrDefault.title)
        - Status: \(run.status.title)
        - Working directory: \(run.workingDirectory)
        - Model: \(run.model)
        - Usage: \(usageLine)

        元の指令:
        \(Self.redactedHandoffText(run.command, limit: 2_000))

        ログ要約:
        \(logSummary)

        差分要約:
        \(diffSummary)

        次にやってほしいこと:
        1. この実行の目的、現在地、未解決事項を Project 文脈として短く整理する。
        2. 次の Chat/別モデルが続けるための「次の一手」を3つ以内で出す。
        3. 重要な事実だけを Hermes native memory に残す必要がある場合は、Hermes の memory 機能で保存する。
        """
    }

    private func handoffLogSummary(for runID: UUID) -> String {
        let entries = logEntries(for: runID).suffix(24)
        guard !entries.isEmpty else { return "ログなし" }
        let text = entries.map { entry in
            "[\(entry.stream)] \(entry.message)"
        }.joined(separator: "\n")
        return Self.redactedHandoffText(text, limit: 4_000)
    }

    private func handoffDiffSummary(for runID: UUID) -> String {
        let entries = diffEntries(for: runID)
        guard !entries.isEmpty else { return "差分なし" }
        let text = entries.prefix(20).map { entry in
            "- \(entry.path): +\(entry.additions) / -\(entry.deletions)"
        }.joined(separator: "\n")
        return Self.redactedHandoffText(text, limit: 2_000)
    }

    private static func handoffUsageLine(_ usage: CommandRunUsage) -> String? {
        var parts: [String] = []
        if let input = usage.inputTokens {
            parts.append("入力 \(input)")
        }
        if let output = usage.outputTokens {
            parts.append("出力 \(output)")
        }
        if let reasoning = usage.reasoningTokens {
            parts.append("推論 \(reasoning)")
        }
        if let total = usage.totalTokensOrDerived {
            parts.append("合計 \(total)")
        }
        if let cost = usage.costUSD {
            parts.append(String(format: "費用 %.4f USD", cost))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " / ")
    }

    private static func shortRunID(_ run: CommandRun) -> String {
        String(run.id.uuidString.prefix(8)).lowercased()
    }

    private static func redactedHandoffText(_ text: String, limit: Int) -> String {
        VeqralRedactor.redact(text, limit: limit)
    }

    private static let shortDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()

    private func updateAgentChat(_ chat: AgentChatSpace) {
        guard let projectIndex = agentProjects.firstIndex(where: { project in
            project.chats.contains(where: { $0.id == chat.id })
        }),
        let chatIndex = agentProjects[projectIndex].chats.firstIndex(where: { $0.id == chat.id }) else {
            return
        }
        var updated = chat
        updated.updatedAt = Date()
        agentProjects[projectIndex].chats[chatIndex] = updated
        persist()
    }

    private func updateAgentChatSession(chatID: String, sessionID: String) {
        guard let projectIndex = agentProjects.firstIndex(where: { project in
            project.chats.contains(where: { $0.id == chatID })
        }),
        let chatIndex = agentProjects[projectIndex].chats.firstIndex(where: { $0.id == chatID }) else {
            return
        }
        agentProjects[projectIndex].chats[chatIndex].sessionID = sessionID
        agentProjects[projectIndex].chats[chatIndex].updatedAt = Date()
        persist()
    }

    private func ensureProjectWithoutChatCreation() {
        let directory = workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSHomeDirectory() : workingDirectory
        let expanded = NSString(string: directory).expandingTildeInPath
        let id = Self.stableAgentProjectID(for: expanded)
        if !agentProjects.contains(where: { $0.id == id }) {
            agentProjects.insert(
                AgentProjectSpace(
                    id: id,
                    name: URL(fileURLWithPath: expanded).lastPathComponent.nilIfBlank ?? "Project",
                    workingDirectory: expanded,
                    createdAt: Date(),
                    chats: []
                ),
                at: 0
            )
        }
        selectedAgentProjectID = selectedAgentProjectID ?? id
    }

    private func agentProjectChatCount(projectID: String) -> Int {
        agentProjects.first { $0.id == projectID }?.chats.count ?? 0
    }

    func approve(_ approval: CommandApproval) {
        guard let index = approvals.firstIndex(where: { $0.id == approval.id }) else { return }
        approvals[index].status = .approved
        if let runID = approval.runID, let runIndex = runs.firstIndex(where: { $0.id == runID }) {
            runs[runIndex].status = .running
            runs[runIndex].progress = 0.15
            appendLog(runID: runID, stream: "ok", message: "Approved. Starting execution.")
            let run = runs[runIndex]
            persist()
            if remoteHost.isEnabled, let remoteRunID = remoteRunIDs[runID.uuidString] {
                Task {
                    do {
                        try await RemoteHostClient(configuration: remoteHost).approve(remoteRunID: remoteRunID)
                        appendLog(runID: runID, stream: "ok", message: "Remote approval sent.")
                        startRemoteStream(localRun: run, remoteRunID: remoteRunID)
                    } catch {
                        appendLog(runID: runID, stream: "warn", message: "Remote approve failed: \(error.localizedDescription)")
                    }
                }
                return
            }
            executeIfAvailable(run)
        } else {
            persist()
        }
    }

    func reject(_ approval: CommandApproval) {
        guard let index = approvals.firstIndex(where: { $0.id == approval.id }) else { return }
        approvals[index].status = .rejected
        if let runID = approval.runID, let runIndex = runs.firstIndex(where: { $0.id == runID }) {
            runs[runIndex].status = .failed
            runs[runIndex].completedAt = Date()
            appendLog(runID: runID, stream: "warn", message: "Rejected. Run stopped.")
            if remoteHost.isEnabled, let remoteRunID = remoteRunIDs[runID.uuidString] {
                Task {
                    try? await RemoteHostClient(configuration: remoteHost).reject(remoteRunID: remoteRunID)
                }
            }
        }
        persist()
    }

    func pauseOrResumeSelectedRun() {
        guard let selectedRunID, let index = runs.firstIndex(where: { $0.id == selectedRunID }) else { return }
        switch runs[index].status {
        case .running:
            runs[index].status = .waiting
            appendLog(runID: selectedRunID, stream: "warn", message: "Paused.")
            if remoteHost.isEnabled, let remoteRunID = remoteRunIDs[selectedRunID.uuidString] {
                Task {
                    do {
                        try await RemoteHostClient(configuration: remoteHost).cancel(remoteRunID: remoteRunID)
                    } catch {
                        appendLog(runID: selectedRunID, stream: "warn", message: "Remote cancel failed: \(error.localizedDescription)")
                    }
                }
            }
        case .waiting:
            runs[index].status = .running
            appendLog(runID: selectedRunID, stream: "ok", message: "Resumed.")
            if remoteHost.isEnabled, let remoteRunID = remoteRunIDs[selectedRunID.uuidString] {
                let run = runs[index]
                Task {
                    do {
                        try await RemoteHostClient(configuration: remoteHost).resume(remoteRunID: remoteRunID)
                        startRemoteStream(localRun: run, remoteRunID: remoteRunID)
                    } catch {
                        appendLog(runID: selectedRunID, stream: "warn", message: "Remote resume failed: \(error.localizedDescription)")
                    }
                }
            }
        default:
            break
        }
        persist()
    }

    func clearLocalHistory() {
        remoteStreamTasks.values.forEach { $0.cancel() }
        remoteStreamTasks = [:]
        remoteStreamTokens = [:]
        remoteStreamStatus = .idle
        runs = []
        approvals = []
        logs = []
        diffs = []
        selectedRunID = nil
        remoteRunIDs = [:]
        persist()
    }

    func logEntries(for runID: UUID?) -> [CommandLogEntry] {
        guard let runID else { return [] }
        return logs.filter { $0.runID == runID }.sorted { $0.time < $1.time }
    }

    func diffEntries(for runID: UUID?) -> [CommandDiffEntry] {
        guard let runID else { return [] }
        return diffs.filter { $0.runID == runID }
    }

    func pendingApprovals(limit: Int? = nil) -> [CommandApproval] {
        let pending = approvals.filter { $0.status == .pending }
        guard let limit else { return pending }
        return Array(pending.prefix(limit))
    }

    func pendingApproval(for runID: UUID?) -> CommandApproval? {
        guard let runID else { return nil }
        return approvals.first { $0.runID == runID && $0.status == .pending }
    }

    func visibleRuns(phase: RunPhase? = nil) -> [CommandRun] {
        runs.filter { run in
            !archivedRunIDs.contains(run.id) && (phase == nil || run.phase == phase)
        }
    }

    func archiveRun(_ run: CommandRun) {
        archivedRunIDs.insert(run.id)
        if selectedRunID == run.id {
            selectedRunID = visibleRuns().first?.id
        }
        persist()
    }

    func hasCustomHistoryTitle(_ session: RemoteHistorySession) -> Bool {
        sessionTitles[session.id]?.nilIfBlank != nil
    }

    func historyTitle(for session: RemoteHistorySession) -> String {
        sessionTitles[session.id]?.nilIfBlank ?? session.summary
    }

    func renameHistorySession(_ session: RemoteHistorySession, title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            sessionTitles.removeValue(forKey: session.id)
        } else {
            sessionTitles[session.id] = clean
        }
        persist()
    }

    func renameSelectedHermesChat(_ title: String) {
        guard var chat = selectedAgentChat else { return }
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        chat.title = clean
        updateAgentChat(chat)
    }

    func startNewDirectSession(_ tool: RemoteHistoryTool) {
        let runtime: CommandRuntime = tool == .codex ? .codexDirect : .claudeDirect
        selectedRuntime = runtime
        submitCommand(
            "Start a new \(tool.title) session from Veqral. Briefly confirm the current workspace and wait for my next instruction.",
            runtime: runtime
        )
    }

    func attachDiffInstruction(_ diff: CommandDiffEntry, hunk: String? = nil) {
        let snippet = (hunk ?? diff.patch ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(3_500)
        let attachmentText: String
        if snippet.isEmpty {
            attachmentText = "\n\n[Diff: \(diff.path)] +\(diff.additions) -\(diff.deletions)\nここを確認して、必要な修正案を出して。"
        } else {
            attachmentText = "\n\n[Diff hunk: \(diff.path)]\n```diff\n\(snippet)\n```\nここをこうして。"
        }
        commandDraft += attachmentText
    }

    private func reconnectRemoteRuns() {
        guard remoteHost.isEnabled, remoteHost.isPaired else { return }
        for run in runs where [.running, .waiting, .approval].contains(run.status) {
            if let remoteRunID = remoteRunIDs[run.id.uuidString] {
                startRemoteStream(localRun: run, remoteRunID: remoteRunID)
            }
        }
    }

    private func mergeRemoteRuns(_ remoteRuns: [RemoteRunRecord], client: RemoteHostClient) async {
        for remoteRun in remoteRuns {
            let localID = remoteRunIDs.first { $0.value == remoteRun.id }.flatMap { UUID(uuidString: $0.key) }
            if let localID, let index = runs.firstIndex(where: { $0.id == localID }) {
                runs[index].status = Self.localStatus(from: remoteRun.status)
                runs[index].progress = Self.progress(for: remoteRun.status)
                runs[index].completedAt = remoteRun.completedAt
                runs[index].device = remoteHost.name.isEmpty ? remoteHost.endpoint : remoteHost.name
                runs[index].runtime = Self.runtime(from: remoteRun.engine)
                runs[index].model = "\(runs[index].runtimeOrDefault.shortTitle) via Mac Host"
                runs[index].resumeSessionID = remoteRun.resumeSessionID ?? remoteRun.sessionID
                runs[index].agentProjectID = remoteRun.projectID
                runs[index].agentChatID = remoteRun.chatID
                runs[index].provider = remoteRun.provider
                runs[index].providerModel = remoteRun.model
                runs[index].usage = remoteRun.usage
                if remoteRun.status == "waitingApproval", !approvals.contains(where: { $0.runID == localID && $0.status == .pending }) {
                    insertRemoteApproval(
                        for: runs[index],
                        reason: remoteRun.approvalReason ?? "Remote approval required",
                        severity: remoteRun.approvalSeverity
                    )
                }
                await syncRemoteRunDetails(localRunID: localID, remoteRunID: remoteRun.id, client: client)
                continue
            }

            let localRun = CommandRun(
                id: UUID(),
                title: title(for: remoteRun.prompt),
                command: remoteRun.prompt,
                runtime: Self.runtime(from: remoteRun.engine),
                phase: .implementation,
                status: Self.localStatus(from: remoteRun.status),
                agent: agentLabel(for: Self.runtime(from: remoteRun.engine)),
                device: remoteHost.name.isEmpty ? remoteHost.endpoint : remoteHost.name,
                model: "\(Self.runtime(from: remoteRun.engine).shortTitle) via Mac Host",
                progress: Self.progress(for: remoteRun.status),
                startedAt: remoteRun.startedAt,
                completedAt: remoteRun.completedAt,
                workingDirectory: remoteRun.workingDirectory,
                resumeSessionID: remoteRun.resumeSessionID ?? remoteRun.sessionID,
                agentProjectID: remoteRun.projectID,
                agentChatID: remoteRun.chatID,
                provider: remoteRun.provider,
                providerModel: remoteRun.model,
                usage: remoteRun.usage
            )
            runs.append(localRun)
            remoteRunIDs[localRun.id.uuidString] = remoteRun.id
            if remoteRun.status == "waitingApproval" {
                insertRemoteApproval(
                    for: localRun,
                    reason: remoteRun.approvalReason ?? "Remote approval required",
                    severity: remoteRun.approvalSeverity
                )
            }

            do {
                let response = try await client.runLogs(remoteRunID: remoteRun.id)
                let existing = Set(logs.filter { $0.runID == localRun.id }.map { "\($0.time.timeIntervalSince1970)-\($0.stream)-\($0.message)" })
                for event in response.logs {
                    let key = "\(event.createdAt.timeIntervalSince1970)-\(event.stream)-\(event.message)"
                    guard !existing.contains(key) else { continue }
                    logs.append(CommandLogEntry(id: UUID(), runID: localRun.id, time: event.createdAt, stream: event.stream, message: event.message))
                }
            } catch {
                appendLog(runID: localRun.id, stream: "warn", message: "Remote log sync failed: \(error.localizedDescription)")
            }
            await syncRemoteRunDetails(localRunID: localRun.id, remoteRunID: remoteRun.id, client: client)
        }
        runs.sort { $0.startedAt > $1.startedAt }
        selectedRunID = selectedRunID ?? runs.first?.id
        persist()
        reconnectRemoteRuns()
    }

    private func syncRemoteRunDetails(localRunID: UUID, remoteRunID: String, client: RemoteHostClient) async {
        do {
            let response = try await client.runDiff(remoteRunID: remoteRunID)
            diffs.removeAll { $0.runID == localRunID }
            diffs.append(contentsOf: response.files.map { file in
                CommandDiffEntry(
                    id: UUID(),
                    runID: localRunID,
                    path: file.path,
                    additions: file.additions,
                    deletions: file.deletions,
                    patch: file.patch
                )
            })
        } catch {
            appendLog(runID: localRunID, stream: "warn", message: "Remote diff sync failed: \(error.localizedDescription)")
        }

        do {
            let response = try await client.runArtifacts(remoteRunID: remoteRunID)
            let incomingIDs = Set(response.artifacts.map(\.id))
            remoteArtifacts.removeAll { incomingIDs.contains($0.id) }
            remoteArtifacts.append(contentsOf: response.artifacts)
            remoteArtifacts.sort { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
            remoteArtifacts = Array(remoteArtifacts.prefix(80))
            for artifact in response.artifacts.filter(Self.isImageArtifact).prefix(8) where artifactImageData[artifact.id] == nil {
                do {
                    let content = try await client.artifactContent(remoteRunID: remoteRunID, artifactID: artifact.id)
                    artifactImageData[artifact.id] = content.data
                } catch {
                    appendLog(runID: localRunID, stream: "warn", message: "Remote image artifact preview failed: \(error.localizedDescription)")
                }
            }
        } catch {
            appendLog(runID: localRunID, stream: "warn", message: "Remote artifact sync failed: \(error.localizedDescription)")
        }
    }

    private static func isImageArtifact(_ artifact: RemoteArtifactRecord) -> Bool {
        let type = artifact.type.lowercased()
        let path = artifact.path.lowercased()
        return ["png", "jpg", "jpeg", "gif", "image/png", "image/jpeg", "image/gif"].contains(type)
            || path.hasSuffix(".png")
            || path.hasSuffix(".jpg")
            || path.hasSuffix(".jpeg")
            || path.hasSuffix(".gif")
    }

    private func insertRemoteApproval(for run: CommandRun, reason: String, severity: String? = nil) {
        let isHigh = severity != "low"
        approvals.insert(
            CommandApproval(
                id: UUID(),
                runID: run.id,
                title: run.title,
                detail: reason,
                command: run.command,
                risk: isHigh ? "高" : "中",
                tintName: isHigh ? "red" : "amber",
                status: .pending,
                createdAt: Date()
            ),
            at: 0
        )
        notify(title: L10n.tr("Veqral approval required"), body: reason)
    }

    private func executeIfAvailable(_ run: CommandRun, attachments: [CommandAttachment] = []) {
        if remoteHost.isEnabled {
            executeRemote(run, attachments: attachments)
            return
        }

        #if targetEnvironment(macCatalyst)
        appendLog(runID: run.id, stream: "info", message: "Running \(run.runtimeOrDefault.title) in \(run.workingDirectory)")
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                switch run.runtimeOrDefault {
                case .hermesAgent:
                    LocalCommandExecutor.runHermes(prompt: run.command, workingDirectory: run.workingDirectory)
                case .codexDirect, .claudeDirect:
                    LocalCommandResult(
                        exitCode: 64,
                        stdoutLines: [],
                        stderrLines: ["Direct Codex/Claude runs are launched through the paired Mac Host so session history stays in the native CLI store."],
                        diffEntries: []
                    )
                case .localShell:
                    LocalCommandExecutor.run(command: run.command, workingDirectory: run.workingDirectory)
                }
            }.value
            applyExecutionResult(result, runID: run.id)
        }
        #else
        appendLog(runID: run.id, stream: "warn", message: "iPhone/iPad can create runs. Execution requires the Mac app or a Mac Host connection.")
        if let index = runs.firstIndex(where: { $0.id == run.id }) {
            runs[index].status = .waiting
            runs[index].progress = 0.25
        }
        persist()
        #endif
    }

    private func executeRemote(_ run: CommandRun, attachments: [CommandAttachment]) {
        guard remoteHost.isPaired else {
            appendLog(runID: run.id, stream: "warn", message: "Remote Host is enabled but not paired.")
            if let index = runs.firstIndex(where: { $0.id == run.id }) {
                runs[index].status = .waiting
            }
            persist()
            return
        }

        appendLog(runID: run.id, stream: "info", message: "Sending run to \(remoteHost.displayEndpoint)")
        let configuration = remoteHost
        Task {
            do {
                let response = try await RemoteHostClient(configuration: configuration).createRun(
                    prompt: run.command,
                    workingDirectory: run.workingDirectory,
                    runtime: run.runtimeOrDefault,
                    resumeSessionID: run.resumeSessionID,
                    projectID: run.agentProjectID,
                    chatID: run.agentChatID,
                    provider: run.provider,
                    model: run.providerModel,
                    attachments: attachments
                )
                remoteRunIDs[run.id.uuidString] = response.runID
                if let sessionID = response.sessionID ?? run.resumeSessionID, let chatID = run.agentChatID {
                    updateAgentChatSession(chatID: chatID, sessionID: sessionID)
                }
                if let index = runs.firstIndex(where: { $0.id == run.id }) {
                    runs[index].status = response.approvalRequired == true || response.status == "waitingApproval" ? .approval : .running
                    runs[index].progress = response.approvalRequired == true || response.status == "waitingApproval" ? 0.0 : 0.20
                    runs[index].device = configuration.name.isEmpty ? configuration.endpoint : configuration.name
                    runs[index].model = "\(run.runtimeOrDefault.shortTitle) via Mac Host"
                    runs[index].resumeSessionID = response.sessionID ?? run.resumeSessionID
                }
                appendLog(runID: run.id, stream: "ok", message: "Remote run \(response.runID) \(response.status)")
                persist()
                startRemoteStream(localRun: run, remoteRunID: response.runID)
                if response.approvalRequired == true || response.status == "waitingApproval" {
                    let message = response.approvalReason ?? "Remote approval required"
                    approvals.insert(
                        CommandApproval(
                            id: UUID(),
                            runID: run.id,
                            title: run.title,
                            detail: message,
                            command: run.command,
                            risk: response.approvalSeverity == "low" ? "中" : "高",
                            tintName: response.approvalSeverity == "low" ? "amber" : "red",
                            status: .pending,
                            createdAt: Date()
                        ),
                        at: 0
                    )
                    appendLog(runID: run.id, stream: "approval", message: "Remote approval required: \(message)")
                    notify(title: L10n.tr("Veqral approval required"), body: message)
                    persist()
                }
            } catch RemoteHostError.approvalRequired(let message) {
                if let index = runs.firstIndex(where: { $0.id == run.id }) {
                    runs[index].status = .approval
                    runs[index].progress = 0
                }
                approvals.insert(
                    CommandApproval(
                        id: UUID(),
                        runID: run.id,
                        title: run.title,
                        detail: message,
                        command: run.command,
                        risk: "高",
                        tintName: "red",
                        status: .pending,
                        createdAt: Date()
                    ),
                    at: 0
                )
                appendLog(runID: run.id, stream: "approval", message: "Remote approval required: \(message)")
                notify(title: L10n.tr("Veqral approval required"), body: message)
                persist()
            } catch {
                let message = Self.remoteFailureMessage(error, context: "Remote run")
                remoteHostMessage = message
                appendLog(runID: run.id, stream: "warn", message: message)
                if let index = runs.firstIndex(where: { $0.id == run.id }) {
                    runs[index].status = .waiting
                    runs[index].progress = 0.10
                }
                persist()
            }
        }
    }

    private func startRemoteStream(localRun run: CommandRun, remoteRunID: String) {
        remoteStreamTasks[run.id]?.cancel()
        let configuration = remoteHost
        let streamToken = UUID()
        remoteStreamTokens[run.id] = streamToken
        remoteStreamStatus = RemoteStreamStatus(
            phase: .connecting,
            runID: run.id,
            runTitle: run.title,
            detail: L10n.tr("Opening log stream."),
            attempt: 0,
            nextRetrySeconds: nil
        )
        remoteStreamTasks[run.id] = Task {
            let client = RemoteHostClient(configuration: configuration)
            var reconnectAttempt = 0
            defer {
                if remoteStreamTokens[run.id] == streamToken {
                    remoteStreamTasks[run.id] = nil
                    remoteStreamTokens[run.id] = nil
                    clearRemoteStreamStatus(for: run.id)
                }
            }

            while !Task.isCancelled {
                do {
                    if reconnectAttempt > 0 {
                        let shouldContinue = try await prepareRemoteStreamReconnect(
                            localRun: run,
                            remoteRunID: remoteRunID,
                            client: client,
                            attempt: reconnectAttempt
                        )
                        guard shouldContinue, !Task.isCancelled else { return }
                    }

                    remoteStreamStatus = RemoteStreamStatus(
                        phase: reconnectAttempt == 0 ? .connecting : .reconnecting,
                        runID: run.id,
                        runTitle: run.title,
                        detail: reconnectAttempt == 0 ? L10n.tr("Opening log stream.") : L10n.tr("Resuming remote run before reconnect."),
                        attempt: reconnectAttempt,
                        nextRetrySeconds: nil
                    )

                    for try await event in client.stream(remoteRunID: remoteRunID) {
                        guard !Task.isCancelled else { return }
                        reconnectAttempt = 0
                        remoteStreamStatus = RemoteStreamStatus(
                            phase: .connected,
                            runID: run.id,
                            runTitle: run.title,
                            detail: L10n.tr("Streaming run logs."),
                            attempt: 0,
                            nextRetrySeconds: nil
                        )
                        let didFinish = await applyRemoteStreamEvent(event, localRunID: run.id, fallbackRun: run, client: client)
                        if didFinish {
                            return
                        }
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    let message = Self.remoteFailureMessage(error, context: "Remote stream")
                    remoteHostMessage = message
                    if Self.isRemoteAuthenticationFailure(error) {
                        appendLog(runID: run.id, stream: "warn", message: message)
                        remoteStreamStatus = RemoteStreamStatus(
                            phase: .disconnected,
                            runID: run.id,
                            runTitle: run.title,
                            detail: message,
                            attempt: reconnectAttempt,
                            nextRetrySeconds: nil
                        )
                        if let index = runs.firstIndex(where: { $0.id == run.id }), runs[index].status == .running {
                            runs[index].status = .waiting
                        }
                        persist()
                        return
                    }

                    if isTerminalLocalRun(run.id) {
                        return
                    }

                    reconnectAttempt += 1
                    let delay = Self.remoteReconnectDelaySeconds(attempt: reconnectAttempt)
                    remoteStreamStatus = RemoteStreamStatus(
                        phase: .reconnecting,
                        runID: run.id,
                        runTitle: run.title,
                        detail: message,
                        attempt: reconnectAttempt,
                        nextRetrySeconds: delay
                    )
                    if reconnectAttempt == 1 {
                        appendLog(runID: run.id, stream: "warn", message: message)
                    }
                    if reconnectAttempt <= 3 || reconnectAttempt % 3 == 0 {
                        appendLog(runID: run.id, stream: "info", message: "Reconnecting log stream in \(delay)s (attempt \(reconnectAttempt)).")
                    }
                    try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                }
            }
        }
    }

    private func prepareRemoteStreamReconnect(
        localRun run: CommandRun,
        remoteRunID: String,
        client: RemoteHostClient,
        attempt: Int
    ) async throws -> Bool {
        let snapshot = try await client.runSnapshot(remoteRunID: remoteRunID)
        let didFinish = await applyRemoteRunSnapshot(snapshot, localRunID: run.id, remoteRunID: remoteRunID, client: client)
        guard !didFinish else { return false }

        if ["running", "queued", "needsAttention"].contains(snapshot.run.status) {
            try await client.resume(remoteRunID: remoteRunID)
            if attempt == 1 {
                appendLog(runID: run.id, stream: "info", message: "Remote resume requested before reconnecting the log stream.")
            }
        }
        return true
    }

    private func applyRemoteRunSnapshot(
        _ snapshot: RemoteRunSnapshotResponse,
        localRunID: UUID,
        remoteRunID: String,
        client: RemoteHostClient
    ) async -> Bool {
        remoteRunIDs[localRunID.uuidString] = remoteRunID
        if let index = runs.firstIndex(where: { $0.id == localRunID }) {
            runs[index].status = Self.localStatus(from: snapshot.run.status)
            runs[index].progress = Self.progress(for: snapshot.run.status)
            runs[index].completedAt = snapshot.run.completedAt
            runs[index].resumeSessionID = snapshot.run.resumeSessionID ?? snapshot.run.sessionID
            runs[index].agentProjectID = snapshot.run.projectID
            runs[index].agentChatID = snapshot.run.chatID
            runs[index].provider = snapshot.run.provider
            runs[index].providerModel = snapshot.run.model
            runs[index].usage = snapshot.run.usage
            if snapshot.run.status == "waitingApproval",
               !approvals.contains(where: { $0.runID == localRunID && $0.status == .pending }) {
                insertRemoteApproval(
                    for: runs[index],
                    reason: snapshot.run.approvalReason ?? "Remote approval required",
                    severity: snapshot.run.approvalSeverity
                )
            }
        }
        for event in snapshot.logs {
            appendRemoteLogEvent(event, localRunID: localRunID)
        }
        persist()

        if Self.isTerminalRemoteStatus(snapshot.run.status) {
            await syncRemoteRunDetails(localRunID: localRunID, remoteRunID: remoteRunID, client: client)
            scheduleWorkspaceRefresh(delayNanoseconds: 0)
            return true
        }
        return false
    }

    private func applyRemoteStreamEvent(
        _ event: RemoteHostLogEvent,
        localRunID: UUID,
        fallbackRun: CommandRun,
        client: RemoteHostClient
    ) async -> Bool {
        appendRemoteLogEvent(event, localRunID: localRunID)
        let currentRun = runs.first { $0.id == localRunID } ?? fallbackRun

        if let sessionID = event.sessionID {
            appendRemoteLogEvent(
                RemoteHostLogEvent(
                    runID: event.runID,
                    kind: "status",
                    stream: "session",
                    message: "session_id: \(sessionID)",
                    createdAt: event.createdAt,
                    sessionID: sessionID,
                    exitCode: nil
                ),
                localRunID: localRunID
            )
            if let chatID = currentRun.agentChatID {
                updateAgentChatSession(chatID: chatID, sessionID: sessionID)
            }
        }

        if event.kind == "complete" {
            do {
                let snapshot = try await client.runSnapshot(remoteRunID: event.runID)
                _ = await applyRemoteRunSnapshot(snapshot, localRunID: localRunID, remoteRunID: event.runID, client: client)
            } catch {
                if let index = runs.firstIndex(where: { $0.id == localRunID }) {
                    runs[index].status = event.exitCode == 0 ? .complete : .failed
                    runs[index].progress = 1.0
                    runs[index].completedAt = Date()
                }
                persist()
                await syncRemoteRunDetails(localRunID: localRunID, remoteRunID: event.runID, client: client)
                scheduleWorkspaceRefresh(delayNanoseconds: 0)
            }
            notify(
                title: event.exitCode == 0 ? L10n.tr("Veqral run complete") : L10n.tr("Veqral run failed"),
                body: currentRun.title
            )
            return true
        }

        if event.kind == "approval" {
            notify(title: L10n.tr("Veqral approval required"), body: event.message)
        }
        return false
    }

    @discardableResult
    private func appendRemoteLogEvent(_ event: RemoteHostLogEvent, localRunID: UUID) -> Bool {
        let lines = event.message.split(whereSeparator: \.isNewline).map(String.init)
        let messages = lines.isEmpty ? [""] : Array(lines.prefix(160))
        var inserted = false
        for message in messages {
            guard !remoteLogExists(runID: localRunID, time: event.createdAt, stream: event.stream, message: message) else {
                continue
            }
            logs.append(CommandLogEntry(id: UUID(), runID: localRunID, time: event.createdAt, stream: event.stream, message: message))
            inserted = true
        }
        if logs.count > 700 {
            logs.removeFirst(logs.count - 700)
        }
        return inserted
    }

    private func remoteLogExists(runID: UUID, time: Date, stream: String, message: String) -> Bool {
        logs.contains { entry in
            entry.runID == runID &&
            entry.stream == stream &&
            entry.message == message &&
            abs(entry.time.timeIntervalSince(time)) < 0.001
        }
    }

    private func clearRemoteStreamStatus(for runID: UUID) {
        guard remoteStreamStatus.runID == runID else { return }
        if remoteStreamStatus.phase == .disconnected {
            return
        }
        if remoteStreamTasks.keys.contains(where: { $0 != runID }) {
            remoteStreamStatus = RemoteStreamStatus(
                phase: .connected,
                runID: nil,
                runTitle: L10n.tr("Remote streams active"),
                detail: L10n.tr("Streaming run logs."),
                attempt: 0,
                nextRetrySeconds: nil
            )
        } else {
            remoteStreamStatus = .idle
        }
    }

    private func isTerminalLocalRun(_ runID: UUID) -> Bool {
        guard let status = runs.first(where: { $0.id == runID })?.status else { return false }
        return [.complete, .failed].contains(status)
    }

    private static func isTerminalRemoteStatus(_ status: String) -> Bool {
        ["complete", "failed", "cancelled"].contains(status)
    }

    private static func remoteReconnectDelaySeconds(attempt: Int) -> Int {
        min(30, max(1, 1 << min(max(attempt - 1, 0), 5)))
    }

    private static func remoteFailureMessage(_ error: Error, context: String) -> String {
        if isRemoteAuthenticationFailure(error) {
            return "\(context) authentication failed. Pair this device with Mac Host again."
        }

        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("timed out")
            || message.localizedCaseInsensitiveContains("cannot connect")
            || message.localizedCaseInsensitiveContains("network connection was lost")
            || message.localizedCaseInsensitiveContains("not connected to the internet") {
            return "\(context) disconnected. Check Tailscale and Mac Host, then retry."
        }

        return "\(context) failed: \(message)"
    }

    private static func isRemoteAuthenticationFailure(_ error: Error) -> Bool {
        if let remoteError = error as? RemoteHostError {
            if case .authentication = remoteError {
                return true
            }
        }
        let message = error.localizedDescription
        return message.localizedCaseInsensitiveContains("unauthorized")
            || message.localizedCaseInsensitiveContains("forbidden")
            || message.localizedCaseInsensitiveContains("invalid signature")
            || message.localizedCaseInsensitiveContains("expired signature")
            || message.localizedCaseInsensitiveContains("unknown device")
    }

    private func applyExecutionResult(_ result: LocalCommandResult, runID: UUID) {
        for line in result.stdoutLines {
            appendLog(runID: runID, stream: result.exitCode == 0 ? "ok" : "info", message: line)
        }
        for line in result.stderrLines {
            appendLog(runID: runID, stream: "warn", message: line)
        }
        if let index = runs.firstIndex(where: { $0.id == runID }) {
            runs[index].status = result.exitCode == 0 ? .complete : .failed
            runs[index].progress = 1.0
            runs[index].completedAt = Date()
        }
        if !result.diffEntries.isEmpty {
            diffs.removeAll { $0.runID == runID }
            diffs.append(contentsOf: result.diffEntries.map {
                CommandDiffEntry(id: UUID(), runID: runID, path: $0.path, additions: $0.additions, deletions: $0.deletions, patch: $0.patch)
            })
        }
        appendLog(runID: runID, stream: result.exitCode == 0 ? "ok" : "warn", message: "Exit code: \(result.exitCode)")
        persist()
        scheduleWorkspaceRefresh(delayNanoseconds: 0)
    }

    private func appendLog(runID: UUID, stream: String, message: String) {
        let lines = message.split(whereSeparator: \.isNewline).map(String.init)
        if lines.isEmpty {
            logs.append(CommandLogEntry(id: UUID(), runID: runID, time: Date(), stream: stream, message: ""))
        } else {
            for line in lines.prefix(160) {
                logs.append(CommandLogEntry(id: UUID(), runID: runID, time: Date(), stream: stream, message: line))
            }
        }
        if logs.count > 700 {
            logs.removeFirst(logs.count - 700)
        }
    }

    private func upsertCostSummary(_ summary: RemoteProjectCostSummary) {
        if let index = projectCostSummaries.firstIndex(where: { $0.projectKey == summary.projectKey }) {
            projectCostSummaries[index] = summary
        } else {
            projectCostSummaries.insert(summary, at: 0)
        }
    }

    private func localCostSummaries() -> [RemoteProjectCostSummary] {
        let keys = Set(runs.map { Self.costProjectKey(projectID: $0.agentProjectID, workingDirectory: $0.workingDirectory) })
        return keys.map { key in
            let run = runs.first { Self.costProjectKey(projectID: $0.agentProjectID, workingDirectory: $0.workingDirectory) == key }
            return localCostSummary(projectKey: key, projectID: run?.agentProjectID, workingDirectory: run?.workingDirectory ?? workingDirectory)
        }
        .sorted { $0.costUSD > $1.costUSD }
    }

    private func localCostSummary(projectKey: String, projectID: String?, workingDirectory: String) -> RemoteProjectCostSummary {
        let matchingRuns = runs.filter {
            Self.costProjectKey(projectID: $0.agentProjectID, workingDirectory: $0.workingDirectory) == projectKey
        }
        let usage = matchingRuns.compactMap(\.usage)
        let input = usage.compactMap(\.inputTokens).reduce(0, +)
        let output = usage.compactMap(\.outputTokens).reduce(0, +)
        let reasoning = usage.compactMap(\.reasoningTokens).reduce(0, +)
        let total = usage.compactMap(\.totalTokensOrDerived).reduce(0, +)
        let estimated = usage.compactMap(\.estimatedCostUSD).reduce(0, +)
        let actual = usage.compactMap(\.actualCostUSD).reduce(0, +)
        let existingBudget = projectCostSummaries.first { $0.projectKey == projectKey }
        let limit = existingBudget?.budgetLimitUSD
        let threshold = existingBudget?.thresholdPercent ?? 0.8
        let cost = actual > 0 ? actual : estimated
        let over = limit.map { $0 > 0 && cost >= $0 } ?? false
        let near = limit.map { $0 > 0 && cost >= $0 * threshold } ?? false
        return RemoteProjectCostSummary(
            projectKey: projectKey,
            projectID: projectID,
            workingDirectory: workingDirectory.nilIfBlank,
            displayName: projectID?.nilIfBlank ?? URL(fileURLWithPath: workingDirectory).lastPathComponent.nilIfBlank ?? "Project",
            runCount: matchingRuns.count,
            inputTokens: input,
            outputTokens: output,
            reasoningTokens: reasoning,
            totalTokens: total,
            estimatedCostUSD: estimated,
            actualCostUSD: actual,
            costUSD: cost,
            budgetLimitUSD: limit,
            thresholdPercent: threshold,
            paused: existingBudget?.paused ?? false,
            isNearLimit: near,
            isOverLimit: over
        )
    }

    private static func costProjectKey(projectID: String?, workingDirectory: String) -> String {
        if let projectID = projectID?.nilIfBlank {
            return "project:\(projectID)"
        }
        let directory = workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSHomeDirectory() : workingDirectory
        return "path:\(NSString(string: directory).expandingTildeInPath)"
    }

    private func title(for command: String) -> String {
        if command.count <= 52 {
            return command
        }
        return String(command.prefix(49)) + "..."
    }

    private func agentLabel(for runtime: CommandRuntime) -> String {
        switch runtime {
        case .hermesAgent:
            "Hermes"
        case .codexDirect:
            "Codex"
        case .claudeDirect:
            "Claude"
        case .localShell:
            "Local Mac"
        }
    }

    private static func localStatus(from remoteStatus: String) -> RunStatus {
        switch remoteStatus {
        case "queued", "running":
            .running
        case "waitingApproval":
            .approval
        case "cancelled", "needsAttention":
            .waiting
        case "complete":
            .complete
        case "failed":
            .failed
        default:
            .waiting
        }
    }

    private static func progress(for remoteStatus: String) -> Double {
        switch remoteStatus {
        case "queued":
            0.12
        case "running":
            0.45
        case "waitingApproval":
            0
        case "complete":
            1
        case "failed", "cancelled":
            1
        default:
            0.2
        }
    }

    private static func runtime(from remoteEngine: String?) -> CommandRuntime {
        switch remoteEngine {
        case "codex":
            .codexDirect
        case "claude":
            .claudeDirect
        case "shell":
            .localShell
        default:
            .hermesAgent
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func riskDescription(for command: String) -> (label: String, detail: String, tintName: String)? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let words = commandWords(in: lower)

        if containsCommandName(in: words, matching: ["rm", "rmdir", "unlink", "shred", "dd", "mkfs"]) || lower.contains("trash") || lower.contains("git clean") || lower.contains("git reset --hard") || lower.contains("diskutil erase") {
            return ("高", "ファイル削除を含む可能性があります。", "red")
        }
        if containsCommandName(in: words, matching: ["sudo", "su"]) {
            return ("高", "管理者権限を要求しています。", "red")
        }
        if lower.contains("curl") && (lower.contains("| sh") || lower.contains("| bash") || lower.contains("| zsh")) {
            return ("高", "ネットワークから取得したスクリプトを直接実行しようとしています。", "red")
        }
        if lower.contains("deploy") || lower.contains("production") || lower.contains("prod") || lower.contains("terraform apply") || lower.contains("terraform destroy") || lower.contains("kubectl apply") || lower.contains("kubectl delete") {
            return ("高", "本番環境に影響する可能性があります。", "red")
        }
        if lower.contains("secret") || lower.contains("token") || lower.contains("keychain") || lower.contains(".env") || lower.contains("id_rsa") || lower.contains("private_key") {
            return ("中", "秘密情報に触れる可能性があります。", "amber")
        }
        if lower.contains("open ") || lower.contains("osascript") || lower.contains("screencapture") {
            return ("中", "画面操作またはアプリ起動を含みます。", "amber")
        }
        if containsCommandName(in: words, matching: ["mv", "cp", "touch", "mkdir", "chmod", "chown", "install", "brew", "npm", "pnpm", "yarn", "pip", "gem", "bundle", "git"]) && !isReadOnlyCommand(lower) {
            return ("中", "作業ツリーまたはローカル環境を変更する可能性があります。", "amber")
        }
        if !isReadOnlyCommand(lower) {
            return ("中", "読み取り専用と判断できないため、実行前に承認します。", "amber")
        }
        return nil
    }

    private func hermesRiskDescription(for prompt: String) -> (label: String, detail: String, tintName: String)? {
        let lower = prompt.lowercased()
        if lower.contains("rm ") || lower.contains("delete") || lower.contains("remove files") || lower.contains("git clean") || lower.contains("reset --hard") {
            return ("高", "Hermes may delete files or discard local work.", "red")
        }
        if lower.contains("deploy") || lower.contains("production") || lower.contains("prod") || lower.contains("terraform apply") || lower.contains("kubectl apply") || lower.contains("billing") || lower.contains("payment") {
            return ("高", "Hermes may affect production, infrastructure, or billing.", "red")
        }
        if lower.contains("secret") || lower.contains("token") || lower.contains("password") || lower.contains("keychain") || lower.contains(".env") || lower.contains("private key") {
            return ("中", "Hermes may inspect or modify secret material.", "amber")
        }
        if lower.contains("computer use") || lower.contains("screen") || lower.contains("browser") || lower.contains("open app") || lower.contains("screenshot") {
            return ("中", "Hermes may use browser or screen-control tools.", "amber")
        }
        return nil
    }

    private func commandWords(in command: String) -> [String] {
        command.split { character in
            !(character.isLetter || character.isNumber || character == "-" || character == "_" || character == "." || character == "/")
        }
        .map { token in
            String(token.split(separator: "/").last ?? token)
        }
    }

    private func containsCommandName(in words: [String], matching names: Set<String>) -> Bool {
        words.contains { names.contains($0) }
    }

    private func isReadOnlyCommand(_ command: String) -> Bool {
        if command.contains(">") || command.contains("&&") || command.contains(";") || command.contains("| sh") || command.contains("| bash") || command.contains("| zsh") {
            return false
        }

        let tokens = command.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let executable = tokens.first?.split(separator: "/").last.map(String.init) else {
            return true
        }

        switch executable {
        case "pwd", "ls", "la", "ll", "tree", "cat", "head", "tail", "wc", "grep", "egrep", "fgrep", "rg", "du", "df", "whoami", "uname", "date", "which", "whereis", "env", "printenv":
            return true
        case "find":
            return !tokens.contains("-delete") && !tokens.contains("-exec")
        case "sed":
            return !tokens.contains("-i")
        case "awk":
            return true
        case "swift":
            return tokens.dropFirst().allSatisfy { $0 == "--version" || $0 == "-version" }
        case "xcodebuild":
            return tokens.contains("-list") || tokens.contains("-showBuildSettings") || tokens.contains("-showsdks") || tokens.contains("-version")
        case "git":
            guard tokens.count > 1 else { return true }
            let subcommand = tokens[1]
            let safeSubcommands: Set<String> = ["status", "diff", "log", "show", "rev-parse", "ls-files", "grep", "describe"]
            if safeSubcommands.contains(subcommand) {
                return true
            }
            if subcommand == "branch" {
                return !tokens.contains("-d") && !tokens.contains("-D") && !tokens.contains("-m") && !tokens.contains("-M")
            }
            if subcommand == "remote" {
                guard tokens.count > 2 else { return true }
                return !["add", "remove", "rm", "rename", "set-url"].contains(tokens[2])
            }
            return false
        default:
            return false
        }
    }

    private func scheduleWorkspaceRefresh(delayNanoseconds: UInt64 = 350_000_000) {
        workspaceRefreshTask?.cancel()
        let directory = workingDirectory
        workspace = WorkspaceSnapshot.empty(workingDirectory: directory)

        #if targetEnvironment(macCatalyst)
        workspaceRefreshTask = Task { [weak self] in
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            guard !Task.isCancelled else { return }
            let snapshot = await Task.detached(priority: .utility) {
                LocalCommandExecutor.inspectWorkspace(workingDirectory: directory)
            }.value
            guard !Task.isCancelled else { return }
            guard let self, self.workingDirectory == directory else { return }
            self.workspace = snapshot
        }
        #else
        workspace = WorkspaceSnapshot.unavailable(
            workingDirectory: directory,
            message: "ローカルコマンド実行はMac版またはMac Host接続が必要です。"
        )
        #endif
    }

    private func persist() {
        var persistedRemoteHost = remoteHost
        persistedRemoteHost.token = ""
        let snapshot = CommandCenterSnapshot(
            schemaVersion: 4,
            runs: runs,
            approvals: approvals,
            logs: logs,
            diffs: diffs,
            selectedRunID: selectedRunID,
            selectedRuntime: selectedRuntime,
            remoteHost: persistedRemoteHost,
            remoteRunIDs: remoteRunIDs,
            workingDirectory: workingDirectory,
            agentProjects: agentProjects,
            selectedAgentProjectID: selectedAgentProjectID,
            selectedAgentChatID: selectedAgentChatID,
            selectedHermesProvider: selectedHermesProvider,
            selectedHermesModel: selectedHermesModel,
            appLanguage: appLanguage,
            sessionTitles: sessionTitles,
            archivedRunIDs: archivedRunIDs,
            savedCommandDrafts: savedCommandDrafts
        )
        do {
            let data = try JSONEncoder.commandCenter.encode(snapshot)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            print("Failed to persist command center state: \(error)")
        }
    }

    private static func loadSnapshot(from url: URL) -> CommandCenterSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.commandCenter.decode(CommandCenterSnapshot.self, from: data)
    }

    private static func emptySnapshot(defaultWorkingDirectory: String) -> CommandCenterSnapshot {
        return CommandCenterSnapshot(
            schemaVersion: 4,
            runs: [],
            approvals: [],
            logs: [],
            diffs: [],
            selectedRunID: nil,
            selectedRuntime: .hermesAgent,
            remoteHost: .empty,
            remoteRunIDs: [:],
            workingDirectory: defaultWorkingDirectory,
            agentProjects: [],
            selectedAgentProjectID: nil,
            selectedAgentChatID: nil,
            selectedHermesProvider: "auto",
            selectedHermesModel: "",
            appLanguage: UserDefaults.standard.string(forKey: "appLanguage").flatMap(AppLanguage.init(rawValue:)) ?? .system,
            sessionTitles: [:],
            archivedRunIDs: [],
            savedCommandDrafts: []
        )
    }

    private static func productionCleanedSnapshot(_ snapshot: CommandCenterSnapshot) -> CommandCenterSnapshot {
        let removedRunIDs = Set(snapshot.runs.filter(isLegacySeedOrDiagnosticRun).map(\.id))
        var cleaned = snapshot
        cleaned.schemaVersion = 4
        cleaned.runs = snapshot.runs.filter { !removedRunIDs.contains($0.id) }
        cleaned.approvals = snapshot.approvals.filter { approval in
            if let runID = approval.runID, removedRunIDs.contains(runID) { return false }
            return !isLegacySeedApproval(approval)
        }
        cleaned.logs = snapshot.logs.filter { !removedRunIDs.contains($0.runID) && !isLegacySeedLog($0) }
        cleaned.diffs = snapshot.diffs.filter { !removedRunIDs.contains($0.runID) }
        cleaned.remoteRunIDs = snapshot.remoteRunIDs?.filter { key, _ in
            guard let id = UUID(uuidString: key) else { return true }
            return !removedRunIDs.contains(id)
        }
        if let selected = cleaned.selectedRunID, removedRunIDs.contains(selected) {
            cleaned.selectedRunID = cleaned.runs.first?.id
        }
        cleaned.archivedRunIDs = cleaned.archivedRunIDs?.subtracting(removedRunIDs)
        cleaned.savedCommandDrafts = mergedSavedCommandDrafts(
            primary: cleaned.savedCommandDrafts ?? [],
            fallback: []
        )
        return cleaned
    }

    private func persistSavedCommandDrafts() {
        persist()
        SavedCommandDraftCache.save(savedCommandDrafts, cacheFolder: persistenceURL.deletingLastPathComponent())
    }

    private static func savedCommandKey(command: String, runtime: CommandRuntime?) -> String {
        "\(runtime?.rawValue ?? "any")|\(command.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    private static func mergedSavedCommandDrafts(primary: [SavedCommandDraft], fallback: [SavedCommandDraft]) -> [SavedCommandDraft] {
        var seen: Set<String> = []
        let merged = (primary + fallback)
            .sorted { lhs, rhs in lhs.updatedAt > rhs.updatedAt }
            .filter { draft in
                let command = draft.command.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !command.isEmpty else { return false }
                let key = savedCommandKey(command: command, runtime: draft.runtime)
                guard !seen.contains(key) else { return false }
                seen.insert(key)
                return true
            }
        return Array(merged.prefix(24))
    }

    private static func isLegacySeedOrDiagnosticRun(_ run: CommandRun) -> Bool {
        let text = "\(run.title)\n\(run.command)".lowercased()
        let markers = [
            "veqral local command center ready",
            "veqral_ios_e2e_ok",
            "veqral_ws_ready",
            "veqral_persist_ready",
            "veqral_smoke_ok",
            "go-live",
            "reply pong only",
            "ping only.",
            "codex smoke",
            "delete /tmp/veqral_should_not_delete"
        ]
        return markers.contains { text.contains($0) }
    }

    private static func isLegacySeedApproval(_ approval: CommandApproval) -> Bool {
        let text = "\(approval.title)\n\(approval.detail)\n\(approval.command)".lowercased()
        return text.contains("jsontheftoken") ||
            text.contains("jwt_secret") ||
            text.contains("rails db:migrate") ||
            text.contains("veqral_should_not_delete")
    }

    private static func isLegacySeedLog(_ log: CommandLogEntry) -> Bool {
        let text = log.message.lowercased()
        return text.contains("veqral is ready") ||
            text.contains("safe read-only commands run immediately") ||
            text.contains("mutating, secret, production")
    }

    private static func sanitizedApprovals(_ approvals: [CommandApproval]) -> [CommandApproval] {
        let legacySeedCommands: Set<String> = [
            "rails db:migrate",
            "npm install jsontheftoken",
            "export JWT_SECRET=..."
        ]
        return approvals.filter { !legacySeedCommands.contains($0.command) }
    }

    private static func makePairingToken() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    private static func currentDeviceNameCandidates() -> Set<String> {
        var names = [ProcessInfo.processInfo.hostName]
        #if canImport(UIKit)
        names.append(UIDevice.current.name)
        #endif
        return Set(names.map(normalizedDeviceName).filter { !$0.isEmpty })
    }

    private static func normalizedDeviceName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func attachmentTimestamp() -> String {
        Self.attachmentDateFormatter.string(from: Date())
    }

    private static let attachmentDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static func urlEncoded(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func stableAgentProjectID(for path: String) -> String {
        SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func hydrateRemoteHost(_ configuration: RemoteHostConfiguration) -> RemoteHostConfiguration {
        guard configuration.token.isEmpty,
              !configuration.deviceID.isEmpty,
              let token = AppKeychainStore.get(account: remoteTokenAccount(deviceID: configuration.deviceID)) else {
            return configuration
        }
        var hydrated = configuration
        hydrated.token = token
        return hydrated
    }

    private static func remoteTokenAccount(deviceID: String) -> String {
        "remote-host:\(deviceID)"
    }
}

private struct CommandCenterSnapshot: Codable {
    var schemaVersion: Int?
    var runs: [CommandRun]
    var approvals: [CommandApproval]
    var logs: [CommandLogEntry]
    var diffs: [CommandDiffEntry]
    var selectedRunID: UUID?
    var selectedRuntime: CommandRuntime?
    var remoteHost: RemoteHostConfiguration?
    var remoteRunIDs: [String: String]?
    var workingDirectory: String
    var agentProjects: [AgentProjectSpace]?
    var selectedAgentProjectID: String?
    var selectedAgentChatID: String?
    var selectedHermesProvider: String?
    var selectedHermesModel: String?
    var appLanguage: AppLanguage?
    var sessionTitles: [String: String]?
    var archivedRunIDs: Set<UUID>?
    var savedCommandDrafts: [SavedCommandDraft]?
}

private enum SavedCommandDraftCache {
    private static let fileName = "saved-command-drafts.json"

    static func load(cacheFolder: URL) -> [SavedCommandDraft] {
        let urls = [ubiquityURL(), localURL(cacheFolder: cacheFolder)].compactMap { $0 }
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let drafts = try? JSONDecoder.commandCenter.decode([SavedCommandDraft].self, from: data),
                  !drafts.isEmpty else {
                continue
            }
            return drafts
        }
        return []
    }

    static func save(_ drafts: [SavedCommandDraft], cacheFolder: URL) {
        guard let data = try? JSONEncoder.commandCenter.encode(drafts) else { return }
        for url in [localURL(cacheFolder: cacheFolder), ubiquityURL()].compactMap({ $0 }) {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: url, options: .atomic)
        }
    }

    static func clearLocal(cacheFolder: URL) {
        try? FileManager.default.removeItem(at: localURL(cacheFolder: cacheFolder))
    }

    private static func localURL(cacheFolder: URL) -> URL {
        cacheFolder.appendingPathComponent(fileName)
    }

    private static func ubiquityURL() -> URL? {
        guard let root = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        return root
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Veqral", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}

struct LocalCommandResult: Sendable {
    struct Diff: Sendable {
        var path: String
        var additions: Int
        var deletions: Int
        var patch: String?
    }

    var exitCode: Int32
    var stdoutLines: [String]
    var stderrLines: [String]
    var diffEntries: [Diff]
}

enum LocalCommandExecutor {
    private static let commandTimeout: TimeInterval = 180
    private static let hermesTimeout: TimeInterval = 900
    private static let maxCapturedBytes = 512_000

    static func defaultRuntime() -> CommandRuntime {
        #if targetEnvironment(macCatalyst)
        hermesExecutablePath() == nil ? .localShell : .hermesAgent
        #else
        .hermesAgent
        #endif
    }

    static func run(command: String, workingDirectory: String) -> LocalCommandResult {
        #if targetEnvironment(macCatalyst)
        let output = runShell(command, workingDirectory: workingDirectory)
        let diffs = gitDiffEntries(workingDirectory: workingDirectory)
        return LocalCommandResult(
            exitCode: output.exitCode,
            stdoutLines: lines(from: output.stdout),
            stderrLines: lines(from: output.stderr),
            diffEntries: diffs
        )
        #else
        return LocalCommandResult(
            exitCode: 0,
            stdoutLines: ["Mac版またはMac Hostで実行できます。"],
            stderrLines: [],
            diffEntries: []
        )
        #endif
    }

    static func runHermes(prompt: String, workingDirectory: String) -> LocalCommandResult {
        #if targetEnvironment(macCatalyst)
        guard let hermesPath = hermesExecutablePath() else {
            return LocalCommandResult(
                exitCode: 127,
                stdoutLines: [],
                stderrLines: [
                    "Hermes Agent is not installed or not on a known path.",
                    "Install with: curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash"
                ],
                diffEntries: []
            )
        }

        let wrappedPrompt = """
        You are Hermes Agent running under Veqral, a personal Agent Command Center.
        Working directory: \(NSString(string: workingDirectory).expandingTildeInPath)

        Follow Veqral's safety policy:
        - Do not bypass Hermes approval gates.
        - Do not use --yolo.
        - Use checkpoints for file-changing work.
        - Be concise in the final response.

        User request:
        \(prompt)
        """
        let command = [
            shellQuoted(hermesPath),
            "chat",
            "-Q",
            "--source", "veqral",
            "--checkpoints",
            "--toolsets", "terminal,file,skills,memory,browser",
            "--max-turns", "40",
            "-q", shellQuoted(wrappedPrompt)
        ].joined(separator: " ")
        let output = runShell(command, workingDirectory: workingDirectory, timeout: hermesTimeout)
        let diffs = gitDiffEntries(workingDirectory: workingDirectory)
        return LocalCommandResult(
            exitCode: output.exitCode,
            stdoutLines: lines(from: stripANSI(output.stdout)),
            stderrLines: lines(from: stripANSI(output.stderr)),
            diffEntries: diffs
        )
        #else
        return LocalCommandResult(
            exitCode: 0,
            stdoutLines: ["Hermes runs from the Mac app or Mac Host connection."],
            stderrLines: [],
            diffEntries: []
        )
        #endif
    }

    static func inspectWorkspace(workingDirectory: String) -> WorkspaceSnapshot {
        #if targetEnvironment(macCatalyst)
        let expandedDirectory = NSString(string: workingDirectory).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedDirectory, isDirectory: &isDirectory), isDirectory.boolValue else {
            return WorkspaceSnapshot.unavailable(
                workingDirectory: expandedDirectory,
                message: "Working directory does not exist."
            )
        }

        let rootResult = runShell("git rev-parse --show-toplevel", workingDirectory: expandedDirectory, timeout: 15)
        let rootPath = firstLine(rootResult.stdout)
        let hostName = ProcessInfo.processInfo.hostName
        let hermes = inspectHermes(workingDirectory: expandedDirectory)

        guard rootResult.exitCode == 0, !rootPath.isEmpty else {
            return WorkspaceSnapshot(
                projectName: URL(fileURLWithPath: expandedDirectory).lastPathComponent,
                rootPath: "",
                workingDirectory: expandedDirectory,
                branch: "",
                remote: "",
                statusSummary: "Not a Git repository",
                changedFiles: 0,
                canRunLocalCommands: true,
                hermesPath: hermes.path,
                hermesVersion: hermes.version,
                deviceName: hostName,
                hostName: hostName,
                tailscaleIP: tailscaleIP(),
                refreshedAt: Date(),
                errorMessage: nil
            )
        }

        let branch = firstLine(runShell("git branch --show-current", workingDirectory: rootPath, timeout: 15).stdout)
        let remote = firstLine(runShell("git remote get-url origin", workingDirectory: rootPath, timeout: 15).stdout)
        let status = runShell("git status --porcelain", workingDirectory: rootPath, timeout: 15)
        let changedFiles = lines(from: status.stdout).count
        let statusSummary = changedFiles == 0 ? "Clean" : "\(changedFiles) changed files"
        let tailscaleAddress = tailscaleIP()

        return WorkspaceSnapshot(
            projectName: URL(fileURLWithPath: rootPath).lastPathComponent,
            rootPath: rootPath,
            workingDirectory: expandedDirectory,
            branch: branch,
            remote: remote,
            statusSummary: statusSummary,
            changedFiles: changedFiles,
            canRunLocalCommands: true,
            hermesPath: hermes.path,
            hermesVersion: hermes.version,
            deviceName: hostName,
            hostName: hostName,
            tailscaleIP: tailscaleAddress,
            refreshedAt: Date(),
            errorMessage: status.exitCode == 0 ? nil : firstLine(status.stderr)
        )
        #else
        return WorkspaceSnapshot.unavailable(
            workingDirectory: workingDirectory,
            message: "ローカルコマンド実行はMac版またはMac Host接続が必要です。"
        )
        #endif
    }

    #if targetEnvironment(macCatalyst)
    private static func inspectHermes(workingDirectory: String) -> (path: String, version: String) {
        guard let path = hermesExecutablePath() else {
            return ("", "Not installed")
        }
        let version = firstLine(runShell("\(shellQuoted(path)) --version", workingDirectory: workingDirectory, timeout: 20).stdout)
        return (path, version.isEmpty ? "Installed" : version)
    }

    private static func tailscaleIP() -> String {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let result = runShell("command -v tailscale >/dev/null 2>&1 && tailscale ip -4 | head -n 1", workingDirectory: home, timeout: 10)
        return firstLine(result.stdout)
    }

    private static func hermesExecutablePath() -> String? {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let candidates = [
            "\(home)/.local/bin/hermes",
            "\(home)/.hermes/hermes-agent/venv/bin/hermes",
            "/opt/homebrew/bin/hermes",
            "/usr/local/bin/hermes",
            "/usr/bin/hermes"
        ]
        if let candidate = candidates.first(where: executableExists(at:)) {
            return candidate
        }
        let command = "PATH=\(shellQuoted("\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin")) command -v hermes"
        let result = runShell(command, workingDirectory: home, timeout: 10)
        let discovered = firstLine(result.stdout)
        return executableExists(at: discovered) ? discovered : nil
    }

    private static func executableExists(at path: String) -> Bool {
        guard !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else {
            return false
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }
        return !isDirectory.boolValue
    }

    private static func runShell(_ command: String, workingDirectory: String, timeout: TimeInterval = commandTimeout) -> (exitCode: Int32, stdout: String, stderr: String) {
        let expandedDirectory = NSString(string: workingDirectory).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedDirectory, isDirectory: &isDirectory), isDirectory.boolValue else {
            return (66, "", "Working directory does not exist: \(expandedDirectory)")
        }

        let script = "cd \(shellQuoted(expandedDirectory)) && \(command)"

        var stdoutPipe = [Int32](repeating: 0, count: 2)
        var stderrPipe = [Int32](repeating: 0, count: 2)
        guard pipe(&stdoutPipe) == 0 else {
            return (127, "", "Failed to create stdout pipe.")
        }
        guard pipe(&stderrPipe) == 0 else {
            close(stdoutPipe[0])
            close(stdoutPipe[1])
            return (127, "", "Failed to create stderr pipe.")
        }

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        posix_spawn_file_actions_adddup2(&fileActions, stdoutPipe[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, stderrPipe[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, stdoutPipe[0])
        posix_spawn_file_actions_addclose(&fileActions, stderrPipe[0])

        let executable = "/bin/zsh"
        let argumentStrings: [String] = [executable, "-lc", script]
        var arguments: [UnsafeMutablePointer<CChar>?] = argumentStrings.map { strdup($0) }
        arguments.append(nil)

        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let environmentStrings: [String] = [
            "PATH=\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME=\(home)",
            "LANG=en_US.UTF-8"
        ]
        var environment: [UnsafeMutablePointer<CChar>?] = environmentStrings.map { strdup($0) }
        environment.append(nil)

        defer {
            for pointer in arguments where pointer != nil {
                free(pointer)
            }
            for pointer in environment where pointer != nil {
                free(pointer)
            }
            posix_spawn_file_actions_destroy(&fileActions)
        }

        var pid = pid_t()
        let spawnStatus = executable.withCString { executablePath in
            arguments.withUnsafeMutableBufferPointer { argumentBuffer in
                environment.withUnsafeMutableBufferPointer { environmentBuffer in
                    posix_spawn(
                        &pid,
                        executablePath,
                        &fileActions,
                        nil,
                        argumentBuffer.baseAddress,
                        environmentBuffer.baseAddress
                    )
                }
            }
        }

        guard spawnStatus == 0 else {
            close(stdoutPipe[0])
            close(stdoutPipe[1])
            close(stderrPipe[0])
            close(stderrPipe[1])
            return (127, "", "Failed to start zsh: \(spawnStatus)")
        }

        close(stdoutPipe[1])
        close(stderrPipe[1])
        setNonBlocking(stdoutPipe[0])
        setNonBlocking(stderrPipe[0])

        var stdoutData = Data()
        var stderrData = Data()
        let deadline = Date().addingTimeInterval(timeout)
        var waitStatus: Int32 = 0

        while true {
            readAvailable(from: stdoutPipe[0], into: &stdoutData)
            readAvailable(from: stderrPipe[0], into: &stderrData)

            let waitResult = waitpid(pid, &waitStatus, WNOHANG)
            if waitResult == pid {
                break
            }

            if Date() >= deadline {
                kill(pid, SIGTERM)
                usleep(200_000)
                if waitpid(pid, &waitStatus, WNOHANG) == 0 {
                    kill(pid, SIGKILL)
                    waitpid(pid, &waitStatus, 0)
                }
                readAvailable(from: stdoutPipe[0], into: &stdoutData)
                readAvailable(from: stderrPipe[0], into: &stderrData)
                close(stdoutPipe[0])
                close(stderrPipe[0])
                let stderr = text(from: stderrData) + "\nCommand timed out after \(Int(timeout)) seconds."
                return (124, text(from: stdoutData), stderr.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            if waitResult == -1 {
                break
            }

            usleep(50_000)
        }

        readAvailable(from: stdoutPipe[0], into: &stdoutData)
        readAvailable(from: stderrPipe[0], into: &stderrData)
        close(stdoutPipe[0])
        close(stderrPipe[0])

        return (exitCode(from: waitStatus), text(from: stdoutData), text(from: stderrData))
    }

    private static func gitDiffEntries(workingDirectory: String) -> [LocalCommandResult.Diff] {
        let result = runShell("git diff --numstat", workingDirectory: workingDirectory)
        guard result.exitCode == 0 else { return [] }
        return result.stdout
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> LocalCommandResult.Diff? in
                let parts = line.split(separator: "\t")
                guard parts.count >= 3,
                      let additions = Int(parts[0]),
                      let deletions = Int(parts[1]) else {
                    return nil
                }
                let path = String(parts[2])
                let patch = gitPatch(path: path, workingDirectory: workingDirectory)
                return LocalCommandResult.Diff(path: path, additions: additions, deletions: deletions, patch: patch)
            }
    }

    private static func gitPatch(path: String, workingDirectory: String) -> String? {
        let result = runShell("git diff -- \(shellQuoted(path))", workingDirectory: workingDirectory)
        guard result.exitCode == 0 else { return nil }
        let trimmed = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(40_000))
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func setNonBlocking(_ fileDescriptor: Int32) {
        let flags = fcntl(fileDescriptor, F_GETFL, 0)
        guard flags >= 0 else { return }
        _ = fcntl(fileDescriptor, F_SETFL, flags | O_NONBLOCK)
    }

    private static func readAvailable(from fileDescriptor: Int32, into data: inout Data) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let bufferSize = buffer.count
            let bytesRead = buffer.withUnsafeMutableBytes { rawBuffer in
                Darwin.read(fileDescriptor, rawBuffer.baseAddress, bufferSize)
            }
            if bytesRead > 0 {
                appendLimited(buffer.prefix(Int(bytesRead)), to: &data)
            } else if bytesRead == 0 || errno == EAGAIN || errno == EWOULDBLOCK {
                break
            } else {
                break
            }
        }
    }

    private static func appendLimited(_ bytes: ArraySlice<UInt8>, to data: inout Data) {
        let remaining = maxCapturedBytes - data.count
        guard remaining > 0 else { return }
        data.append(contentsOf: bytes.prefix(remaining))
    }

    private static func exitCode(from waitStatus: Int32) -> Int32 {
        let code = Int32((waitStatus >> 8) & 0xff)
        if code == 0, waitStatus != 0 {
            return 1
        }
        return code
    }
    #endif

    private static func lines(from text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map(String.init)
    }

    private static func firstLine(_ text: String) -> String {
        lines(from: text).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func text(from data: Data) -> String {
        String(data: data, encoding: .utf8) ?? ""
    }

    private static func stripANSI(_ text: String) -> String {
        let pattern = #"\u{001B}\[[0-9;?]*[ -/]*[@-~]"#
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
}

enum RemoteHostError: Error, LocalizedError {
    case invalidConfiguration
    case authentication(String)
    case approvalRequired(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "Remote Host is not configured."
        case .authentication(let message):
            message
        case .approvalRequired(let message):
            message
        case .server(let message):
            message
        }
    }
}

struct RemoteHostClient: Sendable {
    let configuration: RemoteHostConfiguration

    static func pair(endpoint: String, deviceName: String, pairingCode: String, pairingSignature: String? = nil) async throws -> RemotePairResponse {
        guard let url = URL(string: "/v1/pair", relativeTo: URL(string: endpoint)) else {
            throw RemoteHostError.invalidConfiguration
        }
        struct PairBody: Codable {
            var deviceName: String
            var pairingCode: String
            var pairingEndpoint: String
            var pairingSignature: String?
        }
        var request = URLRequest(url: url.absoluteURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.commandCenter.encode(PairBody(
            deviceName: deviceName,
            pairingCode: pairingCode,
            pairingEndpoint: endpoint,
            pairingSignature: pairingSignature
        ))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteHostError.server("Invalid response")
        }
        if [401, 403].contains(http.statusCode) {
            let message = (try? JSONDecoder.commandCenter.decode([String: String].self, from: data)["error"]) ?? "Unauthorized"
            throw RemoteHostError.authentication(message)
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder.commandCenter.decode([String: String].self, from: data)["error"]) ?? "HTTP \(http.statusCode)"
            throw RemoteHostError.server(message)
        }
        return try JSONDecoder.commandCenter.decode(RemotePairResponse.self, from: data)
    }

    func health() async throws -> RemoteHealthResponse {
        guard let url = URL(string: "/v1/health", relativeTo: URL(string: configuration.endpoint)) else {
            throw RemoteHostError.invalidConfiguration
        }
        let (data, response) = try await URLSession.shared.data(from: url.absoluteURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RemoteHostError.server("Health check failed")
        }
        return try JSONDecoder.commandCenter.decode(RemoteHealthResponse.self, from: data)
    }

    func telemetry() async throws -> RemoteHostTelemetry {
        let data = try await request(path: "/v1/telemetry", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteHostTelemetry.self, from: data)
    }

    func authOnboardingStatus() async throws -> RemoteAuthOnboardingStatus {
        let data = try await request(path: "/v1/auth/onboarding", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteAuthOnboardingStatus.self, from: data)
    }

    func refreshAuthOnboarding() async throws -> RemoteAuthOnboardingStatus {
        let data = try await request(path: "/v1/auth/onboarding/refresh", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteAuthOnboardingStatus.self, from: data)
    }

    func cleanupVoiceCommand(_ requestBody: RemoteVoiceCleanupRequest) async throws -> RemoteVoiceCleanupResponse {
        let body = try JSONEncoder.commandCenter.encode(requestBody)
        let data = try await request(path: "/v1/voice/cleanup", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteVoiceCleanupResponse.self, from: data)
    }

    func testDiscordNotification() async throws -> RemoteNotificationTestResponse {
        let data = try await request(path: "/v1/notifications/discord/test", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteNotificationTestResponse.self, from: data)
    }

    func createRun(
        prompt: String,
        workingDirectory: String,
        runtime: CommandRuntime,
        resumeSessionID: String?,
        projectID: String?,
        chatID: String?,
        provider: String?,
        model: String?,
        attachments: [CommandAttachment] = []
    ) async throws -> RemoteCreateRunResponse {
        struct Body: Encodable {
            var prompt: String
            var workingDirectory: String
            var engine: String?
            var resumeSessionID: String?
            var projectID: String?
            var chatID: String?
            var provider: String?
            var model: String?
            var attachments: [RemoteRunAttachment]
        }
        let body = try JSONEncoder.commandCenter.encode(Body(
            prompt: prompt,
            workingDirectory: workingDirectory,
            engine: runtime.remoteEngine,
            resumeSessionID: resumeSessionID,
            projectID: projectID,
            chatID: chatID,
            provider: provider == "auto" ? nil : provider,
            model: model?.nilIfBlank,
            attachments: attachments.map {
                RemoteRunAttachment(id: $0.id, fileName: $0.fileName, mimeType: $0.mimeType, data: $0.data)
            }
        ))
        let data = try await request(path: "/v1/runs", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteCreateRunResponse.self, from: data)
    }

    func runList() async throws -> RemoteRunListResponse {
        let data = try await request(path: "/v1/runs", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteRunListResponse.self, from: data)
    }

    func runSnapshot(remoteRunID: String) async throws -> RemoteRunSnapshotResponse {
        let data = try await request(path: "/v1/runs/\(remoteRunID)", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteRunSnapshotResponse.self, from: data)
    }

    func runLogs(remoteRunID: String) async throws -> RemoteRunLogResponse {
        let data = try await request(path: "/v1/runs/\(remoteRunID)/logs", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteRunLogResponse.self, from: data)
    }

    func runDiff(remoteRunID: String) async throws -> RemoteGitDiffResponse {
        let data = try await request(path: "/v1/runs/\(remoteRunID)/diff", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteGitDiffResponse.self, from: data)
    }

    func runArtifacts(remoteRunID: String) async throws -> RemoteArtifactListResponse {
        let data = try await request(path: "/v1/runs/\(remoteRunID)/artifacts", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteArtifactListResponse.self, from: data)
    }

    func artifactContent(remoteRunID: String, artifactID: String) async throws -> RemoteArtifactContentResponse {
        struct Body: Encodable {
            var artifactID: String
        }
        let body = try JSONEncoder.commandCenter.encode(Body(artifactID: artifactID))
        let data = try await request(path: "/v1/runs/\(remoteRunID)/artifact-content", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteArtifactContentResponse.self, from: data)
    }

    func cancel(remoteRunID: String) async throws {
        _ = try await request(path: "/v1/runs/\(remoteRunID)/cancel", method: "POST", body: Data())
    }

    func resume(remoteRunID: String) async throws {
        _ = try await request(path: "/v1/runs/\(remoteRunID)/resume", method: "POST", body: Data())
    }

    func approve(remoteRunID: String) async throws {
        _ = try await request(path: "/v1/runs/\(remoteRunID)/approve", method: "POST", body: Data())
    }

    func reject(remoteRunID: String) async throws {
        _ = try await request(path: "/v1/runs/\(remoteRunID)/reject", method: "POST", body: Data())
    }

    func hermesControlStatus() async throws -> HermesControlStatus {
        let data = try await request(path: "/v1/hermes/control", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(HermesControlStatus.self, from: data)
    }

    func updateHermesControl(_ update: HermesControlUpdate) async throws -> HermesControlUpdateResult {
        let body = try JSONEncoder.commandCenter.encode(update)
        let data = try await request(path: "/v1/hermes/control", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(HermesControlUpdateResult.self, from: data)
    }

    func hermesApprovals() async throws -> HermesApprovalList {
        let data = try await request(path: "/v1/hermes/approvals", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(HermesApprovalList.self, from: data)
    }

    func decideHermesApproval(id: String, decision: String, note: String?) async throws {
        struct Body: Encodable {
            var id: String
            var decision: String
            var note: String?
        }
        let body = try JSONEncoder.commandCenter.encode(Body(id: id, decision: decision, note: note))
        _ = try await request(path: "/v1/hermes/approvals/decide", method: "POST", body: body)
    }

    func devices() async throws -> RemoteDeviceListResponse {
        let data = try await request(path: "/v1/devices", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteDeviceListResponse.self, from: data)
    }

    func revokeDevice(deviceID: String) async throws {
        _ = try await request(path: "/v1/devices/\(deviceID)/revoke", method: "POST", body: Data())
    }

    func audit() async throws -> RemoteAuditLogResponse {
        let data = try await request(path: "/v1/audit", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteAuditLogResponse.self, from: data)
    }

    func githubStatus(workingDirectory: String) async throws -> RemoteGitHubStatus {
        let body = try JSONEncoder.commandCenter.encode(["workingDirectory": workingDirectory])
        let data = try await request(path: "/v1/github/status", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteGitHubStatus.self, from: data)
    }

    func createDraftPR(workingDirectory: String, title: String, body: String) async throws -> RemoteDraftPRResponse {
        let bodyData = try JSONEncoder.commandCenter.encode([
            "workingDirectory": workingDirectory,
            "title": title,
            "body": body
        ])
        let data = try await request(path: "/v1/github/draft-pr", method: "POST", body: bodyData)
        return try JSONDecoder.commandCenter.decode(RemoteDraftPRResponse.self, from: data)
    }

    func costBudgets() async throws -> RemoteProjectBudgetListResponse {
        let data = try await request(path: "/v1/budgets", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteProjectBudgetListResponse.self, from: data)
    }

    func updateCostBudget(_ requestBody: RemoteProjectBudgetUpdateRequest) async throws -> RemoteProjectCostSummary {
        let body = try JSONEncoder.commandCenter.encode(requestBody)
        let data = try await request(path: "/v1/budgets", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteProjectCostSummary.self, from: data)
    }

    func registerPushToken(deviceToken: String, environment: String, bundleID: String, locale: String) async throws -> RemotePushTokenResponse {
        struct Body: Encodable {
            var deviceToken: String
            var environment: String
            var bundleID: String
            var locale: String
        }
        let body = try JSONEncoder.commandCenter.encode(Body(
            deviceToken: deviceToken,
            environment: environment,
            bundleID: bundleID,
            locale: locale
        ))
        let data = try await request(path: "/v1/push/token", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemotePushTokenResponse.self, from: data)
    }

    func portfolioAssets() async throws -> RemotePortfolioAssetListResponse {
        let data = try await request(path: "/v1/portfolio/assets", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemotePortfolioAssetListResponse.self, from: data)
    }

    func discoverPortfolio() async throws -> RemotePortfolioAssetListResponse {
        struct Body: Encodable {
            var engagementRoots: [String]?
            var codeRoots: [String]?
            var includeGitHub: Bool?
        }
        let body = try JSONEncoder.commandCenter.encode(Body(engagementRoots: nil, codeRoots: nil, includeGitHub: nil))
        let data = try await request(path: "/v1/portfolio/discover", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemotePortfolioAssetListResponse.self, from: data)
    }

    func savePortfolioAsset(_ asset: PortfolioAsset) async throws -> PortfolioAsset {
        struct Body: Encodable {
            var asset: PortfolioAsset
        }
        let body = try JSONEncoder.commandCenter.encode(Body(asset: asset))
        let method = asset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "POST" : "PATCH"
        let path = method == "POST" ? "/v1/portfolio/assets" : "/v1/portfolio/assets/\(asset.id)"
        let data = try await request(path: path, method: method, body: body)
        return try JSONDecoder.commandCenter.decode(PortfolioAsset.self, from: data)
    }

    func portfolioStatus(assetID: String) async throws -> RemotePortfolioStatusResponse {
        let data = try await request(path: "/v1/portfolio/assets/\(assetID)/status", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemotePortfolioStatusResponse.self, from: data)
    }

    func portfolioLogs(assetID: String) async throws -> RemotePortfolioLogsResponse {
        let data = try await request(path: "/v1/portfolio/assets/\(assetID)/logs", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemotePortfolioLogsResponse.self, from: data)
    }

    func portfolioLogSummary(assetID: String) async throws -> RemotePortfolioSummaryResponse {
        let data = try await request(path: "/v1/portfolio/assets/\(assetID)/log-summary", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemotePortfolioSummaryResponse.self, from: data)
    }

    func portfolioCommits(assetID: String) async throws -> RemotePortfolioCommitsResponse {
        let data = try await request(path: "/v1/portfolio/assets/\(assetID)/commits", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemotePortfolioCommitsResponse.self, from: data)
    }

    func portfolioControl(assetID: String, action: String) async throws -> RemotePortfolioControlResponse {
        let body = try JSONEncoder.commandCenter.encode(["action": action])
        let data = try await request(path: "/v1/portfolio/assets/\(assetID)/control", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemotePortfolioControlResponse.self, from: data)
    }

    func portfolioPromote(assetID: String) async throws -> RemotePortfolioPromoteResponse {
        let data = try await request(path: "/v1/portfolio/assets/\(assetID)/promote", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(RemotePortfolioPromoteResponse.self, from: data)
    }

    func salesLeads() async throws -> RemoteSalesLeadListResponse {
        let data = try await request(path: "/v1/sales/leads", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteSalesLeadListResponse.self, from: data)
    }

    func saveSalesLead(_ lead: SalesLead) async throws -> SalesLead {
        struct Body: Encodable {
            var lead: SalesLead
        }
        let body = try JSONEncoder.commandCenter.encode(Body(lead: lead))
        let data = try await request(path: "/v1/sales/leads/\(lead.id)", method: "PATCH", body: body)
        return try JSONDecoder.commandCenter.decode(SalesLead.self, from: data)
    }

    func importSalesCSV(_ csv: String) async throws -> RemoteSalesCSVImportResponse {
        let body = try JSONEncoder.commandCenter.encode(["csv": csv])
        let data = try await request(path: "/v1/sales/leads/import-csv", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteSalesCSVImportResponse.self, from: data)
    }

    func auditSalesLead(id: String) async throws -> WebsiteAudit {
        let data = try await request(path: "/v1/sales/leads/\(id)/audit", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(WebsiteAudit.self, from: data)
    }

    func generateSalesRedesign(id: String) async throws -> RedesignMock {
        let data = try await request(path: "/v1/sales/leads/\(id)/generate-mock", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(RedesignMock.self, from: data)
    }

    func generateSalesProposal(id: String) async throws -> Proposal {
        let data = try await request(path: "/v1/sales/leads/\(id)/generate-proposal", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(Proposal.self, from: data)
    }

    func approveSalesProposal(id: String) async throws -> Proposal {
        let data = try await request(path: "/v1/sales/leads/\(id)/approve-proposal", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(Proposal.self, from: data)
    }

    func markSalesLeadContacted(id: String, channel: String, note: String?) async throws -> SalesLead {
        struct Body: Encodable {
            var channel: String
            var note: String?
        }
        let body = try JSONEncoder.commandCenter.encode(Body(channel: channel, note: note))
        let data = try await request(path: "/v1/sales/leads/\(id)/mark-contacted", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(SalesLead.self, from: data)
    }

    func salesLeadAssets(id: String) async throws -> RemoteSalesLeadAssetsResponse {
        let data = try await request(path: "/v1/sales/leads/\(id)/assets", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteSalesLeadAssetsResponse.self, from: data)
    }

    func promoteSalesLeadToPortfolio(id: String) async throws -> RemoteSalesPortfolioPromotionResponse {
        let data = try await request(path: "/v1/sales/leads/\(id)/promote-to-portfolio", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteSalesPortfolioPromotionResponse.self, from: data)
    }

    func createSalesHermesHandoff(id: String) async throws -> RemoteSalesHermesHandoffResponse {
        let data = try await request(path: "/v1/sales/leads/\(id)/create-hermes-handoff", method: "POST", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteSalesHermesHandoffResponse.self, from: data)
    }

    func memoryList() async throws -> RemoteMemoryListResponse {
        let data = try await request(path: "/v1/memory", method: "GET", body: Data())
        return try JSONDecoder.commandCenter.decode(RemoteMemoryListResponse.self, from: data)
    }

    func readMemory(id: String) async throws -> RemoteMemoryContentResponse {
        let body = try JSONEncoder.commandCenter.encode(["id": id])
        let data = try await request(path: "/v1/memory/read", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteMemoryContentResponse.self, from: data)
    }

    func projectMemory(_ requestBody: RemoteProjectMemoryRequest) async throws -> RemoteProjectMemoryResponse {
        let body = try JSONEncoder.commandCenter.encode(requestBody)
        let data = try await request(path: "/v1/memory/project", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteProjectMemoryResponse.self, from: data)
    }

    func diffMemory(id: String, content: String) async throws -> RemoteMemoryDiffResponse {
        let body = try JSONEncoder.commandCenter.encode(["id": id, "content": content])
        let data = try await request(path: "/v1/memory/diff", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteMemoryDiffResponse.self, from: data)
    }

    func writeMemory(id: String, content: String) async throws -> RemoteMemoryWriteResponse {
        let body = try JSONEncoder.commandCenter.encode(["id": id, "content": content])
        let data = try await request(path: "/v1/memory/write", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteMemoryWriteResponse.self, from: data)
    }

    func historySessions(
        tool: RemoteHistoryTool?,
        project: String?,
        query: String?,
        date: String?,
        page: Int,
        limit: Int
    ) async throws -> RemoteHistoryListResponse {
        struct Body: Encodable {
            var tool: RemoteHistoryTool?
            var project: String?
            var query: String?
            var date: String?
            var page: Int?
            var limit: Int?
        }
        let body = try JSONEncoder.commandCenter.encode(Body(
            tool: tool,
            project: project?.isEmpty == true ? nil : project,
            query: query?.isEmpty == true ? nil : query,
            date: date?.isEmpty == true ? nil : date,
            page: page,
            limit: limit
        ))
        let data = try await request(path: "/v1/history/sessions", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteHistoryListResponse.self, from: data)
    }

    func historyDetail(id: String, tool: RemoteHistoryTool) async throws -> RemoteHistoryDetailResponse {
        struct Body: Encodable {
            var id: String
            var tool: RemoteHistoryTool
        }
        let body = try JSONEncoder.commandCenter.encode(Body(id: id, tool: tool))
        let data = try await request(path: "/v1/history/session", method: "POST", body: body)
        return try JSONDecoder.commandCenter.decode(RemoteHistoryDetailResponse.self, from: data)
    }

    func stream(remoteRunID: String) -> AsyncThrowingStream<RemoteHostLogEvent, Error> {
        AsyncThrowingStream { continuation in
            guard let baseURL = URL(string: configuration.endpoint) else {
                continuation.finish(throwing: RemoteHostError.invalidConfiguration)
                return
            }
            let path = "/v1/runs/\(remoteRunID)/events"
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
            components?.path = path
            guard let url = components?.url else {
                continuation.finish(throwing: RemoteHostError.invalidConfiguration)
                return
            }
            var request = URLRequest(url: url)
            sign(&request, method: "GET", path: path, body: Data())
            let task = URLSession.shared.webSocketTask(with: request)
            task.resume()

            let receiveTask = Task {
                do {
                    while !Task.isCancelled {
                        let message = try await task.receive()
                        let data: Data
                        switch message {
                        case .data(let payload):
                            data = payload
                        case .string(let text):
                            data = Data(text.utf8)
                        @unknown default:
                            continue
                        }
                        let event = try JSONDecoder.commandCenter.decode(RemoteHostLogEvent.self, from: data)
                        continuation.yield(event)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                receiveTask.cancel()
                task.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    private func request(path: String, method: String, body: Data) async throws -> Data {
        guard let url = URL(string: path, relativeTo: URL(string: configuration.endpoint)) else {
            throw RemoteHostError.invalidConfiguration
        }
        var request = URLRequest(url: url.absoluteURL)
        request.httpMethod = method
        request.httpBody = body.isEmpty ? nil : body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        sign(&request, method: method, path: path, body: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteHostError.server("Invalid response")
        }
        if http.statusCode == 409 {
            let message = (try? JSONDecoder.commandCenter.decode([String: String].self, from: data)["error"]) ?? "Remote approval required"
            throw RemoteHostError.approvalRequired(message)
        }
        if [401, 403].contains(http.statusCode) {
            let message = (try? JSONDecoder.commandCenter.decode([String: String].self, from: data)["error"]) ?? "Unauthorized"
            throw RemoteHostError.authentication(message)
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder.commandCenter.decode([String: String].self, from: data)["error"]) ?? "HTTP \(http.statusCode)"
            throw RemoteHostError.server(message)
        }
        return data
    }

    private func sign(_ request: inout URLRequest, method: String, path: String, body: Data) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        request.setValue(configuration.deviceID, forHTTPHeaderField: "X-Veqral-Device")
        request.setValue(timestamp, forHTTPHeaderField: "X-Veqral-Timestamp")
        request.setValue(
            RemoteHostSigner.signature(
                token: configuration.token,
                method: method,
                path: path,
                timestamp: timestamp,
                body: body
            ),
            forHTTPHeaderField: "X-Veqral-Signature"
        )
    }
}

enum RemoteHostSigner {
    static func signature(token: String, method: String, path: String, timestamp: String, body: Data) -> String {
        let bodyHash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        let canonical = "\(method)\n\(path)\n\(timestamp)\n\(bodyHash)"
        let key = SymmetricKey(data: Data(token.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(canonical.utf8), using: key)
        return Data(signature).base64EncodedString()
    }
}

enum AppKeychainStore {
    private static let service = "dev.hiroyuki.veqral.app"

    static func set(_ value: String, account: String) throws {
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8)
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw RemoteHostError.server("Keychain write failed: \(status)")
        }
    }

    static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

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

extension CommandCenterStore {
    static let hermesReasoningLevels = ["none", "minimal", "low", "medium", "high", "xhigh"]

    private var hermesClient: RemoteHostClient {
        get throws {
            guard remoteHost.isEnabled else {
                throw RemoteHostError.invalidConfiguration
            }
            return RemoteHostClient(configuration: remoteHost)
        }
    }

    func hermesControlStatus() async throws -> HermesControlStatus {
        try await hermesClient.hermesControlStatus()
    }

    func updateHermesControl(_ update: HermesControlUpdate) async throws -> HermesControlUpdateResult {
        try await hermesClient.updateHermesControl(update)
    }

    func hermesApprovals() async throws -> [HermesApprovalItem] {
        try await hermesClient.hermesApprovals().approvals
    }

    func decideHermesApproval(_ approval: HermesApprovalItem, decision: String, note: String? = nil) async throws {
        try await hermesClient.decideHermesApproval(id: approval.id, decision: decision, note: note)
    }
}
