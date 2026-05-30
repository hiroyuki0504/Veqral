import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: CommandCenterStore
    private let columns = [GridItem(.adaptive(minimum: 156), spacing: 12)]
    private let panelColumns = [GridItem(.adaptive(minimum: 300), spacing: 14)]

    private var metrics: [CommandMetric] {
        let activeCount = store.runs.filter { [.running, .waiting, .approval].contains($0.status) }.count
        let runningCount = store.runs.filter { $0.status == .running }.count
        return [
            CommandMetric(title: "Active runs", value: "\(activeCount)", detail: "\(runningCount) running", symbol: "play.circle", tint: VQTheme.accent),
            CommandMetric(title: "Approvals", value: "\(store.pendingApprovals().count)", detail: "Deletion, deploy, secrets", symbol: "hand.raised", tint: VQTheme.amber),
            CommandMetric(title: "Mac Host", value: store.workspace.canRunLocalCommands ? "1" : "0", detail: store.workspace.tailscaleIP.isEmpty ? "Tailscale pending" : store.workspace.tailscaleIP, symbol: "macbook.and.iphone", tint: store.workspace.canRunLocalCommands ? VQTheme.green : VQTheme.amber),
            CommandMetric(title: "Context", value: "\(MockData.contextPackage.count)", detail: "Shared package items", symbol: "archivebox", tint: VQTheme.green)
        ]
    }

    var body: some View {
        ScreenScaffold(title: "Command", systemImage: "command") {
            CommandComposer()

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(metrics) { metric in
                    MetricTile(metric: metric)
                }
            }

            LazyVGrid(columns: panelColumns, spacing: 14) {
                VQPanel("Active Runs", systemImage: "play.rectangle.on.rectangle", actionImage: "arrow.right") {
                    VStack(alignment: .leading, spacing: 12) {
                        let visibleRuns = Array(store.runs.prefix(3))
                        ForEach(visibleRuns) { run in
                            Button {
                                store.selectRun(run.id)
                            } label: {
                                CommandRunListRow(run: run, isSelected: store.selectedRunID == run.id)
                            }
                            .buttonStyle(.plain)
                            if run.id != visibleRuns.last?.id {
                                EmptyDivider()
                            }
                        }
                    }
                }

                VQPanel("Approval Queue", systemImage: "hand.raised", actionImage: "arrow.right") {
                    VStack(alignment: .leading, spacing: 12) {
                        let pending = store.pendingApprovals(limit: 2)
                        if pending.isEmpty {
                            Text("Risky commands and Hermes prompts pause here before execution.")
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                        }
                        ForEach(pending) { approval in
                            CommandApprovalQueueRow(approval: approval)
                            if approval.id != pending.last?.id {
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
    @EnvironmentObject private var store: CommandCenterStore
    @State private var remoteEndpoint = ""
    @State private var remotePairingCode = ""
    @State private var remoteDeviceName = ProcessInfo.processInfo.hostName
    @State private var remoteStatusMessage = ""
    @State private var isPairing = false
    private let columns = [GridItem(.adaptive(minimum: 320), spacing: 14)]

    var body: some View {
        ScreenScaffold(title: "Devices", systemImage: "macbook.and.iphone") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                VQPanel("This Device", systemImage: "laptopcomputer") {
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: store.workspace.canRunLocalCommands ? "checkmark.seal" : "exclamationmark.triangle")
                            .font(.system(size: 44, weight: .light))
                            .frame(width: 92, height: 92)
                            .foregroundStyle(store.workspace.canRunLocalCommands ? VQTheme.green : VQTheme.amber)
                            .background((store.workspace.canRunLocalCommands ? VQTheme.green : VQTheme.amber).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 12) {
                            KeyValueLine(key: "Device", value: store.workspace.deviceName)
                            KeyValueLine(key: "Host", value: store.workspace.hostName)
                            KeyValueLine(key: "Local shell", value: store.workspace.canRunLocalCommands ? "Available" : "Mac Host required")
                            KeyValueLine(key: "Hermes", value: store.workspace.hermesLabel)
                            KeyValueLine(key: "Workspace", value: store.workspace.workingDirectory)
                            HStack {
                                Button(action: store.refreshWorkspace) {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                            }
                            .font(.footnote.weight(.semibold))
                        }
                    }
                }

                VQPanel("Workspace", systemImage: "folder") {
                    VStack(alignment: .leading, spacing: 12) {
                        KeyValueLine(key: "Project", value: store.workspace.projectName)
                        KeyValueLine(key: "Git root", value: store.workspace.rootPath.isEmpty ? "Not detected" : store.workspace.rootPath)
                        KeyValueLine(key: "Branch", value: store.workspace.branchLabel)
                        KeyValueLine(key: "State", value: store.workspace.statusSummary)
                        KeyValueLine(key: "Hermes path", value: store.workspace.hermesPath.isEmpty ? "Not detected" : store.workspace.hermesPath)
                        KeyValueLine(key: "Tailscale", value: store.workspace.tailscaleIP.isEmpty ? "Not detected" : store.workspace.tailscaleIP)
                        if let error = store.workspace.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(VQTheme.amber)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VQPanel("Remote Mac Host", systemImage: "antenna.radiowaves.left.and.right") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            StatusPill(
                                title: store.remoteHost.isEnabled && store.remoteHost.isPaired ? "Remote Enabled" : "Offline",
                                tint: store.remoteHost.isEnabled && store.remoteHost.isPaired ? VQTheme.green : VQTheme.amber
                            )
                            StatusPill(title: "HMAC", tint: VQTheme.accent)
                            StatusPill(title: "Keychain", tint: VQTheme.green)
                            Spacer()
                        }

                        KeyValueLine(key: "Saved endpoint", value: store.remoteHost.displayEndpoint)
                        KeyValueLine(key: "Device ID", value: store.remoteHost.deviceID.isEmpty ? "Not paired" : "\(store.remoteHost.deviceID.prefix(8))...")
                        KeyValueLine(key: "Execution", value: store.remoteHost.isEnabled ? "iPhone/iPad -> Tailscale -> Mac Host -> Hermes" : "Mac Catalyst or mock only")

                        RemoteConnectionField(title: "Endpoint", placeholder: store.workspace.macHostEndpoint, text: $remoteEndpoint)
                        RemoteConnectionField(title: "Pairing code", placeholder: "8-character code from menu bar QR", text: $remotePairingCode)
                        RemoteConnectionField(title: "This device name", placeholder: "iPhone / iPad", text: $remoteDeviceName)

                        HStack(spacing: 8) {
                            Button {
                                pairRemoteHost()
                            } label: {
                                Label(isPairing ? "Pairing" : "Pair", systemImage: "link.badge.plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                            .disabled(isPairing || remoteEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || remotePairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button {
                                store.disableRemoteHost()
                                remoteStatusMessage = "Remote Host disabled. Pairing data remains in Keychain."
                            } label: {
                                Label("Disable", systemImage: "wifi.slash")
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                        }
                        .font(.footnote.weight(.semibold))

                        if !remoteStatusMessage.isEmpty {
                            Text(remoteStatusMessage)
                                .font(.caption)
                                .foregroundStyle(remoteStatusMessage.contains("failed") || remoteStatusMessage.contains("失敗") ? VQTheme.amber : VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VQPanel("Mac Host Pairing", systemImage: "qrcode.viewfinder") {
                    HStack(alignment: .top, spacing: 16) {
                        QRCodeView(payload: store.pairingPayload)
                            .frame(width: 132, height: 132)

                        VStack(alignment: .leading, spacing: 12) {
                            KeyValueLine(key: "Endpoint", value: store.workspace.macHostEndpoint)
                            KeyValueLine(key: "Code", value: "\(store.pairingToken.prefix(8))...")
                            KeyValueLine(key: "Transport", value: "Tailscale WebSocket")
                            KeyValueLine(key: "Host app", value: "Menu bar app shows the real QR")
                            Text("For P0, launch VeqralHost on the Mac, open Show Pairing QR from the menu bar, then paste the endpoint and code above.")
                                .font(.caption)
                                .foregroundStyle(VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Button(action: store.rotatePairingToken) {
                                    Label("Rotate", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                                Button(action: store.refreshWorkspace) {
                                    Label("Check", systemImage: "network")
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                            }
                            .font(.footnote.weight(.semibold))
                        }
                    }
                }
            }
        }
        .onAppear(perform: syncRemoteFields)
        .onChange(of: store.remoteHost) { _, _ in
            syncRemoteFields()
        }
    }

    private func syncRemoteFields() {
        remoteEndpoint = store.remoteHost.endpoint.isEmpty ? store.workspace.macHostEndpoint : store.remoteHost.endpoint
        if remoteDeviceName.isEmpty {
            remoteDeviceName = ProcessInfo.processInfo.hostName
        }
    }

    private func pairRemoteHost() {
        isPairing = true
        remoteStatusMessage = "Pairing with Mac Host..."
        let endpoint = remoteEndpoint
        let code = remotePairingCode
        let deviceName = remoteDeviceName.isEmpty ? ProcessInfo.processInfo.hostName : remoteDeviceName
        Task { @MainActor in
            do {
                try await store.pairRemoteHost(endpoint: endpoint, pairingCode: code, deviceName: deviceName)
                remotePairingCode = ""
                remoteStatusMessage = "Paired. Future runs will launch through Mac Host."
            } catch {
                remoteStatusMessage = "Pairing failed: \(error.localizedDescription)"
            }
            isPairing = false
        }
    }
}

struct ProjectsView: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        ScreenScaffold(title: "Projects", systemImage: "folder") {
            VQPanel(store.workspace.projectName, systemImage: "folder.badge.gearshape") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        StatusPill(title: store.workspace.statusSummary, tint: store.workspace.changedFiles == 0 ? VQTheme.green : VQTheme.amber)
                        Spacer()
                        Label("\(store.runs.count)", systemImage: "play.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                    KeyValueLine(key: "Repository", value: store.workspace.remoteLabel)
                    KeyValueLine(key: "Local path", value: store.workspace.workingDirectory)
                    KeyValueLine(key: "Git root", value: store.workspace.rootPath.isEmpty ? "Not detected" : store.workspace.rootPath)
                    KeyValueLine(key: "Branch", value: store.workspace.branchLabel)
                    FlowLayout(items: ["Hermes Agent", "Local Shell", "Approvals", "Persisted Runs", "Git Diff"])
                }
            }
        }
    }
}

struct AgentsView: View {
    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 14)]

    var body: some View {
        ScreenScaffold(title: "Agents", systemImage: "person.3.sequence") {
            ContextPackageIndicator(
                subtitle: "PM, implementer, reviewer, tester, and researcher receive the same project memory and safety contract."
            )

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

struct ModelAssignmentView: View {
    @EnvironmentObject private var store: CommandCenterStore
    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 14)]

    var body: some View {
        ScreenScaffold(title: "Models", systemImage: "cpu") {
            ContextPackageIndicator(
                title: "Model-independent Context",
                subtitle: "Provider prompts can differ, but every role is generated from the same Context Package."
            )

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(MockData.modelProfiles) { profile in
                    VQPanel(profile.role, systemImage: modelSymbol(for: profile.role)) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(profile.modelName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(VQTheme.ink)
                                    Text(profile.provider)
                                        .font(.caption)
                                        .foregroundStyle(VQTheme.secondaryText)
                                }
                                Spacer()
                                StatusPill(title: profile.assignedDevice, tint: VQTheme.accent)
                            }

                            HStack(spacing: 8) {
                                ModelTrait(label: "Cost", value: profile.costLevel, tint: profile.costLevel == "High" ? VQTheme.amber : VQTheme.green)
                                ModelTrait(label: "Speed", value: profile.speedLevel, tint: profile.speedLevel == "High" ? VQTheme.green : VQTheme.steel)
                                ModelTrait(label: "Reasoning", value: profile.reasoningLevel, tint: VQTheme.violet)
                            }

                            Text(profile.contextPolicy)
                                .font(.caption)
                                .foregroundStyle(VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            FlowLayout(items: profile.toolSupport)
                        }
                    }
                }
            }

            VQPanel("Runtime Engines", systemImage: "bolt.horizontal") {
                VStack(alignment: .leading, spacing: 12) {
                    KeyValueLine(key: "Selected runtime", value: store.selectedRuntime.title)
                    KeyValueLine(key: "Hermes", value: store.workspace.hermesLabel)
                    KeyValueLine(key: "Local shell", value: store.workspace.canRunLocalCommands ? "Available on Mac" : "Requires Mac Host")
                    KeyValueLine(key: "Output contract", value: "logs / diffs / artifacts / approvals")
                }
            }
        }
    }

    private func modelSymbol(for role: String) -> String {
        let lower = role.lowercased()
        if lower.contains("pm") || lower.contains("manager") { return "person.badge.key" }
        if lower.contains("architect") { return "square.stack.3d.up" }
        if lower.contains("implementer") { return "hammer" }
        if lower.contains("reviewer") { return "checkmark.seal" }
        if lower.contains("tester") { return "testtube.2" }
        return "magnifyingglass"
    }
}

private struct ModelTrait: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(VQTheme.secondaryText)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct RunsView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var selectedPhase: RunPhase? = nil

    private var filteredRuns: [CommandRun] {
        guard let selectedPhase else { return store.runs }
        return store.runs.filter { $0.phase == selectedPhase }
    }

    var body: some View {
        ScreenScaffold(title: "Runs", systemImage: "play.rectangle.on.rectangle") {
            VQPanel("Pipeline", systemImage: "timeline.selection") {
                PhaseRail(current: selectedPhase ?? store.selectedRun?.phase ?? .implementation)
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
                    if filteredRuns.isEmpty {
                        Text("No runs in this phase yet.")
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                    ForEach(filteredRuns) { run in
                        Button {
                            store.selectRun(run.id)
                        } label: {
                            CommandRunListRow(run: run, isSelected: store.selectedRunID == run.id)
                        }
                        .buttonStyle(.plain)
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
                        RuntimeSegmentedControl()
                    }

                    HStack(spacing: 10) {
                        TextField("Command to run on Mac", text: $store.commandDraft, axis: .vertical)
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
                            .onSubmit {
                                store.refreshWorkspace()
                            }
                    }
                    .foregroundStyle(VQTheme.secondaryText)
                    HStack {
                        StatusPill(title: store.workspace.statusSummary, tint: store.workspace.changedFiles == 0 ? VQTheme.green : VQTheme.amber)
                        Text(store.workspace.branchLabel)
                            .font(.caption.monospaced())
                            .foregroundStyle(VQTheme.secondaryText)
                            .lineLimit(1)
                    }
                    #else
                    Text("On iPhone and iPad this saves the run. Local execution happens from the Mac build.")
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
                            if let run = store.selectedRun {
                                store.submitCommand(run.command, runtime: run.runtimeOrDefault)
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
        ScreenScaffold(title: "Approvals", systemImage: "hand.raised") {
            VQPanel("Policy", systemImage: "lock.shield") {
                FlowLayout(items: ["File deletion", "Billing", "Production", "Secrets", "Screen control"])
            }

            let pending = store.pendingApprovals()
            if pending.isEmpty {
                VQPanel("Queue", systemImage: "checkmark.shield") {
                    Text("No pending approvals. Risky commands stop here and run from the Mac build after approval.")
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
                Button("Reject") {
                    store.reject(approval)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                Button("Approve") {
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
    @EnvironmentObject private var store: CommandCenterStore
    @State private var selectedScope: MemoryScope = .project

    private var filteredMemory: [MemoryEntry] {
        MockData.memory.filter { $0.scope == selectedScope }
    }

    private var selectedRemoteFile: RemoteMemoryFile? {
        guard let selectedRemoteMemoryID = store.selectedRemoteMemoryID else { return nil }
        return store.remoteMemoryFiles.first { $0.id == selectedRemoteMemoryID }
    }

    var body: some View {
        ScreenScaffold(title: "Memory", systemImage: "brain.head.profile") {
            VQPanel("Hermes Memory Files", systemImage: "externaldrive.connected.to.line.below") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        StatusPill(
                            title: store.remoteHost.isEnabled && store.remoteHost.isPaired ? "Mac Host Connected" : "Pair Mac Host",
                            tint: store.remoteHost.isEnabled && store.remoteHost.isPaired ? VQTheme.green : VQTheme.amber
                        )
                        StatusPill(title: "USER.md", tint: VQTheme.accent)
                        StatusPill(title: "MEMORY.md", tint: VQTheme.accent)
                        StatusPill(title: "Skills", tint: VQTheme.secondaryText)
                        Spacer()
                        Button {
                            store.refreshRemoteMemory()
                        } label: {
                            Label(store.isLoadingRemoteMemory ? "Loading" : "Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .disabled(store.isLoadingRemoteMemory || !(store.remoteHost.isEnabled && store.remoteHost.isPaired))
                    }
                    .font(.footnote.weight(.semibold))

                    if !(store.remoteHost.isEnabled && store.remoteHost.isPaired) {
                        Text("DevicesでMac HostをQRペアリングすると、Mac上のHermesメモリをここから確認・編集できます。")
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        RemoteMemoryEditor(selectedFile: selectedRemoteFile)
                    }

                    if !store.remoteMemoryMessage.isEmpty {
                        Text(store.remoteMemoryMessage)
                            .font(.caption)
                            .foregroundStyle(store.remoteMemoryMessage.contains("failed") || store.remoteMemoryMessage.contains("失敗") ? VQTheme.amber : VQTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

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
        .onAppear {
            if store.remoteHost.isEnabled, store.remoteHost.isPaired, store.remoteMemoryFiles.isEmpty {
                store.refreshRemoteMemory()
            }
        }
    }
}

struct GitHubOpsView: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        ScreenScaffold(title: "GitHub", systemImage: "point.3.connected.trianglepath.dotted") {
            VQPanel("Release Flow", systemImage: "arrow.triangle.branch") {
                VStack(alignment: .leading, spacing: 14) {
                    GitHubStep(title: "Branch", value: store.workspace.branchLabel, status: store.workspace.branch.isEmpty ? "Missing" : "Ready", tint: store.workspace.branch.isEmpty ? VQTheme.amber : VQTheme.green)
                    GitHubStep(title: "Working Tree", value: store.workspace.statusSummary, status: store.workspace.changedFiles == 0 ? "Clean" : "Dirty", tint: store.workspace.changedFiles == 0 ? VQTheme.green : VQTheme.amber)
                    GitHubStep(title: "Pull Request", value: "Not opened", status: "Next", tint: VQTheme.secondaryText)
                    GitHubStep(title: "CI", value: "No checks yet", status: "Idle", tint: VQTheme.secondaryText)
                    GitHubStep(title: "Deploy", value: "Approval required", status: "Locked", tint: VQTheme.red)
                }
            }

            VQPanel("Repository", systemImage: "tray.full") {
                KeyValueLine(key: "Remote", value: store.workspace.remoteLabel)
                KeyValueLine(key: "Working tree", value: store.workspace.statusSummary)
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

private struct RemoteConnectionField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VQTheme.secondaryText)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.footnote)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(VQTheme.control.opacity(0.64))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(VQTheme.hairline, lineWidth: 1)
                }
        }
    }
}

private struct RemoteMemoryEditor: View {
    @EnvironmentObject private var store: CommandCenterStore
    let selectedFile: RemoteMemoryFile?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                fileList
                    .frame(width: 230)
                editor
            }

            VStack(alignment: .leading, spacing: 14) {
                fileList
                editor
            }
        }
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.remoteMemoryFiles.isEmpty {
                Text("No Hermes memory files loaded.")
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
            } else {
                ForEach(store.remoteMemoryFiles) { file in
                    Button {
                        store.selectRemoteMemory(file)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: file.kind == "skill" ? "hammer" : "doc.text")
                                .foregroundStyle(file.id == store.selectedRemoteMemoryID ? VQTheme.accent : VQTheme.secondaryText)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(file.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text(file.relativePath)
                                    .font(.caption2)
                                    .foregroundStyle(VQTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(file.id == store.selectedRemoteMemoryID ? VQTheme.accent.opacity(0.12) : VQTheme.control.opacity(0.46))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedFile?.relativePath ?? "Select a file")
                        .font(.caption.weight(.semibold))
                    if let selectedFile {
                        Text("\(selectedFile.bytes) bytes")
                            .font(.caption2)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                }
                Spacer()
                Button {
                    store.previewRemoteMemoryDiff()
                } label: {
                    Label("Diff", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .disabled(selectedFile == nil || store.isLoadingRemoteMemory)

                Button {
                    store.saveRemoteMemory()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .disabled(selectedFile == nil || store.isLoadingRemoteMemory)
            }
            .font(.footnote.weight(.semibold))

            TextEditor(text: $store.remoteMemoryContent)
                .font(.system(.caption, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 220)
                .background(VQTheme.control.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(VQTheme.hairline, lineWidth: 1)
                }

            if !store.remoteMemoryDiff.isEmpty {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(store.remoteMemoryDiff)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(VQTheme.ink)
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
                .background(VQTheme.panel.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(VQTheme.hairline, lineWidth: 1)
                }
            }
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
