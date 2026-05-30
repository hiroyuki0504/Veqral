import SwiftUI

struct DashboardView: View {
    private let columns = [GridItem(.adaptive(minimum: 156), spacing: 12)]
    private let panelColumns = [GridItem(.adaptive(minimum: 300), spacing: 14)]

    var body: some View {
        ScreenScaffold(title: "Command", systemImage: "command") {
            CommandComposer()

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MockData.metrics) { metric in
                    MetricTile(metric: metric)
                }
            }

            LazyVGrid(columns: panelColumns, spacing: 14) {
                VQPanel("Active Runs", systemImage: "play.rectangle.on.rectangle", actionImage: "arrow.right") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(MockData.runs.prefix(3)) { run in
                            RunRow(run: run)
                            if run.id != MockData.runs.prefix(3).last?.id {
                                EmptyDivider()
                            }
                        }
                    }
                }

                VQPanel("Approval Queue", systemImage: "hand.raised", actionImage: "arrow.right") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(MockData.approvals.prefix(2)) { approval in
                            ApprovalRow(approval, compact: true)
                            if approval.id != MockData.approvals.prefix(2).last?.id {
                                EmptyDivider()
                            }
                        }
                    }
                }

                VQPanel("Device Fleet", systemImage: "macbook.and.iphone", actionImage: "qrcode.viewfinder") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(MockData.devices.prefix(2)) { device in
                            DeviceRow(device: device)
                            if device.id != MockData.devices.prefix(2).last?.id {
                                EmptyDivider()
                            }
                        }
                    }
                }

                VQPanel("Recent Artifacts", systemImage: "shippingbox", actionImage: "square.grid.2x2") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(MockData.artifacts.prefix(4)) { artifact in
                            HStack(spacing: 10) {
                                Image(systemName: artifact.symbol)
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(VQTheme.accent)
                                    .background(VQTheme.accent.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artifact.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(artifact.type) · \(artifact.source)")
                                        .font(.caption)
                                        .foregroundStyle(VQTheme.secondaryText)
                                }
                                Spacer()
                                StatusPill(title: artifact.status, tint: artifact.status == "Ready" ? VQTheme.green : VQTheme.amber)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct IntentCaptureView: View {
    private let columns = [GridItem(.adaptive(minimum: 320), spacing: 14)]

    var body: some View {
        ScreenScaffold(title: "Intent", systemImage: "text.bubble") {
            CommandComposer()

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                VQPanel("Conversation", systemImage: "bubble.left.and.bubble.right") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(MockData.chat) { message in
                            HStack {
                                if message.isUser { Spacer(minLength: 28) }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(message.speaker)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(message.isUser ? VQTheme.accent : VQTheme.steel)
                                    Text(message.text)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(10)
                                .background(message.isUser ? VQTheme.accent.opacity(0.12) : VQTheme.steel.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                if !message.isUser { Spacer(minLength: 28) }
                            }
                        }
                    }
                }

                VQPanel("Requirement Draft", systemImage: "checklist") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(MockData.requirements.prefix(4)) { section in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(section.title)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    StatusPill(title: section.state.title, tint: section.state.tint)
                                }
                                Text(section.bullets.first ?? "")
                                    .font(.caption)
                                    .foregroundStyle(VQTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if section.id != MockData.requirements.prefix(4).last?.id {
                                EmptyDivider()
                            }
                        }
                    }
                }

                VQPanel("Memory Candidates", systemImage: "brain.head.profile") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(MockData.memory.filter { !$0.pinned }.prefix(3)) { entry in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(VQTheme.accent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.content)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("\(entry.scope.title) · \(entry.confidence)")
                                        .font(.caption)
                                        .foregroundStyle(VQTheme.secondaryText)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }
}

struct RequirementsView: View {
    var body: some View {
        ScreenScaffold(title: "Requirements", systemImage: "checklist") {
            VQPanel("Phase Gate", systemImage: "flag.checkered") {
                PhaseRail(current: .requirements)
            }

            VStack(spacing: 12) {
                ForEach(MockData.requirements) { section in
                    VQPanel(section.title, systemImage: section.state == .decided ? "checkmark.circle" : "circle.dotted") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                StatusPill(title: section.state.title, tint: section.state.tint)
                                Spacer()
                                Button(action: {}) {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                                .help("Edit")
                            }

                            ForEach(section.bullets, id: \.self) { bullet in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "smallcircle.filled.circle")
                                        .font(.caption2)
                                        .foregroundStyle(section.state.tint)
                                        .padding(.top, 4)
                                    Text(bullet)
                                        .font(.subheadline)
                                        .foregroundStyle(VQTheme.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct DevicesView: View {
    private let columns = [GridItem(.adaptive(minimum: 320), spacing: 14)]

    var body: some View {
        ScreenScaffold(title: "Devices", systemImage: "macbook.and.iphone") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                VQPanel("Pair Mac Host", systemImage: "qrcode.viewfinder") {
                    HStack(alignment: .top, spacing: 16) {
                        QRPlaceholder()
                        VStack(alignment: .leading, spacing: 12) {
                            KeyValueLine(key: "Transport", value: "Tailscale")
                            KeyValueLine(key: "Pairing", value: "QR + device key")
                            KeyValueLine(key: "Host", value: "Menu bar app")
                            KeyValueLine(key: "Token", value: "Keychain")
                            HStack {
                                Button(action: {}) {
                                    Label("Scan", systemImage: "camera.viewfinder")
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                                Button(action: {}) {
                                    Image(systemName: "plus")
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                                .help("Add manually")
                            }
                            .font(.footnote.weight(.semibold))
                        }
                    }
                }

                ForEach(MockData.devices) { device in
                    VQPanel(device.name, systemImage: device.status == .offline ? "desktopcomputer.trianglebadge.exclamationmark" : "desktopcomputer") {
                        DeviceRow(device: device)
                        EmptyDivider()
                        KeyValueLine(key: "Active run", value: device.activeRun)
                    }
                }
            }
        }
    }
}

struct ProjectsView: View {
    var body: some View {
        ScreenScaffold(title: "Projects", systemImage: "folder") {
            ForEach(MockData.projects) { project in
                VQPanel(project.name, systemImage: "folder.badge.gearshape") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            StatusPill(title: project.status, tint: VQTheme.accent)
                            Spacer()
                            Label("\(project.activeRuns)", systemImage: "play.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VQTheme.secondaryText)
                        }
                        KeyValueLine(key: "Repository", value: project.repo)
                        KeyValueLine(key: "Local path", value: project.localPath)
                        KeyValueLine(key: "Memory entries", value: "\(project.memoryCount)")
                        FlowLayout(items: project.team)
                    }
                }
            }
        }
    }
}

struct AgentsView: View {
    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 14)]

    var body: some View {
        ScreenScaffold(title: "Agents", systemImage: "person.3.sequence") {
            VQPanel("Organization", systemImage: "point.3.connected.trianglepath.dotted") {
                OrganizationGraph()
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(MockData.agents) { agent in
                    VQPanel(agent.name, systemImage: "person.crop.circle.badge.checkmark") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(agent.role)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                StatusPill(title: agent.status.title, tint: agent.status.tint)
                            }
                            KeyValueLine(key: "Model", value: agent.model)
                            KeyValueLine(key: "Device", value: agent.device)
                            FlowLayout(items: agent.permissions)
                        }
                    }
                }
            }
        }
    }
}

struct RunsView: View {
    @State private var selectedPhase: RunPhase? = nil

    private var filteredRuns: [AgentRun] {
        guard let selectedPhase else { return MockData.runs }
        return MockData.runs.filter { $0.phase == selectedPhase }
    }

    var body: some View {
        ScreenScaffold(title: "Runs", systemImage: "play.rectangle.on.rectangle") {
            VQPanel("Pipeline", systemImage: "timeline.selection") {
                PhaseRail(current: selectedPhase ?? .implementation)
                Picker("Phase", selection: $selectedPhase) {
                    Text("All").tag(nil as RunPhase?)
                    ForEach(RunPhase.allCases) { phase in
                        Text(phase.title).tag(phase as RunPhase?)
                    }
                }
                .pickerStyle(.segmented)
            }

            VQPanel("Queue", systemImage: "list.bullet.rectangle") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(filteredRuns) { run in
                        RunRow(run: run)
                        if run.id != filteredRuns.last?.id {
                            EmptyDivider()
                        }
                    }
                }
            }
        }
    }
}

struct TerminalView: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        ScreenScaffold(title: "Terminal", systemImage: "terminal") {
            VQPanel("Command", systemImage: "paperplane") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        TextField("Macで実行するコマンド", text: $store.commandDraft, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(1...3)
                            .font(.body.monospaced())
                            .onSubmit {
                                store.submitDraft()
                            }
                        Button(action: store.submitDraft) {
                            Label("Run", systemImage: "arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                    }

                    #if targetEnvironment(macCatalyst)
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                        TextField("Working directory", text: $store.workingDirectory)
                            .textFieldStyle(.plain)
                            .font(.caption.monospaced())
                    }
                    .foregroundStyle(VQTheme.secondaryText)
                    #else
                    Text("iPhone/iPadではRunを保存します。ローカル実行はMac版で行います。")
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                    #endif
                }
            }

            VQPanel("Session", systemImage: "terminal", actionImage: "arrow.clockwise") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        StatusPill(title: store.selectedRun?.status.title ?? "Waiting", tint: store.selectedRun?.status.tint ?? VQTheme.secondaryText)
                        Spacer()
                        Text(store.selectedRun?.title ?? "No run selected")
                            .font(.caption.monospaced())
                            .foregroundStyle(VQTheme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        let logs = store.logEntries(for: store.selectedRun?.id)
                        if logs.isEmpty {
                            Text("まだログはありません。")
                                .foregroundStyle(VQTheme.secondaryText)
                        }
                        ForEach(logs) { line in
                            HStack(alignment: .top, spacing: 8) {
                                Text(line.time.commandTime)
                                    .foregroundStyle(VQTheme.secondaryText)
                                Text(line.stream)
                                    .foregroundStyle(VQTheme.amber)
                                    .frame(width: 58, alignment: .leading)
                                Text(line.message)
                                    .foregroundStyle(Color(red: 0.85, green: 0.90, blue: 0.88))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .font(.caption.monospaced())
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.06, green: 0.07, blue: 0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    HStack {
                        Text("$ \(store.selectedRun?.command ?? "pwd")")
                            .font(.caption.monospaced())
                            .foregroundStyle(VQTheme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            if let command = store.selectedRun?.command {
                                store.submitCommand(command)
                            }
                        } label: {
                            Image(systemName: "paperplane")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .help("Send command")
                    }
                }
            }
        }
    }
}

struct DiffView: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        ScreenScaffold(title: "Diff", systemImage: "plus.forwardslash.minus") {
            VQPanel("Changed Files", systemImage: "doc.on.doc") {
                VStack(alignment: .leading, spacing: 12) {
                    let diffs = store.diffEntries(for: store.selectedRun?.id)
                    if diffs.isEmpty {
                        Text("Git diffはまだありません。Mac版でgit管理下のフォルダを指定すると取得します。")
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                    ForEach(diffs) { file in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(file.path)
                                    .font(.subheadline.monospaced().weight(.semibold))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text("+\(file.additions) -\(file.deletions)")
                                    .font(.caption.monospaced().weight(.semibold))
                                    .foregroundStyle(file.deletions > 0 ? VQTheme.amber : VQTheme.green)
                            }
                        }
                        if file.id != diffs.last?.id {
                            EmptyDivider()
                        }
                    }
                }
            }

            VQPanel("Review Notes", systemImage: "text.badge.checkmark") {
                VStack(alignment: .leading, spacing: 10) {
                    ReviewNote(symbol: "checkmark.circle", text: "Responsive navigation separates iPhone tabs from iPad inspection.")
                    ReviewNote(symbol: "exclamationmark.triangle", text: "Mac Host transport remains mocked until MVP 1.")
                    ReviewNote(symbol: "arrow.triangle.2.circlepath", text: "Diff summaries should later come from git plus agent review.")
                }
            }
        }
    }
}

struct ArtifactsView: View {
    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 14)]

    var body: some View {
        ScreenScaffold(title: "Artifacts", systemImage: "shippingbox") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(MockData.artifacts) { artifact in
                    VQPanel(artifact.title, systemImage: artifact.symbol) {
                        VStack(alignment: .leading, spacing: 12) {
                            ZStack {
                                Rectangle()
                                    .fill(VQTheme.steel.opacity(0.08))
                                Image(systemName: artifact.symbol)
                                    .font(.system(size: 44, weight: .light))
                                    .foregroundStyle(VQTheme.accent)
                            }
                            .frame(height: 118)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            KeyValueLine(key: "Type", value: artifact.type)
                            KeyValueLine(key: "Source", value: artifact.source)
                            StatusPill(title: artifact.status, tint: artifact.status == "Ready" ? VQTheme.green : VQTheme.amber)
                        }
                    }
                }
            }
        }
    }
}

struct ApprovalsView: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        ScreenScaffold(title: "承認", systemImage: "hand.raised") {
            VQPanel("Policy", systemImage: "lock.shield") {
                FlowLayout(items: ["File deletion", "Billing", "Production", "Secrets", "Screen control"])
            }

            let pending = store.pendingApprovals()
            if pending.isEmpty {
                VQPanel("Queue", systemImage: "checkmark.shield") {
                    Text("承認待ちはありません。危険なコマンドはここで止まり、承認後にMac版で実行されます。")
                        .font(.subheadline)
                        .foregroundStyle(VQTheme.secondaryText)
                }
            }

            ForEach(pending) { approval in
                VQPanel(approval.riskLabel, systemImage: approval.symbolName) {
                    CommandApprovalQueueRow(approval: approval)
                }
            }
        }
    }
}

private struct CommandApprovalQueueRow: View {
    @EnvironmentObject private var store: CommandCenterStore
    let approval: CommandApproval

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: approval.symbolName)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(approval.tint)
                    .background(approval.tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(approval.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    Text(approval.detail)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(approval.command)
                        .font(.caption.monospaced())
                        .foregroundStyle(VQTheme.steel)
                        .lineLimit(2)
                }
            }

            HStack {
                StatusPill(title: approval.riskLabel, tint: approval.tint)
                Spacer()
                Button("拒否") {
                    store.reject(approval)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                Button("承認") {
                    store.approve(approval)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 8))
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(.vertical, 4)
    }
}

struct MemoryView: View {
    @State private var selectedScope: MemoryScope = .project

    private var filteredMemory: [MemoryEntry] {
        MockData.memory.filter { $0.scope == selectedScope }
    }

    var body: some View {
        ScreenScaffold(title: "Memory", systemImage: "brain.head.profile") {
            VQPanel("Scope", systemImage: "square.stack.3d.up") {
                Picker("Scope", selection: $selectedScope) {
                    ForEach(MemoryScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
            }

            VQPanel("\(selectedScope.title) Memory", systemImage: "pin") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(filteredMemory) { entry in
                        MemoryRow(entry: entry)
                        if entry.id != filteredMemory.last?.id {
                            EmptyDivider()
                        }
                    }
                }
            }

            VQPanel("Context Package", systemImage: "archivebox") {
                FlowLayout(items: MockData.contextPackage)
            }
        }
    }
}

struct GitHubOpsView: View {
    var body: some View {
        ScreenScaffold(title: "GitHub", systemImage: "point.3.connected.trianglepath.dotted") {
            VQPanel("Release Flow", systemImage: "arrow.triangle.branch") {
                VStack(alignment: .leading, spacing: 14) {
                    GitHubStep(title: "Branch", value: "codex/mvp-0-prototype", status: "Ready", tint: VQTheme.green)
                    GitHubStep(title: "Commit", value: "Waiting for review", status: "Draft", tint: VQTheme.amber)
                    GitHubStep(title: "Pull Request", value: "Not opened", status: "Next", tint: VQTheme.secondaryText)
                    GitHubStep(title: "CI", value: "No checks yet", status: "Idle", tint: VQTheme.secondaryText)
                    GitHubStep(title: "Deploy", value: "Approval required", status: "Locked", tint: VQTheme.red)
                }
            }

            VQPanel("Repository", systemImage: "tray.full") {
                KeyValueLine(key: "Remote", value: "github.com/hiroyuki/veqral")
                KeyValueLine(key: "Working tree", value: "Prototype changes")
                KeyValueLine(key: "Review mode", value: "Agent + human approval")
            }
        }
    }
}

struct InspectorView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "sidebar.right")
                        .foregroundStyle(VQTheme.accent)
                    Text("Inspector")
                        .font(.headline)
                    Spacer()
                }

                VQPanel("Current Run", systemImage: "play.circle") {
                    if let run = MockData.runs.first {
                        RunRow(run: run)
                    }
                }

                VQPanel("Context", systemImage: "archivebox") {
                    FlowLayout(items: MockData.contextPackage)
                }

                VQPanel("Approval Rules", systemImage: "lock.shield") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(["Deletion", "Billing", "Production", "Secrets", "Screen control"], id: \.self) { rule in
                            HStack {
                                Image(systemName: "checkmark.shield")
                                    .foregroundStyle(VQTheme.amber)
                                Text(rule)
                                    .font(.caption.weight(.semibold))
                                Spacer()
                            }
                        }
                    }
                }

                VQPanel("Mac Fleet", systemImage: "desktopcomputer") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(MockData.devices.prefix(2)) { device in
                            HStack {
                                Circle()
                                    .fill(device.status.tint)
                                    .frame(width: 8, height: 8)
                                Text(device.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(VQTheme.canvas.ignoresSafeArea())
    }
}

private struct PhaseRail: View {
    let current: RunPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(RunPhase.allCases) { phase in
                    VStack(spacing: 6) {
                        Image(systemName: phase == current ? "circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(phase == current ? VQTheme.accent : VQTheme.secondaryText)
                        Text(phase.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            ProgressView(value: Double(RunPhase.allCases.firstIndex(of: current) ?? 0), total: Double(RunPhase.allCases.count - 1))
                .tint(VQTheme.accent)
        }
    }
}

private struct QRPlaceholder: View {
    private let pattern: [Bool] = [
        true, true, true, false, true, true, true,
        true, false, true, false, true, false, true,
        true, true, true, true, true, true, true,
        false, true, false, true, false, true, false,
        true, true, false, false, true, false, true,
        true, false, true, true, false, false, true,
        true, true, true, false, true, true, true
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(13), spacing: 3), count: 7), spacing: 3) {
            ForEach(Array(pattern.enumerated()), id: \.offset) { _, filled in
                RoundedRectangle(cornerRadius: 2)
                    .fill(filled ? VQTheme.ink : Color.clear)
                    .frame(width: 13, height: 13)
            }
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VQTheme.hairline, lineWidth: 1)
        }
    }
}

private struct OrganizationGraph: View {
    var body: some View {
        VStack(spacing: 14) {
            AgentNode(name: "Northstar", role: "PM", tint: VQTheme.ink)
            Rectangle()
                .fill(VQTheme.hairline)
                .frame(width: 1, height: 18)
            HStack(spacing: 10) {
                AgentNode(name: "Forge", role: "Build", tint: VQTheme.accent)
                AgentNode(name: "Lens", role: "Review", tint: VQTheme.amber)
                AgentNode(name: "Probe", role: "Test", tint: VQTheme.green)
            }
            Rectangle()
                .fill(VQTheme.hairline)
                .frame(width: 1, height: 18)
            AgentNode(name: "Release", role: "GitHub", tint: VQTheme.red)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AgentNode: View {
    let name: String
    let role: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "person.crop.circle")
                .font(.title3)
                .foregroundStyle(tint)
            Text(name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(role)
                .font(.caption2)
                .foregroundStyle(VQTheme.secondaryText)
        }
        .padding(10)
        .frame(maxWidth: 110)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ReviewNote: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(symbol.contains("exclamationmark") ? VQTheme.amber : VQTheme.green)
                .padding(.top, 1)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

private struct MemoryRow: View {
    let entry: MemoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StatusPill(title: entry.scope.title, tint: entry.pinned ? VQTheme.accent : VQTheme.secondaryText)
                if entry.pinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(VQTheme.accent)
                }
                Spacer()
                Text(entry.confidence)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.secondaryText)
            }
            Text(entry.content)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Text(entry.source)
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
        }
    }
}

private struct GitHubStep: View {
    let title: String
    let value: String
    let status: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(value)
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
            }
            Spacer()
            StatusPill(title: status, tint: tint)
        }
    }
}
