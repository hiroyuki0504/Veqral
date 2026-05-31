import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case home
    case chat
    case requirements
    case projects
    case devices
    case agents
    case models
    case runs
    case terminal
    case diff
    case artifacts
    case history
    case approvals
    case memory
    case github

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: L10n.tr("Command")
        case .chat: L10n.tr("Intent")
        case .requirements: L10n.tr("Requirements")
        case .projects: L10n.tr("Projects")
        case .devices: L10n.tr("Devices")
        case .agents: L10n.tr("Agents")
        case .models: L10n.tr("Models")
        case .runs: L10n.tr("Runs")
        case .terminal: L10n.tr("Terminal")
        case .diff: L10n.tr("Diff")
        case .artifacts: L10n.tr("Artifacts")
        case .history: L10n.tr("History")
        case .approvals: L10n.tr("Approvals")
        case .memory: L10n.tr("Memory")
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
        case .models: "cpu"
        case .runs: "play.rectangle.on.rectangle"
        case .terminal: "terminal"
        case .diff: "plus.forwardslash.minus"
        case .artifacts: "shippingbox"
        case .history: "clock.arrow.circlepath"
        case .approvals: "hand.raised"
        case .memory: "brain.head.profile"
        case .github: "point.3.connected.trianglepath.dotted"
        }
    }

    static let primaryTabs: [AppSection] = [.home, .approvals, .projects, .devices]
    static let commandGroup: [AppSection] = [.home, .chat, .requirements]
    static let operationGroup: [AppSection] = [.projects, .agents, .models, .runs, .terminal, .diff, .artifacts, .history]
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
        case .requirements: L10n.tr("Requirements")
        case .implementation: L10n.tr("Implementation")
        case .testing: L10n.tr("Testing")
        case .github: "GitHub"
        case .deploy: L10n.tr("Deploy")
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
        case .running: L10n.tr("Running")
        case .waiting: L10n.tr("Waiting")
        case .complete: L10n.tr("Complete")
        case .failed: L10n.tr("Failed")
        case .approval: L10n.tr("Approval")
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
        case .online: L10n.tr("Online")
        case .idle: L10n.tr("Idle")
        case .offline: L10n.tr("Offline")
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

enum MemoryScope: String, CaseIterable, Identifiable {
    case user
    case project
    case decision
    case agent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .user: L10n.tr("User")
        case .project: L10n.tr("Project")
        case .decision: L10n.tr("Decision")
        case .agent: L10n.tr("Agent")
        }
    }
}

enum ContextPackage {
    static let items = [
        "User Profile",
        "Project Memory",
        "Requirements",
        "Decision Log",
        "Current Task",
        "Repo Summary",
        "Relevant Files",
        "Coding Conventions",
        "Security Policy",
        "Approval Policy",
        "Available Tools",
        "Device Capabilities",
        "Output Contract"
    ]
}
