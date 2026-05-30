import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case home
    case chat
    case requirements
    case projects
    case devices
    case agents
    case runs
    case terminal
    case diff
    case artifacts
    case approvals
    case memory
    case github

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Command"
        case .chat: "Intent"
        case .requirements: "Requirements"
        case .projects: "Projects"
        case .devices: "Devices"
        case .agents: "Agents"
        case .runs: "Runs"
        case .terminal: "Terminal"
        case .diff: "Diff"
        case .artifacts: "Artifacts"
        case .approvals: "承認"
        case .memory: "Memory"
        case .github: "GitHub"
        }
    }

    var symbol: String {
        switch self {
        case .home: "command"
        case .chat: "text.bubble"
        case .requirements: "checklist"
        case .projects: "folder"
        case .devices: "macbook.and.iphone"
        case .agents: "person.3.sequence"
        case .runs: "play.rectangle.on.rectangle"
        case .terminal: "terminal"
        case .diff: "plus.forwardslash.minus"
        case .artifacts: "shippingbox"
        case .approvals: "hand.raised"
        case .memory: "brain.head.profile"
        case .github: "point.3.connected.trianglepath.dotted"
        }
    }

    static let primaryTabs: [AppSection] = [.home, .approvals, .projects, .devices]
    static let commandGroup: [AppSection] = [.home, .chat, .requirements]
    static let operationGroup: [AppSection] = [.projects, .agents, .runs, .terminal, .diff, .artifacts]
    static let systemGroup: [AppSection] = [.devices, .approvals, .memory, .github]
    static let compactMore: [AppSection] = allCases.filter { !primaryTabs.contains($0) }
}

enum RunPhase: String, CaseIterable, Identifiable, Codable {
    case requirements
    case implementation
    case testing
    case github
    case deploy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .requirements: "Requirements"
        case .implementation: "Implementation"
        case .testing: "Testing"
        case .github: "GitHub"
        case .deploy: "Deploy"
        }
    }
}

enum RunStatus: String, Codable {
    case running
    case waiting
    case complete
    case failed
    case approval

    var title: String {
        switch self {
        case .running: "実行中"
        case .waiting: "Waiting"
        case .complete: "Complete"
        case .failed: "Failed"
        case .approval: "承認待ち"
        }
    }

    var tint: Color {
        switch self {
        case .running: VQTheme.accent
        case .waiting: VQTheme.amber
        case .complete: VQTheme.green
        case .failed: VQTheme.red
        case .approval: VQTheme.ink
        }
    }
}

enum DeviceStatus: String {
    case online
    case idle
    case offline

    var title: String {
        switch self {
        case .online: "Online"
        case .idle: "Idle"
        case .offline: "Offline"
        }
    }

    var tint: Color {
        switch self {
        case .online: VQTheme.green
        case .idle: VQTheme.amber
        case .offline: VQTheme.secondaryText
        }
    }
}

enum RequirementState: String {
    case decided
    case open
    case review

    var title: String {
        switch self {
        case .decided: "Decided"
        case .open: "Open"
        case .review: "Review"
        }
    }

    var tint: Color {
        switch self {
        case .decided: VQTheme.green
        case .open: VQTheme.amber
        case .review: VQTheme.accent
        }
    }
}

enum RiskType: String {
    case deletion
    case billing
    case production
    case secret
    case screen

    var title: String {
        switch self {
        case .deletion: "File deletion"
        case .billing: "Billing"
        case .production: "Production"
        case .secret: "Secrets"
        case .screen: "Screen control"
        }
    }

    var symbol: String {
        switch self {
        case .deletion: "trash"
        case .billing: "creditcard"
        case .production: "server.rack"
        case .secret: "key"
        case .screen: "cursorarrow.motionlines"
        }
    }
}

enum MemoryScope: String, CaseIterable, Identifiable {
    case user
    case project
    case decision
    case agent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .user: "User"
        case .project: "Project"
        case .decision: "Decision"
        case .agent: "Agent"
        }
    }
}

struct CommandMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color
}

struct Device: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let hostName: String
    let tailscaleIP: String
    let status: DeviceStatus
    let workload: Double
    let battery: String?
    let capabilities: [String]
    let activeRun: String
}

struct ProjectItem: Identifiable {
    let id = UUID()
    let name: String
    let repo: String
    let localPath: String
    let status: String
    let memoryCount: Int
    let activeRuns: Int
    let team: [String]
}

struct AgentProfile: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let model: String
    let device: String
    let status: RunStatus
    let permissions: [String]
}

struct AgentRun: Identifiable {
    let id = UUID()
    let title: String
    let phase: RunPhase
    let status: RunStatus
    let agent: String
    let device: String
    let model: String
    let progress: Double
    let started: String
}

struct RequirementSection: Identifiable {
    let id = UUID()
    let title: String
    let state: RequirementState
    let bullets: [String]
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let speaker: String
    let text: String
    let isUser: Bool
}

struct ApprovalRequest: Identifiable {
    let id = UUID()
    let summary: String
    let reason: String
    let action: String
    let affectedTarget: String
    let riskType: RiskType
    let requestedBy: String
}

struct ArtifactItem: Identifiable {
    let id = UUID()
    let title: String
    let type: String
    let source: String
    let status: String
    let symbol: String
}

struct MemoryEntry: Identifiable {
    let id = UUID()
    let scope: MemoryScope
    let content: String
    let source: String
    let confidence: String
    let pinned: Bool
}

struct DiffFile: Identifiable {
    let id = UUID()
    let path: String
    let additions: Int
    let deletions: Int
    let summary: String
}

struct LogLine: Identifiable {
    let id = UUID()
    let time: String
    let stream: String
    let message: String
}
