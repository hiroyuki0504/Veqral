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
            CommandMetric(title: "Context", value: "\(ContextPackage.items.count)", detail: "Shared package items", symbol: "archivebox", tint: VQTheme.green)
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
                        if store.remoteDevices.isEmpty {
                            Text(store.remoteHost.isPaired ? "No paired devices loaded yet. Refresh the Mac Host." : "Pair a Mac Host to see trusted iPhone and iPad clients.")
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                        }
                        let devices = Array(store.remoteDevices.prefix(3))
                        ForEach(devices) { device in
                            RemoteDeviceSummaryRow(device: device, isCurrent: device.id == store.remoteHost.deviceID)
                            if device.id != devices.last?.id {
                                EmptyDivider()
                            }
                        }
                    }
                }

                VQPanel("Recent Artifacts", systemImage: "shippingbox", actionImage: "square.grid.2x2") {
                    VStack(alignment: .leading, spacing: 10) {
                        if store.remoteArtifacts.isEmpty {
                            Text("Artifacts appear after a Mac Host run produces files, screenshots, reports, or attachments.")
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                        }
                        ForEach(store.remoteArtifacts.prefix(4)) { artifact in
                            HStack(spacing: 10) {
                                Image(systemName: artifactSymbol(for: artifact.type))
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(VQTheme.accent)
                                    .background(VQTheme.accent.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artifact.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(artifact.type) · \(byteLabel(artifact.bytes))")
                                        .font(.caption)
                                        .foregroundStyle(VQTheme.secondaryText)
                                }
                                Spacer()
                                StatusPill(title: "Synced", tint: VQTheme.green)
                            }
                        }
                    }
                }
            }
        }
    }

    private func artifactSymbol(for type: String) -> String {
        switch type.lowercased() {
        case "png", "jpg", "jpeg", "gif", "image/jpeg", "image/png":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "html", "htm":
            return "safari"
        case "json":
            return "curlybraces.square"
        case "log", "txt":
            return "doc.text"
        default:
            return "shippingbox"
        }
    }

    private func byteLabel(_ bytes: Int) -> String {
        if bytes >= 1_048_576 { return String(format: "%.1f MB", Double(bytes) / 1_048_576) }
        if bytes >= 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return "\(bytes) B"
    }
}

struct IntentCaptureView: View {
    @EnvironmentObject private var store: CommandCenterStore
    private let columns = [GridItem(.adaptive(minimum: 320), spacing: 14)]

    var body: some View {
        ScreenScaffold(title: "Intent", systemImage: "text.bubble") {
            CommandComposer()

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                VQPanel("Run Intake", systemImage: "bubble.left.and.bubble.right") {
                    VStack(alignment: .leading, spacing: 12) {
                        if store.runs.isEmpty {
                            Text("No command history yet. Send a natural-language instruction above to create the first Hermes run.")
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(store.runs.prefix(4)) { run in
                            CommandRunListRow(run: run, isSelected: store.selectedRunID == run.id)
                        }
                    }
                }

                VQPanel("Requirement Source", systemImage: "checklist") {
                    VStack(alignment: .leading, spacing: 12) {
                        KeyValueLine(key: "Project", value: store.workspace.projectName)
                        KeyValueLine(key: "Workspace", value: store.workingDirectory)
                        KeyValueLine(key: "Runtime", value: store.selectedRuntime.title)
                        KeyValueLine(key: "Mac Host", value: store.remoteHost.isPaired ? store.remoteHost.displayEndpoint : "Not paired")
                        Text("Requirements are produced by the active Hermes run and saved as logs, diffs, artifacts, and memory edits.")
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VQPanel("Memory Candidates", systemImage: "brain.head.profile") {
                    VStack(alignment: .leading, spacing: 10) {
                        if store.remoteMemoryFiles.isEmpty {
                            Text(store.remoteHost.isPaired ? "Refresh Memory to load Hermes USER.md, MEMORY.md, and skills." : "Pair Mac Host to inspect Hermes memory.")
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                        }
                        ForEach(store.remoteMemoryFiles.prefix(4)) { file in
                            KeyValueLine(key: file.title, value: file.relativePath)
                        }
                    }
                }
            }
        }
    }
}

struct RequirementsView: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        ScreenScaffold(title: "Requirements", systemImage: "checklist") {
            VQPanel("Phase Gate", systemImage: "flag.checkered") {
                PhaseRail(current: .requirements)
            }

            VQPanel("Current Requirement Context", systemImage: "doc.text.magnifyingglass") {
                VStack(alignment: .leading, spacing: 12) {
                    if let run = store.selectedRun {
                        KeyValueLine(key: "Run", value: run.title)
                        KeyValueLine(key: "Status", value: run.status.title)
                        KeyValueLine(key: "Workspace", value: run.workingDirectory)
                        Text(run.command)
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("No requirements have been captured yet. Start from Intent or Command to let Hermes create the first requirements run.")
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
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
                                title: remoteStatusTitle,
                                tint: remoteOnline ? VQTheme.green : VQTheme.amber
                            )
                            StatusPill(title: "HMAC", tint: VQTheme.accent)
                            StatusPill(title: "Keychain", tint: VQTheme.green)
                            Spacer()
                        }

                        KeyValueLine(key: "Saved endpoint", value: store.remoteHost.displayEndpoint)
                        KeyValueLine(key: "Device ID", value: store.remoteHost.deviceID.isEmpty ? "Not paired" : "\(store.remoteHost.deviceID.prefix(8))...")
                        KeyValueLine(key: "Tailscale", value: store.remoteHostHealth?.tailscaleIP ?? (store.workspace.tailscaleIP.isEmpty ? "Not verified" : store.workspace.tailscaleIP))
                        KeyValueLine(key: "Host", value: store.remoteHostHealth?.host ?? "Not connected")
                        KeyValueLine(key: "Hermes", value: store.remoteHostHealth?.hermesVersion ?? "Not checked")
                        KeyValueLine(key: "Execution", value: store.remoteHost.isEnabled ? "iPhone/iPad -> Tailscale -> Mac Host -> Hermes" : "Pair a Mac Host before running on iPhone/iPad")

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

                            Button {
                                store.refreshRemoteHostStatus()
                            } label: {
                                Label(store.isRefreshingRemoteHost ? "Refreshing" : "Refresh Host", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                            .disabled(!store.remoteHost.isPaired || store.isRefreshingRemoteHost)
                        }
                        .font(.footnote.weight(.semibold))

                        if !store.remoteHostMessage.isEmpty {
                            Text(store.remoteHostMessage)
                                .font(.caption)
                                .foregroundStyle(store.remoteHostMessage.localizedCaseInsensitiveContains("failed") || store.remoteHostMessage.localizedCaseInsensitiveContains("offline") ? VQTheme.amber : VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !remoteStatusMessage.isEmpty {
                            Text(remoteStatusMessage)
                                .font(.caption)
                                .foregroundStyle(remoteStatusMessage.contains("failed") || remoteStatusMessage.contains("失敗") ? VQTheme.amber : VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VQPanel("CLI Diagnostics", systemImage: "stethoscope") {
                    VStack(alignment: .leading, spacing: 10) {
                        if let toolStatuses = store.remoteHostHealth?.toolStatuses, !toolStatuses.isEmpty {
                            ForEach(toolStatuses) { status in
                                ToolDiagnosticRow(status: status)
                                if status.id != toolStatuses.last?.id {
                                    EmptyDivider()
                                }
                            }
                        } else {
                            Text(store.remoteHost.isPaired ? "Refresh the Mac Host to inspect Codex, Claude, and Hermes adapters." : "Pair a Mac Host to inspect CLI versions.")
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VQPanel("Run Agent on This Mac", systemImage: "switch.2") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose which native agent the paired Mac Host should spawn for the next command.")
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach([CommandRuntime.codexDirect, .claudeDirect, .hermesAgent]) { runtime in
                            Button {
                                store.selectRuntime(runtime)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: runtime.symbol)
                                        .frame(width: 34, height: 34)
                                        .foregroundStyle(store.selectedRuntime == runtime ? VQTheme.accent : VQTheme.secondaryText)
                                        .background((store.selectedRuntime == runtime ? VQTheme.accent : VQTheme.steel).opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(runtime.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(VQTheme.ink)
                                        Text(runtime.contextModeDescription)
                                            .font(.caption)
                                            .foregroundStyle(VQTheme.secondaryText)
                                    }
                                    Spacer()
                                    StatusPill(
                                        title: store.selectedRuntime == runtime ? "Selected" : "Available",
                                        tint: store.selectedRuntime == runtime ? VQTheme.green : VQTheme.steel
                                    )
                                }
                                .padding(10)
                                .background(store.selectedRuntime == runtime ? VQTheme.accent.opacity(0.08) : VQTheme.control.opacity(0.30))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        KeyValueLine(key: "Direct mode", value: "Codex and Claude keep their own native history.")
                        KeyValueLine(key: "Hermes mode", value: "Project chats share Hermes memory across model changes.")
                    }
                }

                VQPanel("Paired Devices", systemImage: "iphone.gen3.radiowaves.left.and.right") {
                    VStack(alignment: .leading, spacing: 12) {
                        if store.remoteDevices.isEmpty {
                            Text(store.remoteHost.isPaired ? "No paired devices reported yet. Refresh the Host once it is reachable." : "Pair a Mac Host to list trusted iPhone/iPad clients.")
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                        }

                        ForEach(store.remoteDevices) { device in
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: device.id == store.remoteHost.deviceID ? "iphone.gen3" : "rectangle.connected.to.line.below")
                                    .foregroundStyle(device.lastSeenAt == nil ? VQTheme.secondaryText : VQTheme.accent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(device.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("Last seen \(dateLabel(device.lastSeenAt))")
                                        .font(.caption)
                                        .foregroundStyle(VQTheme.secondaryText)
                                    Text(device.id)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(VQTheme.secondaryText)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    store.revokeRemoteDevice(device)
                                } label: {
                                    Label(device.id == store.remoteHost.deviceID ? "Unpair" : "Revoke", systemImage: "xmark.circle")
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                            }
                            if device.id != store.remoteDevices.last?.id {
                                EmptyDivider()
                            }
                        }
                    }
                }

                VQPanel("Host Audit", systemImage: "list.bullet.rectangle") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            StatusPill(title: "\(store.remoteAuditLines.count) events", tint: VQTheme.steel)
                            Spacer()
                            Button(action: store.refreshRemoteHostStatus) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                            .font(.footnote.weight(.semibold))
                            .disabled(!store.remoteHost.isPaired)
                        }

                        if store.remoteAuditLines.isEmpty {
                            Text("No audit events loaded yet.")
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                        }

                        ForEach(Array(store.remoteAuditLines.suffix(8).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption.monospaced())
                                .foregroundStyle(VQTheme.secondaryText)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VQPanel("Mac Host Pairing", systemImage: "qrcode.viewfinder") {
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 54, weight: .light))
                            .foregroundStyle(VQTheme.accent)
                            .frame(width: 132, height: 132)
                            .background(VQTheme.control.opacity(0.62))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(VQTheme.hairline, lineWidth: 1)
                            }

                        VStack(alignment: .leading, spacing: 12) {
                            KeyValueLine(key: "Saved endpoint", value: store.remoteHost.displayEndpoint)
                            KeyValueLine(key: "Current state", value: remoteStatusTitle)
                            KeyValueLine(key: "Transport", value: "Tailscale WebSocket")
                            KeyValueLine(key: "Host app", value: "Use the Mac Host pairing QR or deep link")
                            Text("Pairing codes are generated by the running Mac Host and rotate after successful pairing. Paste the Host endpoint and current code above if the QR deep link is unavailable.")
                                .font(.caption)
                                .foregroundStyle(VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Button(action: store.refreshRemoteHostStatus) {
                                    Label("Refresh Host", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                                .disabled(!store.remoteHost.isPaired)
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

    private var remoteOnline: Bool {
        store.remoteHost.isEnabled && store.remoteHost.isPaired && store.remoteHostHealth?.status == "ok"
    }

    private var remoteStatusTitle: String {
        if remoteOnline { return "Online" }
        if store.remoteHost.isEnabled && store.remoteHost.isPaired { return "Offline" }
        return "Not Paired"
    }

    private func dateLabel(_ date: Date?) -> String {
        guard let date else { return "Never" }
        return Self.deviceDateFormatter.string(from: date)
    }

    private static let deviceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct ToolDiagnosticRow: View {
    let status: RemoteCLIToolStatus

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .frame(width: 28, height: 28)
                .foregroundStyle(tint)
                .background(tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(status.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    StatusPill(title: status.isInstalled ? "Installed" : "Missing", tint: status.isInstalled ? VQTheme.green : VQTheme.amber)
                    StatusPill(title: status.isKnownCompatible ? "Adapter OK" : "Check Adapter", tint: status.isKnownCompatible ? VQTheme.green : VQTheme.amber)
                    Spacer(minLength: 0)
                }
                Text(status.versionSummary)
                    .font(.caption.monospaced())
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(2)
                Text(status.compatibilityNote)
                    .font(.caption)
                    .foregroundStyle(status.isKnownCompatible ? VQTheme.secondaryText : VQTheme.amber)
                    .fixedSize(horizontal: false, vertical: true)
                if let commandShape = status.commandShape, !commandShape.isEmpty {
                    Text(commandShape)
                        .font(.caption2.monospaced())
                        .foregroundStyle(VQTheme.secondaryText)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private var tint: Color {
        if !status.isInstalled { return VQTheme.amber }
        return status.isKnownCompatible ? VQTheme.green : VQTheme.amber
    }

    private var iconName: String {
        switch status.engine {
        case "codex":
            return "terminal"
        case "claude":
            return "bubble.left.and.text.bubble.right"
        default:
            return "point.3.connected.trianglepath.dotted"
        }
    }
}

struct ProjectsView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var newChatTitle = ""

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
                    FlowLayout(items: ["Hermes Project", "Codex Direct", "Claude Direct", "Approvals", "Git Diff"])
                }
            }

            VQPanel("Hermes Projects", systemImage: "sparkles.rectangle.stack") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        StatusPill(title: "Unified memory", tint: VQTheme.green)
                        StatusPill(title: store.selectedHermesChoiceTitle.isEmpty ? "Hermes Auto" : store.selectedHermesChoiceTitle, tint: VQTheme.accent)
                        Spacer()
                        Button {
                            store.useCurrentWorkspaceForHermes()
                        } label: {
                            Label("Use Current Folder", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                    }
                    .font(.footnote.weight(.semibold))

                    if store.agentProjects.isEmpty {
                        Text("Select a folder on Mac or use the current workspace to create the first Hermes project.")
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                    }

                    ForEach(store.agentProjects) { project in
                        Button {
                            store.selectAgentProject(project)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(project.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(VQTheme.ink)
                                    Spacer()
                                    StatusPill(
                                        title: store.selectedAgentProject?.id == project.id ? "Selected" : "\(project.chats.count) chats",
                                        tint: store.selectedAgentProject?.id == project.id ? VQTheme.green : VQTheme.steel
                                    )
                                }
                                Text(project.workingDirectory)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(VQTheme.secondaryText)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(10)
                            .background(store.selectedAgentProject?.id == project.id ? VQTheme.accent.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VQPanel("Hermes Chats", systemImage: "bubble.left.and.text.bubble.right") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        TextField("New chat title", text: $newChatTitle)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            store.createHermesChat(title: newChatTitle)
                            newChatTitle = ""
                        } label: {
                            Label("New Chat", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                    }

                    if store.selectedAgentProject?.chats.isEmpty != false {
                        Text("Create a chat to run Hermes inside the selected project. Separate chats can use different models while Hermes keeps project memory.")
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                    }

                    ForEach(store.selectedAgentProject?.chats ?? []) { chat in
                        Button {
                            store.selectAgentChat(chat)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "message.badge.waveform")
                                    .foregroundStyle(store.selectedAgentChat?.id == chat.id ? VQTheme.accent : VQTheme.secondaryText)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(chat.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(VQTheme.ink)
                                    Text(chat.sessionID ?? "New Hermes session")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(VQTheme.secondaryText)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                StatusPill(title: chat.model.isEmpty ? chat.provider : chat.model, tint: VQTheme.accent)
                            }
                            .padding(10)
                            .background(store.selectedAgentChat?.id == chat.id ? VQTheme.accent.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        Button {
                            store.submitHermesProjectCommand()
                        } label: {
                            Label("Send to Selected Chat", systemImage: "paperplane")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .disabled(store.commandDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer()
                        Text("Uses Command draft")
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                }
            }
        }
        .onAppear(perform: store.ensureAgentProjectForCurrentWorkspace)
    }
}

struct AgentsView: View {
    @EnvironmentObject private var store: CommandCenterStore
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
                VQPanel("Hermes Runtime", systemImage: "sparkles") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Default implementer")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            StatusPill(title: store.remoteHost.isPaired ? "Remote Ready" : "Needs Host", tint: store.remoteHost.isPaired ? VQTheme.green : VQTheme.amber)
                        }
                        KeyValueLine(key: "Model path", value: "Hermes -> configured CLI tools")
                        KeyValueLine(key: "Device", value: store.remoteHost.isPaired ? store.remoteHost.displayEndpoint : store.workspace.deviceName)
                        FlowLayout(items: ["Terminal", "Files", "Memory", "Browser", "Approval gate"])
                    }
                }

                VQPanel("Direct CLI Agents", systemImage: "rectangle.3.group.bubble.left") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Native sessions")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            StatusPill(title: store.remoteHost.isPaired ? "Host Ready" : "Needs Host", tint: store.remoteHost.isPaired ? VQTheme.green : VQTheme.amber)
                        }
                        KeyValueLine(key: "Codex", value: "~/.codex sessions, resumable from History")
                        KeyValueLine(key: "Claude", value: "~/.claude sessions, resumable from History")
                        FlowLayout(items: ["Siloed memory", "Read-only history", "PTY stream", "Cancel/resume"])
                    }
                }

                VQPanel("Local Shell", systemImage: "terminal") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Read-only and approved commands")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            StatusPill(title: store.workspace.canRunLocalCommands ? "Mac Ready" : "iOS Remote Only", tint: store.workspace.canRunLocalCommands ? VQTheme.green : VQTheme.amber)
                        }
                        KeyValueLine(key: "Workspace", value: store.workspace.workingDirectory)
                        KeyValueLine(key: "Git", value: store.workspace.statusSummary)
                        FlowLayout(items: ["Status", "Diff", "Build", "GitHub"])
                    }
                }

                if store.remoteDevices.isEmpty {
                    VQPanel("Paired Devices", systemImage: "iphone.gen3.radiowaves.left.and.right") {
                        Text(store.remoteHost.isPaired ? "Refresh the Host to load paired devices." : "Pair iPhone or iPad with Mac Host to show trusted devices.")
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                } else {
                    ForEach(store.remoteDevices) { device in
                        VQPanel(device.name, systemImage: "iphone.gen3") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(device.id == store.remoteHost.deviceID ? "Current device" : "Trusted client")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    StatusPill(title: device.lastSeenAt == nil ? "Paired" : "Seen", tint: device.lastSeenAt == nil ? VQTheme.amber : VQTheme.green)
                                }
                                KeyValueLine(key: "Device ID", value: device.id)
                                KeyValueLine(key: "Last seen", value: device.lastSeenAt.map(Self.deviceDateFormatter.string(from:)) ?? "Never")
                            }
                        }
                    }
                }
            }
        }
    }

    private static let deviceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
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
                ForEach(CommandRuntime.allCases) { runtime in
                    VQPanel(runtime.title, systemImage: runtime.symbol) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(runtime.contextModeDescription)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(VQTheme.ink)
                                    Text(runtime == store.selectedRuntime ? "Selected runtime" : "Available runtime")
                                        .font(.caption)
                                        .foregroundStyle(VQTheme.secondaryText)
                                }
                                Spacer()
                                StatusPill(title: runtime == .hermesAgent && store.remoteHost.isPaired ? "Mac Host" : store.workspace.deviceName, tint: VQTheme.accent)
                            }

                            HStack(spacing: 8) {
                                ModelTrait(label: "Execution", value: runtime.usesRemoteAgent ? "Mac Host" : "Local", tint: runtime.usesRemoteAgent ? VQTheme.accent : VQTheme.steel)
                                ModelTrait(label: "Approvals", value: "Host gated", tint: VQTheme.amber)
                                ModelTrait(label: "Context", value: runtime == .hermesAgent ? "Unified" : "Siloed", tint: runtime == .hermesAgent ? VQTheme.green : VQTheme.steel)
                            }

                            Text(runtimeDescription(runtime))
                                .font(.caption)
                                .foregroundStyle(VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            FlowLayout(items: runtimeTraits(runtime))
                        }
                    }
                }
            }

            VQPanel("Hermes Provider Routing", systemImage: "slider.horizontal.3") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Model", selection: Binding(
                        get: { store.selectedHermesProvider + "|" + store.selectedHermesModel },
                        set: { value in
                            let parts = value.split(separator: "|", maxSplits: 1).map(String.init)
                            let choice = HermesModelChoice.defaults.first { $0.provider == parts.first && $0.model == (parts.count > 1 ? parts[1] : "") }
                            if let choice {
                                store.selectHermesModel(choice)
                            }
                        }
                    )) {
                        ForEach(HermesModelChoice.defaults) { choice in
                            Text(choice.title).tag(choice.provider + "|" + choice.model)
                        }
                    }
                    .pickerStyle(.segmented)

                    KeyValueLine(key: "Provider", value: store.selectedHermesProvider)
                    KeyValueLine(key: "Model", value: store.selectedHermesModel.isEmpty ? "Hermes default" : store.selectedHermesModel)
                    Text("Only Hermes mode uses provider routing here. Codex and Claude direct modes keep their own CLI model/profile settings.")
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
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

    private func runtimeDescription(_ runtime: CommandRuntime) -> String {
        switch runtime {
        case .hermesAgent:
            "Uses Hermes native memory, skills, checkpoints, and provider routing on the paired Mac Host."
        case .codexDirect:
            "Spawns Codex CLI directly and resumes Codex sessions from ~/.codex without going through Hermes."
        case .claudeDirect:
            "Spawns Claude Code directly and resumes Claude sessions from ~/.claude without going through Hermes."
        case .localShell:
            "Runs local shell commands only where local command execution is available."
        }
    }

    private func runtimeTraits(_ runtime: CommandRuntime) -> [String] {
        switch runtime {
        case .hermesAgent:
            ["Hermes memory", "Provider routing", "Skills", "Worktree", "PTY stream"]
        case .codexDirect:
            ["Codex CLI", "~/.codex", "Resume", "Siloed"]
        case .claudeDirect:
            ["Claude Code", "~/.claude", "Resume", "Siloed"]
        case .localShell:
            ["Shell", "Git", "Build", "Diff"]
        }
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

                    CommandAttachmentControls()

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
                    ReviewNote(symbol: "antenna.radiowaves.left.and.right", text: "Mac Host can now stream Hermes logs and sync run diffs over the remote transport.")
                    ReviewNote(symbol: "arrow.triangle.2.circlepath", text: "Diff summaries are populated from the paired Host when a remote run is available.")
                }
            }
        }
    }
}

struct ArtifactsView: View {
    @EnvironmentObject private var store: CommandCenterStore
    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 14)]

    var body: some View {
        ScreenScaffold(title: "Artifacts", systemImage: "shippingbox") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                if store.remoteArtifacts.isEmpty {
                    VQPanel("No Artifacts", systemImage: "shippingbox") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Artifacts appear here after a real Mac Host run produces files or receives image attachments from iOS.")
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            if store.remoteHost.isPaired {
                                Button(action: store.refreshRemoteHostStatus) {
                                    Label("Refresh Host", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                            }
                        }
                    }
                } else {
                    ForEach(store.remoteArtifacts) { artifact in
                        VQPanel(artifact.title, systemImage: symbol(for: artifact.type)) {
                            VStack(alignment: .leading, spacing: 12) {
                                ZStack {
                                    Rectangle()
                                        .fill(VQTheme.steel.opacity(0.08))
                                    Image(systemName: symbol(for: artifact.type))
                                        .font(.system(size: 44, weight: .light))
                                        .foregroundStyle(VQTheme.accent)
                                }
                                .frame(height: 118)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                KeyValueLine(key: "Type", value: artifact.type.uppercased())
                                KeyValueLine(key: "Source", value: artifact.path)
                                KeyValueLine(key: "Size", value: byteLabel(artifact.bytes))
                                StatusPill(title: "Synced from Host", tint: VQTheme.green)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if store.remoteHost.isEnabled, store.remoteHost.isPaired {
                store.refreshRemoteHostStatus()
            }
        }
    }

    private func symbol(for type: String) -> String {
        switch type.lowercased() {
        case "png", "jpg", "jpeg", "gif":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "html", "htm":
            return "safari"
        case "json":
            return "curlybraces.square"
        case "log", "txt":
            return "doc.text"
        case "md":
            return "text.alignleft"
        default:
            return "shippingbox"
        }
    }

    private func byteLabel(_ bytes: Int) -> String {
        if bytes >= 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        }
        if bytes >= 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        }
        return "\(bytes) B"
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var toolFilter = "all"
    @State private var projectFilter = "all"
    @State private var searchText = ""
    @State private var dateFilter = ""

    var body: some View {
        ScreenScaffold(title: "History", systemImage: "clock.arrow.circlepath") {
            VQPanel("Filters", systemImage: "line.3.horizontal.decrease.circle") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Picker("Tool", selection: $toolFilter) {
                            Text("All").tag("all")
                            Text("Claude").tag(RemoteHistoryTool.claude.rawValue)
                            Text("Codex").tag(RemoteHistoryTool.codex.rawValue)
                        }
                        .pickerStyle(.segmented)

                        Button(action: refresh) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                    }

                    HStack(spacing: 10) {
                        Picker("Project", selection: $projectFilter) {
                            Text("All Projects").tag("all")
                            ForEach(store.remoteHistoryProjects, id: \.self) { project in
                                Text(project).tag(project)
                            }
                        }
                        .frame(maxWidth: 260)

                        TextField("Search prompts, tools, output", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(refresh)

                        TextField("YYYY-MM-DD", text: $dateFilter)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 132)
                            .onSubmit(refresh)
                    }

                    if !store.remoteHistoryMessage.isEmpty {
                        Text(store.remoteHistoryMessage)
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                }
            }

            VQPanel("Sessions", systemImage: "tablecells") {
                VStack(alignment: .leading, spacing: 0) {
                    HistoryHeaderRow()
                    EmptyDivider()

                    if store.isLoadingRemoteHistory, store.remoteHistorySessions.isEmpty {
                        ProgressView()
                            .padding(.vertical, 18)
                    } else if store.remoteHistorySessions.isEmpty {
                        Text(store.remoteHost.isPaired ? "No Claude or Codex sessions matched this filter." : "Pair with Mac Host to read Claude/Codex history.")
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(store.remoteHistorySessions) { session in
                            Button {
                                store.loadRemoteHistoryDetail(session)
                            } label: {
                                HistorySessionRow(session: session, isSelected: store.selectedHistorySession?.id == session.id)
                            }
                            .buttonStyle(.plain)
                            EmptyDivider()
                        }
                    }
                }
            }

            VQPanel("Session Detail", systemImage: "text.bubble") {
                if let session = store.selectedHistorySession {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.summary)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(VQTheme.ink)
                                    .lineLimit(2)
                                Text(session.filePath)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(VQTheme.secondaryText)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button {
                                store.continueHistorySession(session)
                            } label: {
                                Label("Continue", systemImage: "arrowshape.turn.up.right")
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                            StatusPill(title: "\(store.remoteHistoryTurns.count) turns", tint: VQTheme.accent)
                        }

                        if store.remoteHistoryTurns.isEmpty, store.isLoadingRemoteHistory {
                            ProgressView()
                                .padding(.vertical, 18)
                        } else if store.remoteHistoryTurns.isEmpty {
                            Text("Select a session to load turns.")
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(store.remoteHistoryTurns) { turn in
                                    HistoryTurnView(turn: turn)
                                }
                            }
                        }
                    }
                } else {
                    Text("Select a Claude or Codex session from the table.")
                        .font(.subheadline)
                        .foregroundStyle(VQTheme.secondaryText)
                }
            }
        }
        .onAppear {
            if store.remoteHistorySessions.isEmpty {
                refresh()
            }
        }
    }

    private func refresh() {
        let tool = RemoteHistoryTool(rawValue: toolFilter)
        store.refreshRemoteHistory(
            tool: tool,
            project: projectFilter == "all" ? nil : projectFilter,
            query: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            date: dateFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

private struct HistoryHeaderRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Tool").frame(width: 72, alignment: .leading)
            Text("Project").frame(width: 140, alignment: .leading)
            Text("Started").frame(width: 150, alignment: .leading)
            Text("Turns").frame(width: 56, alignment: .trailing)
            Text("Prompt / Summary").frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(VQTheme.secondaryText)
        .padding(.vertical, 6)
    }
}

private struct HistorySessionRow: View {
    let session: RemoteHistorySession
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            StatusPill(title: session.tool.title, tint: session.tool == .claude ? VQTheme.violet : VQTheme.green)
                .frame(width: 72, alignment: .leading)
            Text(session.project)
                .frame(width: 140, alignment: .leading)
                .lineLimit(1)
            Text(session.startedAt.map(Self.dateFormatter.string(from:)) ?? "Unknown")
                .font(.caption.monospaced())
                .foregroundStyle(VQTheme.secondaryText)
                .frame(width: 150, alignment: .leading)
            Text("\(session.messageCount)")
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(VQTheme.ink)
                .frame(width: 56, alignment: .trailing)
            VStack(alignment: .leading, spacing: 3) {
                Text(session.summary)
                    .font(.subheadline)
                    .foregroundStyle(VQTheme.ink)
                    .lineLimit(1)
                Text(session.model ?? session.projectPath)
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(isSelected ? VQTheme.accent.opacity(0.10) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct HistoryTurnView: View {
    let turn: RemoteHistoryTurn
    @State private var expanded = false

    private var isTool: Bool {
        turn.role == "tool" || turn.kind != "message"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StatusPill(title: turn.role.capitalized, tint: tint)
                Text(turn.timestamp.map(Self.dateFormatter.string(from:)) ?? "")
                    .font(.caption2.monospaced())
                    .foregroundStyle(VQTheme.secondaryText)
                Spacer()
                if isTool {
                    Button(expanded ? "Collapse" : "Expand") {
                        expanded.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.accent)
                }
            }

            Text(displayText)
                .font(isTool ? .caption.monospaced() : .subheadline)
                .foregroundStyle(isTool ? VQTheme.secondaryText : VQTheme.ink)
                .lineLimit(isTool && !expanded ? 4 : nil)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(VQTheme.elevated.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VQTheme.hairline, lineWidth: 1)
        }
    }

    private var displayText: String {
        turn.text.isEmpty ? "(empty)" : turn.text
    }

    private var tint: Color {
        switch turn.role {
        case "user":
            return VQTheme.accent
        case "assistant":
            return VQTheme.green
        default:
            return VQTheme.amber
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()
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
                    Text("Use Hermes Memory Files above to load live USER.md, MEMORY.md, and skills from the paired Mac Host.")
                        .font(.subheadline)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VQPanel("Context Package", systemImage: "archivebox") {
                FlowLayout(items: ContextPackage.items)
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
                    HStack(spacing: 8) {
                        StatusPill(title: store.remoteHost.isPaired ? "Mac Host" : "Local Snapshot", tint: store.remoteHost.isPaired ? VQTheme.green : VQTheme.amber)
                        StatusPill(title: github.ghAuthenticated ? "gh auth OK" : "gh auth needed", tint: github.ghAuthenticated ? VQTheme.green : VQTheme.amber)
                        Spacer()
                    }

                    GitHubStep(title: "Branch", value: branchLabel, status: branchLabel == "No branch" ? "Missing" : "Ready", tint: branchLabel == "No branch" ? VQTheme.amber : VQTheme.green)
                    GitHubStep(title: "Working Tree", value: workingTreeLabel, status: changedFiles == 0 ? "Clean" : "Dirty", tint: changedFiles == 0 ? VQTheme.green : VQTheme.amber)
                    GitHubStep(title: "Pull Request", value: github.pullRequestURL.isEmpty ? "Not opened" : github.pullRequestURL, status: github.pullRequestState, tint: github.pullRequestURL.isEmpty ? VQTheme.secondaryText : VQTheme.accent)
                    GitHubStep(title: "CI", value: github.checksSummary, status: github.checksSummary.localizedCaseInsensitiveContains("failing") ? "Failing" : "Status", tint: github.checksSummary.localizedCaseInsensitiveContains("failing") ? VQTheme.red : VQTheme.secondaryText)
                    GitHubStep(title: "Deploy", value: "Approval required", status: "Locked", tint: VQTheme.red)

                    HStack(spacing: 8) {
                        Button(action: store.refreshGitHubStatus) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .disabled(!store.remoteHost.isPaired)

                        Button(action: store.createDraftPRFromHost) {
                            Label("Create Draft PR", systemImage: "plus.square.on.square")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .disabled(!store.remoteHost.isPaired || branchLabel == "No branch")
                    }
                    .font(.footnote.weight(.semibold))
                }
            }

            VQPanel("Repository", systemImage: "tray.full") {
                VStack(alignment: .leading, spacing: 12) {
                    KeyValueLine(key: "Remote", value: github.remote.isEmpty ? store.workspace.remoteLabel : github.remote)
                    KeyValueLine(key: "Git root", value: github.gitRoot.isEmpty ? store.workspace.rootPath : github.gitRoot)
                    KeyValueLine(key: "Ahead/behind", value: github.aheadBehind.isEmpty ? "No upstream data" : github.aheadBehind)
                    KeyValueLine(key: "Review mode", value: "Branch + commit + draft PR automatic, merge/deploy approval")
                    if let error = github.error, !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(VQTheme.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !store.remoteHostMessage.isEmpty {
                        Text(store.remoteHostMessage)
                            .font(.caption)
                            .foregroundStyle(store.remoteHostMessage.localizedCaseInsensitiveContains("failed") ? VQTheme.amber : VQTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .onAppear {
            if store.remoteHost.isEnabled, store.remoteHost.isPaired {
                store.refreshGitHubStatus()
            }
        }
    }

    private var github: RemoteGitHubStatus {
        store.remoteGitHubStatus
    }

    private var branchLabel: String {
        if !github.branch.isEmpty { return github.branch }
        return store.workspace.branchLabel
    }

    private var changedFiles: Int {
        github.gitRoot.isEmpty ? store.workspace.changedFiles : github.changedFiles
    }

    private var workingTreeLabel: String {
        changedFiles == 0 ? "Clean" : "\(changedFiles) changed files"
    }
}

struct InspectorView: View {
    @EnvironmentObject private var store: CommandCenterStore

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
                    if let run = store.selectedRun {
                        CommandRunListRow(run: run, isSelected: true)
                    } else {
                        Text("No run selected.")
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                }

                VQPanel("Context", systemImage: "archivebox") {
                    FlowLayout(items: ContextPackage.items)
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
                        if store.remoteDevices.isEmpty {
                            Text("No paired devices loaded.")
                                .font(.caption)
                                .foregroundStyle(VQTheme.secondaryText)
                        }
                        ForEach(store.remoteDevices.prefix(3)) { device in
                            HStack {
                                Circle()
                                    .fill(device.lastSeenAt == nil ? VQTheme.amber : VQTheme.green)
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

private struct OrganizationGraph: View {
    var body: some View {
        VStack(spacing: 14) {
            AgentNode(name: "Command", role: "iPhone/iPad", tint: VQTheme.accent)
            Rectangle()
                .fill(VQTheme.hairline)
                .frame(width: 1, height: 18)
            HStack(spacing: 10) {
                AgentNode(name: "Mac Host", role: "Tailscale", tint: VQTheme.green)
                AgentNode(name: "Hermes", role: "Agent", tint: VQTheme.amber)
                AgentNode(name: "Codex", role: "CLI", tint: VQTheme.violet)
            }
            Rectangle()
                .fill(VQTheme.hairline)
                .frame(width: 1, height: 18)
            AgentNode(name: "Outputs", role: "Logs/Diff", tint: VQTheme.ink)
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
