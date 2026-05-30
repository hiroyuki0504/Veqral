import SwiftUI

enum MockData {
    static let metrics: [CommandMetric] = [
        CommandMetric(title: "Active runs", value: "4", detail: "2 running, 1 waiting", symbol: "play.circle", tint: VQTheme.accent),
        CommandMetric(title: "Approvals", value: "3", detail: "Deletion, deploy, screen", symbol: "hand.raised", tint: VQTheme.amber),
        CommandMetric(title: "Online Macs", value: "2", detail: "Tailscale reachable", symbol: "macbook.and.iphone", tint: VQTheme.green),
        CommandMetric(title: "Memory", value: "126", detail: "14 pinned decisions", symbol: "brain.head.profile", tint: VQTheme.ink)
    ]

    static let devices: [Device] = [
        Device(
            name: "Hiroyuki MacBook Pro",
            type: "MacBook Pro 16",
            hostName: "mbp-veqral",
            tailscaleIP: "100.92.14.22",
            status: .online,
            workload: 0.68,
            battery: "82%",
            capabilities: ["Hermes", "Codex", "Claude Code", "Browser", "GitHub"],
            activeRun: "SwiftUI command prototype"
        ),
        Device(
            name: "Studio Mac mini",
            type: "Mac mini",
            hostName: "mini-agent-host",
            tailscaleIP: "100.77.3.91",
            status: .idle,
            workload: 0.18,
            battery: nil,
            capabilities: ["Hermes", "Codex", "Docker", "Playwright", "CI tools"],
            activeRun: "Ready"
        ),
        Device(
            name: "Travel MacBook Air",
            type: "MacBook Air",
            hostName: "air-field",
            tailscaleIP: "100.41.9.12",
            status: .offline,
            workload: 0.0,
            battery: nil,
            capabilities: ["Codex", "Git"],
            activeRun: "Last seen yesterday"
        )
    ]

    static let projects: [ProjectItem] = [
        ProjectItem(
            name: "Veqral",
            repo: "github.com/hiroyuki/veqral",
            localPath: "~/Documents/Veqral",
            status: "MVP 0 design",
            memoryCount: 42,
            activeRuns: 2,
            team: ["PM", "Implementer", "Reviewer", "Tester"]
        ),
        ProjectItem(
            name: "Hermes Host Lab",
            repo: "github.com/hiroyuki/agent-host-lab",
            localPath: "~/Developer/AgentHost",
            status: "Pairing spike",
            memoryCount: 19,
            activeRuns: 1,
            team: ["Architect", "Implementer"]
        )
    ]

    static let agents: [AgentProfile] = [
        AgentProfile(name: "Northstar", role: "PM / Context Manager", model: "Claude Opus profile", device: "MacBook Pro", status: .running, permissions: ["Memory write", "Requirements", "Approvals"]),
        AgentProfile(name: "Forge", role: "Implementer", model: "Codex profile", device: "MacBook Pro", status: .running, permissions: ["Repo write", "Tests", "Artifacts"]),
        AgentProfile(name: "Lens", role: "Reviewer", model: "Claude Code profile", device: "Mac mini", status: .waiting, permissions: ["Read repo", "Diff review"]),
        AgentProfile(name: "Probe", role: "Tester", model: "Codex test profile", device: "Mac mini", status: .complete, permissions: ["Tests", "Browser", "Screenshots"]),
        AgentProfile(name: "Signal", role: "Researcher", model: "Web research profile", device: "MacBook Pro", status: .waiting, permissions: ["Web", "Docs", "Memory candidates"])
    ]

    static let modelProfiles: [ModelProfile] = [
        ModelProfile(
            role: "PM / Manager",
            provider: "Anthropic",
            modelName: "Claude Opus profile",
            costLevel: "High",
            speedLevel: "Medium",
            reasoningLevel: "Very high",
            toolSupport: ["Requirements", "Memory write", "Delegation"],
            contextPolicy: "May write canonical memory after user approval.",
            assignedDevice: "MacBook Pro"
        ),
        ModelProfile(
            role: "Architect",
            provider: "OpenAI / Anthropic",
            modelName: "Reasoning architect profile",
            costLevel: "High",
            speedLevel: "Medium",
            reasoningLevel: "High",
            toolSupport: ["Repo read", "Design review", "Decision log"],
            contextPolicy: "Reads full context package and writes decision candidates.",
            assignedDevice: "MacBook Pro"
        ),
        ModelProfile(
            role: "Implementer",
            provider: "OpenAI Codex",
            modelName: "Codex implementation profile",
            costLevel: "Medium",
            speedLevel: "High",
            reasoningLevel: "High",
            toolSupport: ["Terminal", "File edits", "Tests"],
            contextPolicy: "Reads shared context and returns diffs, logs, and memory candidates.",
            assignedDevice: "MacBook Pro"
        ),
        ModelProfile(
            role: "Reviewer",
            provider: "Claude Code",
            modelName: "Code review profile",
            costLevel: "Medium",
            speedLevel: "Medium",
            reasoningLevel: "High",
            toolSupport: ["Diff review", "Security policy", "GitHub"],
            contextPolicy: "Reads repo summary and output contract; cannot write memory directly.",
            assignedDevice: "Mac mini"
        ),
        ModelProfile(
            role: "Tester",
            provider: "OpenAI Codex",
            modelName: "Test runner profile",
            costLevel: "Low",
            speedLevel: "High",
            reasoningLevel: "Medium",
            toolSupport: ["Terminal", "Simulator", "Artifacts"],
            contextPolicy: "Reads task, repo, and device capabilities; reports test artifacts.",
            assignedDevice: "Mac mini"
        ),
        ModelProfile(
            role: "Researcher",
            provider: "Web-capable model",
            modelName: "Research profile",
            costLevel: "Medium",
            speedLevel: "Medium",
            reasoningLevel: "Medium",
            toolSupport: ["Browser", "Docs", "Session search"],
            contextPolicy: "Writes source-backed notes as memory candidates only.",
            assignedDevice: "MacBook Pro"
        )
    ]

    static let runs: [AgentRun] = [
        AgentRun(title: "Shape MVP 0 SwiftUI prototype", phase: .implementation, status: .running, agent: "Forge", device: "MacBook Pro", model: "Codex profile", progress: 0.72, started: "13:48"),
        AgentRun(title: "Extract product requirements from handoff", phase: .requirements, status: .complete, agent: "Northstar", device: "MacBook Pro", model: "Claude Opus profile", progress: 1.0, started: "13:33"),
        AgentRun(title: "Validate iPad three-pane navigation", phase: .testing, status: .waiting, agent: "Probe", device: "Mac mini", model: "Codex test profile", progress: 0.35, started: "Queued"),
        AgentRun(title: "Prepare first draft PR", phase: .github, status: .approval, agent: "Release", device: "MacBook Pro", model: "GitHub profile", progress: 0.48, started: "Paused"),
        AgentRun(title: "Deploy preview build", phase: .deploy, status: .approval, agent: "Release", device: "Mac mini", model: "Release profile", progress: 0.12, started: "Paused")
    ]

    static let requirements: [RequirementSection] = [
        RequirementSection(title: "Core Experience", state: .decided, bullets: [
            "Capture intent from iPhone or iPad and turn it into requirements.",
            "Keep project memory, user memory, and decision logs visible and editable.",
            "Show logs, diffs, artifacts, previews, and approvals in one command surface."
        ]),
        RequirementSection(title: "Device Host", state: .decided, bullets: [
            "Pair Macs through a menu bar Agent Host and QR code.",
            "Use Tailscale as the first networking assumption.",
            "Stream PTY logs, git diffs, screenshots, and artifacts back to iOS."
        ]),
        RequirementSection(title: "Agent Organization", state: .review, bullets: [
            "Start with a single worker, then add PM, reviewer, tester, researcher, and release roles.",
            "Allow a model profile per role while sharing one context package.",
            "Restrict formal memory writes to the manager until approval rules mature."
        ]),
        RequirementSection(title: "Approval Policy", state: .decided, bullets: [
            "Require approval for file deletion, billing, production, secrets, and screen control.",
            "Log every risky operation with reason, affected target, and command.",
            "Support approve, reject, and ask follow-up actions."
        ]),
        RequirementSection(title: "Open Questions", state: .open, bullets: [
            "Choose the first Mac Host transport protocol: WebSocket or gRPC streaming.",
            "Decide whether MVP storage should use SwiftData or SQLite directly.",
            "Define the first Hermes session launch contract."
        ])
    ]

    static let chat: [ChatMessage] = [
        ChatMessage(speaker: "Hiroyuki", text: "I want to control my MacBook Pro and Mac mini agents from iPhone while I am outside.", isUser: true),
        ChatMessage(speaker: "Northstar", text: "I have a command-center shape: intent capture, requirements, runs, devices, approvals, memory, and artifacts.", isUser: false),
        ChatMessage(speaker: "Hiroyuki", text: "It should not feel like SSH. I want the agent organization and approvals to be visible.", isUser: true),
        ChatMessage(speaker: "Northstar", text: "Decision captured: the first build is a full UI prototype with realistic mock data and all major entry points.", isUser: false)
    ]

    static let approvals: [ApprovalRequest] = [
        ApprovalRequest(summary: "Remove stale generated build folder", reason: "The tester needs a clean simulator build before screenshot verification.", action: "rm -rf build/DerivedPrototype", affectedTarget: "~/Documents/Veqral/build/DerivedPrototype", riskType: .deletion, requestedBy: "Probe"),
        ApprovalRequest(summary: "Open browser and control preview", reason: "The frontend specialist wants to inspect responsive behavior in a real browser.", action: "Computer Use: launch preview and capture screenshots", affectedTarget: "Local simulator and preview browser", riskType: .screen, requestedBy: "Forge"),
        ApprovalRequest(summary: "Deploy staging host update", reason: "The release agent prepared a signed Mac Host staging build.", action: "deploy --env staging --host mini-agent-host", affectedTarget: "Staging Agent Host", riskType: .production, requestedBy: "Release")
    ]

    static let artifacts: [ArtifactItem] = [
        ArtifactItem(title: "iPhone command screen", type: "Screenshot", source: "Probe", status: "Ready", symbol: "iphone"),
        ArtifactItem(title: "iPad three-pane layout", type: "Screenshot", source: "Probe", status: "Queued", symbol: "ipad"),
        ArtifactItem(title: "Requirements draft", type: "Document", source: "Northstar", status: "Ready", symbol: "doc.text"),
        ArtifactItem(title: "Test report", type: "Test result", source: "Probe", status: "Waiting", symbol: "checkmark.seal"),
        ArtifactItem(title: "Preview build", type: "Web preview", source: "Forge", status: "Draft", symbol: "safari")
    ]

    static let memory: [MemoryEntry] = [
        MemoryEntry(scope: .user, content: "Prefers step-by-step automation over full autonomy from day one.", source: "Intent capture", confidence: "High", pinned: true),
        MemoryEntry(scope: .project, content: "Tailscale can be assumed for the personal MVP network layer.", source: "Requirements", confidence: "High", pinned: true),
        MemoryEntry(scope: .decision, content: "Veqral is the preferred product name for the initial prototype.", source: "Naming pass", confidence: "High", pinned: true),
        MemoryEntry(scope: .agent, content: "Worker agents may propose memory candidates but should not write canonical memory directly.", source: "Context policy", confidence: "Medium", pinned: false),
        MemoryEntry(scope: .project, content: "Approval is mandatory for deletion, billing, production, secrets, and screen control.", source: "Approval policy", confidence: "High", pinned: true)
    ]

    static let diffs: [DiffFile] = [
        DiffFile(path: "Veqral/RootView.swift", additions: 214, deletions: 0, summary: "Adds responsive iPhone tabs and iPad three-pane navigation."),
        DiffFile(path: "Veqral/Screens.swift", additions: 612, deletions: 0, summary: "Adds the command, requirements, devices, agents, runs, terminal, diff, artifacts, approvals, memory, and GitHub screens."),
        DiffFile(path: "Veqral/MockData.swift", additions: 198, deletions: 0, summary: "Adds realistic data that mirrors the handoff document."),
        DiffFile(path: "README.md", additions: 16, deletions: 0, summary: "Documents how to open and build the prototype.")
    ]

    static let logs: [LogLine] = [
        LogLine(time: "13:49:02", stream: "pm", message: "Loaded USER.md, project memory, and decision log into context package."),
        LogLine(time: "13:49:08", stream: "forge", message: "Scaffolding SwiftUI screens for MVP 0."),
        LogLine(time: "13:49:21", stream: "forge", message: "Added mock devices: MacBook Pro, Mac mini, offline travel Mac."),
        LogLine(time: "13:49:44", stream: "probe", message: "Waiting for simulator build before screenshot pass."),
        LogLine(time: "13:50:03", stream: "approval", message: "Queued deletion approval for stale derived prototype folder.")
    ]

    static let contextPackage = [
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
