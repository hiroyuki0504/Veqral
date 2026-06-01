import SwiftUI
import UIKit
import AVFoundation

struct PortfolioView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var kindFilter: PortfolioAssetKind?
    @State private var statusFilter: PortfolioAssetStatus?
    @State private var isShowingAddAsset = false
    @State private var draftAsset = PortfolioAsset.empty()
    @State private var editorTitle = "Add Asset"

    private var filteredAssets: [PortfolioAsset] {
        store.portfolioAssets.filter { asset in
            (kindFilter == nil || asset.kind == kindFilter) &&
            (statusFilter == nil || asset.status == statusFilter)
        }
    }

    var body: some View {
        ScreenScaffold(title: "Portfolio", systemImage: "rectangle.3.group") {
            portfolioHeader
            filters
            assetGrid
            selectedAssetDetail
        }
        .onAppear {
            if store.portfolioAssets.isEmpty {
                store.refreshPortfolio()
            }
        }
        .sheet(isPresented: $isShowingAddAsset) {
            PortfolioAssetEditor(asset: $draftAsset, title: editorTitle) {
                store.savePortfolioAsset(draftAsset)
                isShowingAddAsset = false
                draftAsset = PortfolioAsset.empty()
                editorTitle = "Add Asset"
            }
            .presentationDetents([.large])
        }
    }

    private var portfolioHeader: some View {
        VQPanel("Portfolio Overview", systemImage: "rectangle.3.group", actionImage: "arrow.clockwise") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatusPill(title: "\(store.portfolioAssets.count) \(L10n.tr("assets"))", tint: VQTheme.accent)
                    StatusPill(title: "\(store.portfolioAssets.filter { $0.status == .running }.count) \(L10n.tr("running"))", tint: VQTheme.green)
                    StatusPill(title: "\(store.portfolioAssets.filter { $0.status == .stopped }.count) \(L10n.tr("stopped"))", tint: VQTheme.amber)
                    Spacer()
                }
                HStack(spacing: 8) {
                    Button(action: store.refreshPortfolio) {
                        Label(L10n.tr("Refresh"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 8))

                    Button(action: store.discoverPortfolio) {
                        Label(L10n.tr("Discover"), systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 8))

                    Button {
                        draftAsset = PortfolioAsset.empty()
                        editorTitle = "Add Asset"
                        isShowingAddAsset = true
                    } label: {
                        Label(L10n.tr("Add"), systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 8))
                    Spacer()
                }
                if !store.portfolioMessage.isEmpty {
                    Text(store.portfolioMessage)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var filters: some View {
        VQPanel("Filters", systemImage: "line.3.horizontal.decrease.circle") {
            VStack(alignment: .leading, spacing: 10) {
                Picker(L10n.tr("Kind"), selection: $kindFilter) {
                    Text(L10n.tr("All")).tag(nil as PortfolioAssetKind?)
                    ForEach(PortfolioAssetKind.allCases) { kind in
                        Text(kind.title).tag(kind as PortfolioAssetKind?)
                    }
                }
                .pickerStyle(.segmented)

                Picker(L10n.tr("Status"), selection: $statusFilter) {
                    Text(L10n.tr("All")).tag(nil as PortfolioAssetStatus?)
                    ForEach(PortfolioAssetStatus.allCases) { status in
                        Text(status.title).tag(status as PortfolioAssetStatus?)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var assetGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], alignment: .leading, spacing: 12) {
            if filteredAssets.isEmpty {
                VQPanel("Assets", systemImage: "tray") {
                    Text(store.remoteHost.isPaired ? L10n.tr("No assets registered yet.") : L10n.tr("Mac Host pairing is required."))
                        .font(.subheadline)
                        .foregroundStyle(VQTheme.secondaryText)
                }
            }
            ForEach(filteredAssets) { asset in
                Button {
                    store.selectPortfolioAsset(asset)
                } label: {
                    PortfolioAssetCard(asset: asset, isSelected: store.selectedPortfolioAsset?.id == asset.id)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var selectedAssetDetail: some View {
        if let asset = store.selectedPortfolioAsset {
            VQPanel(asset.name.isEmpty ? L10n.tr("Asset Detail") : asset.name, systemImage: asset.kind.symbol) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        StatusPill(title: asset.kind.title, tint: VQTheme.steel)
                        StatusPill(title: (store.selectedPortfolioStatus?.status ?? asset.status).title, tint: tint(for: store.selectedPortfolioStatus?.status ?? asset.status))
                        StatusPill(title: asset.backupState == .git ? "Git" : L10n.tr("Local only"), tint: asset.backupState == .git ? VQTheme.green : VQTheme.steel)
                        Spacer()
                        Button {
                            draftAsset = asset
                            editorTitle = "Edit Asset"
                            isShowingAddAsset = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        Button(action: store.refreshSelectedPortfolioDetail) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                    }

                    if !asset.summary.isEmpty {
                        Text(asset.summary)
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 7) {
                        KeyValueLine(key: "Health", value: store.selectedPortfolioStatus?.health ?? L10n.tr("Not checked"))
                        KeyValueLine(key: "Machine", value: asset.runtimeHost ?? L10n.tr("This Mac"))
                        KeyValueLine(key: "Repository", value: asset.sourceRefs.github ?? L10n.tr("Not set"))
                        if let driveURL = asset.sourceRefs.driveUrl?.vqNilIfBlank {
                            KeyValueLine(key: "Drive", value: driveURL)
                        }
                        if let cpu = store.selectedPortfolioStatus?.cpuPercent {
                            KeyValueLine(key: "CPU", value: String(format: "%.1f%%", cpu))
                        }
                        if let memory = store.selectedPortfolioStatus?.memoryMB {
                            KeyValueLine(key: "Memory", value: String(format: "%.1f MB", memory))
                        }
                    }

                    if asset.kind == .engagement {
                        PortfolioEngagementPanel(asset: asset, assets: store.portfolioAssets)
                    }

                    PortfolioRecentCommitsPanel(commits: store.portfolioCommits)

                    PortfolioControlPanel(asset: asset)

                    VQPanel("Live Logs", systemImage: "terminal") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Button(action: store.summarizePortfolioLogs) {
                                    Label(L10n.tr("Summarize"), systemImage: "sparkles")
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                                Spacer()
                            }
                            if !store.portfolioLogSummary.isEmpty {
                                Text(store.portfolioLogSummary)
                                    .font(.caption)
                                    .foregroundStyle(VQTheme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(Array(store.portfolioLogLines.suffix(12).enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(VQTheme.secondaryText)
                                        .lineLimit(3)
                                }
                                if store.portfolioLogLines.isEmpty {
                                    Text(L10n.tr("No logs loaded yet."))
                                        .font(.caption)
                                        .foregroundStyle(VQTheme.secondaryText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    HStack {
                        Button(action: store.linkSelectedPortfolioAssetToProject) {
                            Label(asset.linkedProjectId == nil ? L10n.tr("Create Project Link") : L10n.tr("Open Project"), systemImage: "sparkles.rectangle.stack")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))

                        if asset.backupState == .localOnly {
                            Button(action: store.promotePortfolioAsset) {
                                Label(L10n.tr("Private Repo"), systemImage: "arrow.up.right.square")
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private func tint(for status: PortfolioAssetStatus) -> Color {
        switch status {
        case .running: VQTheme.green
        case .stopped: VQTheme.amber
        case .unknown, .notApplicable: VQTheme.unavailable
        }
    }
}

private struct PortfolioAssetCard: View {
    let asset: PortfolioAsset
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: asset.kind.symbol)
                    .frame(width: 30, height: 30)
                    .foregroundStyle(isSelected ? VQTheme.accent : VQTheme.secondaryText)
                    .background(VQTheme.control.opacity(0.48))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Spacer()
                StatusPill(title: asset.status.title, tint: tint(for: asset.status))
            }
            Text(asset.name.isEmpty ? L10n.tr("Untitled") : asset.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VQTheme.ink)
                .lineLimit(2)
            Text(asset.summary.isEmpty ? asset.kind.title : asset.summary)
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
                .lineLimit(2)
            FlowLayout(items: Array(asset.tags.prefix(4)) + [asset.runtimeHost ?? L10n.tr("This Mac")])
        }
        .padding(12)
        .background(isSelected ? VQTheme.accent.opacity(0.09) : VQTheme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? VQTheme.accent.opacity(0.45) : VQTheme.hairline, lineWidth: 1)
        }
    }

    private func tint(for status: PortfolioAssetStatus) -> Color {
        switch status {
        case .running: VQTheme.green
        case .stopped: VQTheme.amber
        case .unknown, .notApplicable: VQTheme.unavailable
        }
    }
}

private struct PortfolioControlPanel: View {
    @EnvironmentObject private var store: CommandCenterStore
    let asset: PortfolioAsset

    var body: some View {
        VQPanel("Controls", systemImage: "switch.2") {
            HStack(spacing: 8) {
                controlButton("start", title: "Start", symbol: "play")
                controlButton("stop", title: "Stop", symbol: "stop")
                controlButton("restart", title: "Restart", symbol: "arrow.clockwise")
                controlButton("deploy", title: "Deploy", symbol: "paperplane")
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func controlButton(_ action: String, title: String, symbol: String) -> some View {
        let command = asset.controls?.command(for: action)
        Button {
            store.runPortfolioControl(action)
        } label: {
            Label(L10n.tr(title), systemImage: symbol)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .disabled(command == nil)
    }
}

private struct PortfolioEngagementPanel: View {
    let asset: PortfolioAsset
    let assets: [PortfolioAsset]

    var body: some View {
        VQPanel("Engagement", systemImage: "person.text.rectangle") {
            VStack(alignment: .leading, spacing: 8) {
                KeyValueLine(key: "Client", value: asset.client ?? L10n.tr("Not set"))
                KeyValueLine(key: "Phase", value: asset.phase ?? L10n.tr("Not set"))
                if let timeline = asset.timeline?.vqNilIfBlank {
                    KeyValueLine(key: "Timeline", value: timeline)
                }
                if !asset.deliverables.isEmpty {
                    Text(L10n.tr("Deliverables"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VQTheme.secondaryText)
                    FlowLayout(items: asset.deliverables.map(\.name))
                }
                if !asset.relatedAssetIds.isEmpty {
                    Text(L10n.tr("Related Apps"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VQTheme.secondaryText)
                    FlowLayout(items: asset.relatedAssetIds.map(relatedAssetName))
                }
            }
        }
    }

    private func relatedAssetName(_ id: String) -> String {
        assets.first(where: { $0.id == id })?.name.vqNilIfBlank ?? L10n.tr("Unknown")
    }
}

private struct PortfolioRecentCommitsPanel: View {
    let commits: [PortfolioRecentCommit]

    var body: some View {
        VQPanel("Recent Commits", systemImage: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: 8) {
                if commits.isEmpty {
                    Text(L10n.tr("No recent commits"))
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                } else {
                    ForEach(commits) { commit in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(commit.message.components(separatedBy: .newlines).first ?? commit.message)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VQTheme.ink)
                                .lineLimit(2)
                            Text("\(commit.author) · \(commit.date.formatted(date: .abbreviated, time: .shortened)) · \(commit.shortSHA)")
                                .font(.caption2)
                                .foregroundStyle(VQTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct PortfolioAssetEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var asset: PortfolioAsset
    let title: String
    let onSave: () -> Void
    @State private var localPath = ""
    @State private var tags = ""
    @State private var driveURL = ""
    @State private var deliverables = ""
    @State private var relatedAssetIDs = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("Basics")) {
                    Picker(L10n.tr("Kind"), selection: $asset.kind) {
                        ForEach(PortfolioAssetKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    TextField(L10n.tr("Name"), text: $asset.name)
                    TextField(L10n.tr("Summary"), text: $asset.summary, axis: .vertical)
                    TextField(L10n.tr("Tags"), text: $tags)
                }

                Section(L10n.tr("Source")) {
                    TextField(L10n.tr("GitHub owner/repo"), text: Binding(
                        get: { asset.sourceRefs.github ?? "" },
                        set: { asset.sourceRefs.github = $0.vqNilIfBlank }
                    ))
                    TextField(L10n.tr("Drive URL"), text: $driveURL)
                    TextField(L10n.tr("Local folder"), text: $localPath)
                }

                Section(L10n.tr("Health")) {
                    TextField(L10n.tr("http / cmd"), text: Binding(
                        get: { asset.healthSpec?.type ?? "" },
                        set: { value in
                            let target = asset.healthSpec?.target ?? ""
                            asset.healthSpec = value.vqNilIfBlank.map { PortfolioHealthSpec(type: $0, target: target) }
                        }
                    ))
                    TextField(L10n.tr("Target"), text: Binding(
                        get: { asset.healthSpec?.target ?? "" },
                        set: { value in
                            let type = asset.healthSpec?.type ?? "http"
                            asset.healthSpec = value.vqNilIfBlank.map { PortfolioHealthSpec(type: type, target: $0) }
                        }
                    ))
                }

                Section(L10n.tr("Controls")) {
                    controlField("Start", keyPath: \.start)
                    controlField("Stop", keyPath: \.stop)
                    controlField("Restart", keyPath: \.restart)
                    controlField("Deploy", keyPath: \.deploy)
                }

                if asset.kind == .engagement {
                    Section(L10n.tr("Engagement")) {
                        TextField(L10n.tr("Client"), text: Binding(get: { asset.client ?? "" }, set: { asset.client = $0.vqNilIfBlank }))
                        TextField(L10n.tr("Phase"), text: Binding(get: { asset.phase ?? "" }, set: { asset.phase = $0.vqNilIfBlank }))
                        TextField(L10n.tr("Timeline"), text: Binding(get: { asset.timeline ?? "" }, set: { asset.timeline = $0.vqNilIfBlank }))
                        TextField(L10n.tr("Deliverables"), text: $deliverables)
                        TextField(L10n.tr("Related Apps"), text: $relatedAssetIDs)
                    }
                }
            }
            .navigationTitle(L10n.tr(title))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("Save")) {
                        applyFields()
                        onSave()
                    }
                    .disabled(asset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                localPath = asset.sourceRefs.localPaths.first?.path ?? ""
                tags = asset.tags.joined(separator: ", ")
                driveURL = asset.sourceRefs.driveUrl ?? ""
                deliverables = asset.deliverables.map { "\($0.name)=\($0.ref)" }.joined(separator: ", ")
                relatedAssetIDs = asset.relatedAssetIds.joined(separator: ", ")
            }
        }
    }

    private func controlField(_ title: String, keyPath: WritableKeyPath<PortfolioControls, String?>) -> some View {
        TextField(L10n.tr(title), text: Binding(
            get: { asset.controls?[keyPath: keyPath] ?? "" },
            set: { value in
                var controls = asset.controls ?? PortfolioControls(start: nil, stop: nil, restart: nil, deploy: nil)
                controls[keyPath: keyPath] = value.vqNilIfBlank
                asset.controls = controls
            }
        ))
    }

    private func applyFields() {
        asset.tags = tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        asset.sourceRefs.driveUrl = driveURL.vqNilIfBlank
        if let path = localPath.vqNilIfBlank {
            asset.sourceRefs.localPaths = [PortfolioLocalPath(machineId: ProcessInfo.processInfo.hostName, path: path)]
            if asset.sourceRefs.github == nil {
                asset.backupState = .localOnly
            }
        }
        asset.deliverables = deliverables.split(separator: ",").compactMap { item in
            let parts = item.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard let name = parts.first?.vqNilIfBlank else { return nil }
            let ref = parts.dropFirst().first?.vqNilIfBlank ?? name
            return PortfolioDeliverable(name: name, ref: ref)
        }
        asset.relatedAssetIds = relatedAssetIDs.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        asset.status = asset.kind == .content ? .notApplicable : asset.status
    }
}

private extension PortfolioAssetKind {
    var symbol: String {
        switch self {
        case .app: "app.connected.to.app.below.fill"
        case .engagement: "person.text.rectangle"
        case .content: "doc.richtext"
        }
    }
}

private extension PortfolioControls {
    func command(for action: String) -> String? {
        switch action {
        case "start": start?.vqNilIfBlank
        case "stop": stop?.vqNilIfBlank
        case "restart": restart?.vqNilIfBlank
        case "deploy": deploy?.vqNilIfBlank
        default: nil
        }
    }
}

private extension String {
    var vqNilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct DevicesView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var remoteEndpoint = ""
    @State private var remotePairingCode = ""
    @State private var remoteDeviceName = ProcessInfo.processInfo.hostName
    @State private var pairingURLInput = ""
    @State private var showPairingScanner = false
    @State private var scannerStatusMessage = ""
    @State private var remoteStatusMessage = ""
    @State private var isPairing = false
    private let columns = [GridItem(.adaptive(minimum: 320), spacing: 14)]

    var body: some View {
        ScreenScaffold(title: "Devices", systemImage: "macbook.and.iphone") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                VQPanel("Workspace", systemImage: "folder") {
                    VStack(alignment: .leading, spacing: 12) {
                        KeyValueLine(key: "Project", value: VQDisplay.workspaceName(store.workspace))
                        CompactKeyValueLine(key: "Git root", value: store.workspace.rootPath.isEmpty ? L10n.tr("Not detected") : store.workspace.rootPath, monospaced: true)
                        KeyValueLine(key: "Branch", value: store.workspace.branchLabel)
                        KeyValueLine(key: "State", value: VQDisplay.workspaceStatus(store.workspace))
                        CompactKeyValueLine(key: "Hermes path", value: store.workspace.hermesPath.isEmpty ? L10n.tr("Not detected") : store.workspace.hermesPath, monospaced: true)
                        KeyValueLine(key: "Tailscale", value: store.workspace.tailscaleIP.isEmpty ? L10n.tr("Not detected") : store.workspace.tailscaleIP)
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
                                tint: remoteStatusTint
                            )
                            StatusPill(title: "HMAC", tint: VQTheme.steel)
                            StatusPill(title: "Keychain", tint: VQTheme.green)
                            Spacer()
                        }

                        Text(remoteOnline ? L10n.tr("Ready for remote runs.") : L10n.tr("Scan the menu bar QR or paste the pairing link."))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(remoteOnline ? VQTheme.green : VQTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Button {
                                beginPairingScan()
                            } label: {
                                Label(L10n.tr("Scan QR"), systemImage: "qrcode.viewfinder")
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 8))

                            Button {
                                applyPairingURLInput()
                            } label: {
                                Label(L10n.tr("Use Link"), systemImage: "link")
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                            .disabled(pairingURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .font(.footnote.weight(.semibold))

                        RemoteConnectionField(title: L10n.tr("Pairing URL"), placeholder: "veqral://pair?endpoint=http://100.x.x.x:7878&code=ABCD1234", text: $pairingURLInput)
                        RemoteConnectionField(title: L10n.tr("Saved endpoint"), placeholder: store.workspace.macHostEndpoint, text: $remoteEndpoint)
                        RemoteConnectionField(title: L10n.tr("Pairing code"), placeholder: L10n.tr("8-character code from menu bar QR"), text: $remotePairingCode)
                        RemoteConnectionField(title: L10n.tr("This device name"), placeholder: "iPhone・iPad", text: $remoteDeviceName)

                        KeyValueLine(key: "Saved endpoint", value: VQDisplay.endpoint(store.remoteHost))
                        KeyValueLine(key: "Device ID", value: store.remoteHost.deviceID.isEmpty ? L10n.tr("Not Paired") : "\(store.remoteHost.deviceID.prefix(8))...")
                        KeyValueLine(key: "Tailscale", value: store.remoteHostHealth?.tailscaleIP ?? (store.workspace.tailscaleIP.isEmpty ? L10n.tr("Not verified") : store.workspace.tailscaleIP))
                        KeyValueLine(key: "Host", value: store.remoteHostHealth?.host ?? L10n.tr("Not connected"))
                        KeyValueLine(key: "Hermes", value: store.remoteHostHealth?.hermesVersion ?? L10n.tr("Not checked"))
                        KeyValueLine(key: "Push", value: store.pushNotificationMessage.isEmpty ? VeqralFeatureFlags.pushUnavailableMessage : store.pushNotificationMessage)
                        KeyValueLine(key: "Execution", value: store.remoteHost.isEnabled ? L10n.tr("iPhone/iPad -> Tailscale -> Mac Host -> Hermes") : L10n.tr("Pair a Mac Host before running on iPhone/iPad"))

                        HStack(spacing: 8) {
                            Button {
                                pairRemoteHost()
                            } label: {
                                Label(L10n.tr(isPairing ? "Pairing" : "Pair"), systemImage: "link.badge.plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                            .disabled(isPairing || remoteEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || remotePairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button {
                                store.disableRemoteHost()
                                remoteStatusMessage = L10n.tr("Remote Host disabled. Pairing data remains in Keychain.")
                            } label: {
                                Label(L10n.tr("Disable"), systemImage: "wifi.slash")
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 8))

                            Button {
                                store.refreshRemoteHostStatus()
                            } label: {
                                Label(L10n.tr(store.isRefreshingRemoteHost ? "Refreshing" : "Refresh Host"), systemImage: "arrow.clockwise")
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
                            Text(store.remoteHost.isPaired ? L10n.tr("Refresh the Mac Host to inspect Codex, Claude, and Hermes adapters.") : L10n.tr("Pair a Mac Host to inspect CLI versions."))
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VQPanel("Run Agent on This Mac", systemImage: "switch.2") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.tr("Choose which native agent the paired Mac Host should spawn for the next command."))
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

                        KeyValueLine(key: "Direct mode", value: L10n.tr("Codex and Claude keep their own native history."))
                        KeyValueLine(key: "Hermes mode", value: L10n.tr("Project chats share Hermes memory across model changes."))
                    }
                }

                VQPanel("Paired Devices", systemImage: "iphone.gen3.radiowaves.left.and.right") {
                    VStack(alignment: .leading, spacing: 12) {
                        let devices = store.visibleRemoteDevices
                        if devices.isEmpty {
                            Text(store.remoteHost.isPaired ? L10n.tr("No other paired devices yet.") : L10n.tr("Pair a Mac Host to list trusted iPhone/iPad clients."))
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                        }

                        ForEach(devices) { device in
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: "rectangle.connected.to.line.below")
                                    .foregroundStyle(device.lastSeenAt == nil ? VQTheme.unavailable : VQTheme.green)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(device.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(L10n.tr("Last seen")) \(dateLabel(device.lastSeenAt))")
                                        .font(.caption)
                                        .foregroundStyle(VQTheme.secondaryText)
                                    Text(device.pushUpdatedAt == nil ? L10n.tr("Push not registered") : "Push \(device.pushEnvironment ?? L10n.tr("unknown")) - \(dateLabel(device.pushUpdatedAt))")
                                        .font(.caption)
                                        .foregroundStyle(device.pushUpdatedAt == nil ? VQTheme.secondaryText : VQTheme.green)
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
                                    Label(L10n.tr("Revoke"), systemImage: "xmark.circle")
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                            }
                            if device.id != devices.last?.id {
                                EmptyDivider()
                            }
                        }
                    }
                }

                VQPanel("Host Audit", systemImage: "list.bullet.rectangle") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            if store.remoteAuditLines.isEmpty {
                                StatusPill(title: L10n.tr("No audit events"), tint: VQTheme.unavailable)
                            } else {
                                StatusPill(title: "\(store.remoteAuditLines.count) \(L10n.tr("events"))", tint: VQTheme.steel)
                            }
                            Spacer()
                            Button(action: store.refreshRemoteHostStatus) {
                                Label(L10n.tr("Refresh"), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                            .font(.footnote.weight(.semibold))
                            .disabled(!store.remoteHost.isPaired)
                        }

                        if store.remoteAuditLines.isEmpty {
                            Text(L10n.tr("No audit events loaded yet."))
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
                            KeyValueLine(key: "Saved endpoint", value: VQDisplay.endpoint(store.remoteHost))
                            KeyValueLine(key: "Current state", value: L10n.tr(remoteStatusTitle))
                            KeyValueLine(key: "Transport", value: "Tailscale WebSocket")
                            KeyValueLine(key: "Host app", value: L10n.tr("Use the Mac Host pairing QR or deep link"))
                            Text(L10n.tr("Pairing codes are generated by the running Mac Host and rotate after successful pairing. Paste the Host endpoint and current code above if the QR deep link is unavailable."))
                                .font(.caption)
                                .foregroundStyle(VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Button(action: store.refreshRemoteHostStatus) {
                                    Label(L10n.tr("Refresh Host"), systemImage: "arrow.clockwise")
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
        .sheet(isPresented: $showPairingScanner) {
            PairingQRScannerSheet(
                statusMessage: scannerStatusMessage,
                onCode: { payload in
                    showPairingScanner = false
                    handleScannedPairingPayload(payload)
                },
                onFailure: { message in
                    scannerStatusMessage = message
                    remoteStatusMessage = message
                }
            )
        }
    }

    private func syncRemoteFields() {
        remoteEndpoint = store.remoteHost.endpoint.isEmpty ? store.workspace.macHostEndpoint : store.remoteHost.endpoint
        if remoteDeviceName.isEmpty {
            remoteDeviceName = ProcessInfo.processInfo.hostName
        }
    }

    private func pairRemoteHost(pairingSignature: String? = nil) {
        isPairing = true
        remoteStatusMessage = L10n.tr("Pairing with Mac Host...")
        let endpoint = remoteEndpoint
        let code = remotePairingCode
        let deviceName = remoteDeviceName.isEmpty ? ProcessInfo.processInfo.hostName : remoteDeviceName
        Task { @MainActor in
            do {
                try await store.pairRemoteHost(endpoint: endpoint, pairingCode: code, pairingSignature: pairingSignature, deviceName: deviceName)
                remotePairingCode = ""
                remoteStatusMessage = L10n.tr("Paired. Future runs will launch through Mac Host.")
            } catch {
                remoteStatusMessage = "\(L10n.tr("Pairing failed")): \(error.localizedDescription)"
            }
            isPairing = false
        }
    }

    private func beginPairingScan() {
        scannerStatusMessage = L10n.tr("Point the camera at the Mac Host QR.")
        #if targetEnvironment(macCatalyst)
        remoteStatusMessage = L10n.tr("QR scanning is unavailable on Mac Catalyst. Use the pairing link or code.")
        return
        #else
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            remoteStatusMessage = L10n.tr("Camera is not available on this device. Use manual pairing instead.")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showPairingScanner = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showPairingScanner = true
                    } else {
                        remoteStatusMessage = L10n.tr("Camera permission denied. Enable it in Settings to scan pairing QR.")
                    }
                }
            }
        case .denied:
            remoteStatusMessage = L10n.tr("Camera permission denied. Enable it in Settings to scan pairing QR.")
        case .restricted:
            remoteStatusMessage = L10n.tr("Camera access is restricted on this device.")
        @unknown default:
            remoteStatusMessage = L10n.tr("Camera authorization state is unavailable.")
        }
        #endif
    }

    private func applyPairingURLInput() {
        let value = pairingURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        handleScannedPairingPayload(value)
    }

    private func handleScannedPairingPayload(_ payload: String) {
        guard let url = URL(string: payload),
              url.scheme == "veqral",
              url.host == "pair",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            remoteStatusMessage = L10n.tr("Pairing QR was not recognized.")
            return
        }
        var values: [String: String] = [:]
        components.queryItems?.forEach { item in
            if let value = item.value {
                values[item.name] = value
            }
        }
        guard let endpoint = values["endpoint"], let code = values["code"] else {
            remoteStatusMessage = L10n.tr("Pairing URL is missing endpoint or code.")
            return
        }
        let signature = values["signature"] ?? values["sig"]
        remoteEndpoint = endpoint
        remotePairingCode = code
        pairingURLInput = payload
        remoteStatusMessage = L10n.tr("QR recognized. Pairing...")
        pairRemoteHost(pairingSignature: signature)
    }

    private var remoteOnline: Bool {
        store.remoteHost.isEnabled && store.remoteHost.isPaired && store.remoteHostHealth?.status == "ok"
    }

    private var remoteStatusTitle: String {
	        if remoteOnline { return "Online" }
	        if store.remoteHost.isEnabled && store.remoteHost.isPaired { return "Offline" }
	        return "Not Paired"
    }

    private var remoteStatusTint: Color {
        if remoteOnline { return VQTheme.green }
        if store.remoteHost.isEnabled && store.remoteHost.isPaired { return VQTheme.unavailable }
        return VQTheme.amber
    }

    private func dateLabel(_ date: Date?) -> String {
        guard let date else { return L10n.tr("Never") }
        return Self.deviceDateFormatter.string(from: date)
    }

    private static let deviceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct PairingQRScannerSheet: View {
    let statusMessage: String
    let onCode: (String) -> Void
    let onFailure: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                QRCodeScannerView(onCode: onCode, onFailure: onFailure)
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(VQTheme.accent)
                    Text(statusMessage.isEmpty ? L10n.tr("Point the camera at the Mac Host QR.") : statusMessage)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    Text(L10n.tr("The QR is shown from the Veqral menu bar app."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.58))
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
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
    @State private var renameChatTitle = ""

    var body: some View {
        ScreenScaffold(title: "Projects", systemImage: "folder") {
            VQPanel(VQDisplay.workspaceName(store.workspace), systemImage: "folder.badge.gearshape") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        StatusPill(title: VQDisplay.workspaceStatus(store.workspace), tint: VQDisplay.workspaceStatusTint(store.workspace))
                        Spacer()
                        Label("\(store.runs.count)", systemImage: "play.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                    KeyValueLine(key: "Repository", value: store.workspace.remoteLabel)
                    CompactKeyValueLine(key: "Local path", value: store.workspace.workingDirectory, monospaced: true)
                    CompactKeyValueLine(key: "Git root", value: store.workspace.rootPath.isEmpty ? L10n.tr("Not detected") : store.workspace.rootPath, monospaced: true)
                    KeyValueLine(key: "Branch", value: store.workspace.branchLabel)
                    FlowLayout(items: ["Hermes Project", "Codex Direct", "Claude Direct", L10n.tr("Approvals"), "Git Diff"])
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
                            Label(L10n.tr("Use Current Folder"), systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                    }
                    .font(.footnote.weight(.semibold))

                    if store.agentProjects.isEmpty {
                        Text(L10n.tr("Select a folder on Mac or use the current workspace to create the first Hermes project."))
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                    }

                    ForEach(store.agentProjects) { project in
                        Button {
                            store.selectAgentProject(project)
                            renameChatTitle = store.selectedAgentChat?.title ?? ""
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(VQDisplay.projectName(project))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(VQTheme.ink)
                                    Spacer()
                                    StatusPill(
                                        title: store.selectedAgentProject?.id == project.id ? "Selected" : "\(project.chats.count) \(L10n.tr("chats"))",
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
                        TextField(L10n.tr("New chat title"), text: $newChatTitle)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            store.createHermesChat(title: newChatTitle)
                            newChatTitle = ""
                        } label: {
                            Label(L10n.tr("New Chat"), systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                    }

                    if store.selectedAgentProject?.chats.isEmpty != false {
                        Text(L10n.tr("Create a chat to run Hermes inside the selected project. Separate chats can use different models while Hermes keeps project memory."))
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                    }

                    HermesChatModelPicker()

                    ForEach(store.selectedAgentProject?.chats ?? []) { chat in
                        let isSelected = store.selectedAgentChat?.id == chat.id
                        HStack(spacing: 10) {
                            Image(systemName: "message.badge.waveform")
                                .foregroundStyle(isSelected ? VQTheme.accent : VQTheme.secondaryText)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                if isSelected {
                                    TextField(L10n.tr("Session name"), text: $renameChatTitle)
                                        .textFieldStyle(.roundedBorder)
                                        .onAppear {
                                            renameChatTitle = chat.title
                                        }
                                } else {
                                    Text(chat.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(VQTheme.ink)
                                }
                                Text(chat.sessionID ?? L10n.tr("New Hermes session"))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(VQTheme.secondaryText)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            if isSelected {
                                Button(L10n.tr("Save Name")) {
                                    store.renameSelectedHermesChat(renameChatTitle)
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                            }
                            StatusPill(title: chat.model.isEmpty ? chat.provider : chat.model, tint: VQTheme.accent)
                        }
                        .padding(10)
                        .background(isSelected ? VQTheme.accent.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !isSelected {
                                store.selectAgentChat(chat)
                                renameChatTitle = chat.title
                            }
                        }
                    }

                    HStack {
                        Button {
                            store.submitHermesProjectCommand()
                        } label: {
                            Label(L10n.tr("Send to Selected Chat"), systemImage: "paperplane")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .disabled(store.commandDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer()
                        Text(L10n.tr("Uses Command draft"))
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                }
            }
        }
        .onAppear(perform: store.ensureAgentProjectForCurrentWorkspace)
        .onChange(of: store.selectedAgentChat?.id) { _, _ in
            renameChatTitle = store.selectedAgentChat?.title ?? ""
        }
    }
}

private struct HermesChatModelPicker: View {
    @EnvironmentObject private var store: CommandCenterStore

    private var selection: Binding<String> {
        Binding(
            get: { store.selectedHermesProvider + "|" + store.selectedHermesModel },
            set: { value in
                let parts = value.split(separator: "|", maxSplits: 1).map(String.init)
                let choice = HermesModelChoice.defaults.first {
                    $0.provider == parts.first && $0.model == (parts.count > 1 ? parts[1] : "")
                }
                if let choice {
                    store.selectHermesModel(choice)
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(L10n.tr("Hermes Model"), systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                Spacer()
                StatusPill(title: store.selectedHermesChoiceTitle.isEmpty ? "Hermes Auto" : store.selectedHermesChoiceTitle, tint: VQTheme.accent)
            }

            Picker(L10n.tr("Hermes Model"), selection: selection) {
                ForEach(HermesModelChoice.defaults) { choice in
                    Text(choice.title).tag(choice.provider + "|" + choice.model)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 6) {
                KeyValueLine(key: "Provider", value: store.selectedHermesProvider)
                KeyValueLine(key: "Model", value: store.selectedHermesModel.isEmpty ? L10n.tr("Hermes default") : store.selectedHermesModel)
            }

            Text(L10n.tr("Codex and Claude direct modes keep their own CLI model settings."))
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(VQTheme.control.opacity(0.32))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct RunsView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var selectedPhase: RunPhase? = nil

    private var filteredRuns: [CommandRun] {
        store.visibleRuns(phase: selectedPhase)
    }

    var body: some View {
        ScreenScaffold(title: "Runs", systemImage: "play.rectangle.on.rectangle") {
            ApprovalFastLane()

            VQPanel("Pipeline", systemImage: "timeline.selection") {
                PhaseRail(current: selectedPhase ?? store.selectedRun?.phase ?? .implementation)
                Picker("Phase", selection: $selectedPhase) {
                    Text(L10n.tr("All")).tag(nil as RunPhase?)
                    ForEach(RunPhase.allCases) { phase in
                        Text(phase.title).tag(phase as RunPhase?)
                    }
                }
                .pickerStyle(.segmented)
            }

            VQPanel("Queue", systemImage: "list.bullet.rectangle") {
                VStack(alignment: .leading, spacing: 12) {
                    if filteredRuns.isEmpty {
                        Text(L10n.tr("No runs in this phase yet."))
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                store.archiveRun(run)
                            } label: {
                                Label(L10n.tr("Archive"), systemImage: "archivebox")
                            }
                            .tint(.gray)
                        }
                        if run.id != filteredRuns.last?.id {
                            EmptyDivider()
                        }
                    }
                }
            }
        }
    }
}

private struct ApprovalFastLane: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        let pending = store.pendingApprovals(limit: 4)
        if !pending.isEmpty {
            VQPanel(L10n.tr("One-tap approvals"), systemImage: "hand.raised.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("Approve or reject without opening a run."))
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                    ForEach(pending) { approval in
                        CompactApprovalDecisionRow(approval: approval)
                        if approval.id != pending.last?.id {
                            EmptyDivider()
                        }
                    }
                }
            }
        }
    }
}

private struct CompactApprovalDecisionRow: View {
    let approval: CommandApproval

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: approval.symbolName)
                .frame(width: 30, height: 30)
                .foregroundStyle(approval.tint)
                .background(approval.tint.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(approval.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                    .lineLimit(1)
                Text(approval.detail)
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            ApprovalActionButtons(approval: approval)
                .frame(minWidth: 190)
        }
        .font(.footnote.weight(.semibold))
    }
}

struct DiffView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var imageMode: ImageDiffMode = .sideBySide

    var body: some View {
        ScreenScaffold(title: "Diff", systemImage: "plus.forwardslash.minus") {
            VQPanel("Changed Files", systemImage: "doc.on.doc") {
                VStack(alignment: .leading, spacing: 12) {
                    let diffs = store.diffEntries(for: store.selectedRun?.id)
                    if diffs.isEmpty {
                        Text(L10n.tr("Git diffはまだありません。Mac版でgit管理下のフォルダを指定すると取得します。"))
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
                            HStack {
                                Button {
                                    store.attachDiffInstruction(file)
                                } label: {
                                    Label(L10n.tr("Attach to Command"), systemImage: "paperclip")
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                                Spacer()
                            }
                            .font(.caption.weight(.semibold))

                            if let patch = file.patch?.trimmingCharacters(in: .whitespacesAndNewlines), !patch.isEmpty {
                                ForEach(Self.hunks(from: patch).prefix(3), id: \.self) { hunk in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            StatusPill(title: L10n.tr("Diff Hunk"), tint: VQTheme.accent)
                                            Spacer()
                                            Button {
                                                store.attachDiffInstruction(file, hunk: hunk)
                                            } label: {
                                                Label(L10n.tr("Attach to Command"), systemImage: "paperclip")
                                            }
                                            .buttonStyle(.plain)
                                            .foregroundStyle(VQTheme.accent)
                                        }
                                        Text(hunk)
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(VQTheme.secondaryText)
                                            .lineLimit(12)
                                            .textSelection(.enabled)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(VQTheme.control.opacity(0.36))
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                }
                            }
                        }
                        if file.id != diffs.last?.id {
                            EmptyDivider()
                        }
                    }
                }
            }

            VQPanel(L10n.tr("Image Diff"), systemImage: "photo.stack") {
                ImageDiffComparisonPanel(artifacts: store.remoteArtifacts, imageData: store.artifactImageData, mode: $imageMode)
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

    private static func hunks(from patch: String) -> [String] {
        let lines = patch.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var hunks: [String] = []
        var current: [String] = []
        for line in lines {
            if line.hasPrefix("@@") {
                if !current.isEmpty {
                    hunks.append(current.joined(separator: "\n"))
                    current.removeAll()
                }
            }
            if line.hasPrefix("@@") || !current.isEmpty {
                current.append(line)
            }
        }
        if !current.isEmpty {
            hunks.append(current.joined(separator: "\n"))
        }
        return hunks.isEmpty ? [patch] : hunks
    }
}

private enum ImageDiffMode: String, CaseIterable, Identifiable {
    case sideBySide
    case slider
    case overlay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sideBySide: L10n.tr("Side by side")
        case .slider: L10n.tr("Slider")
        case .overlay: L10n.tr("Overlay")
        }
    }
}

private struct ImageDiffComparisonPanel: View {
    let artifacts: [RemoteArtifactRecord]
    let imageData: [String: Data]
    @Binding var mode: ImageDiffMode
    @State private var sliderValue = 0.5

    private var images: [RemoteArtifactRecord] {
        artifacts.filter { artifact in
            let type = artifact.type.lowercased()
            let path = artifact.path.lowercased()
            return ["png", "jpg", "jpeg", "gif", "image/png", "image/jpeg"].contains(type)
                || path.hasSuffix(".png")
                || path.hasSuffix(".jpg")
                || path.hasSuffix(".jpeg")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(L10n.tr("Image Diff"), selection: $mode) {
                ForEach(ImageDiffMode.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if images.count < 2 {
                Text(L10n.tr("No image artifacts yet."))
                    .font(.subheadline)
                    .foregroundStyle(VQTheme.secondaryText)
            } else {
                let before = images[0]
                let after = images[1]
                switch mode {
                case .sideBySide:
                    HStack(spacing: 10) {
                        ArtifactImagePreview(artifact: before, data: imageData[before.id], label: "Before")
                        ArtifactImagePreview(artifact: after, data: imageData[after.id], label: "After")
                    }
                case .slider:
                    VStack(spacing: 10) {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                ArtifactUIImage(artifact: after, data: imageData[after.id])
                                ArtifactUIImage(artifact: before, data: imageData[before.id])
                                    .mask(alignment: .leading) {
                                        Rectangle().frame(width: proxy.size.width * CGFloat(sliderValue))
                                    }
                                Rectangle()
                                    .fill(VQTheme.accent)
                                    .frame(width: 2)
                                    .offset(x: proxy.size.width * CGFloat(sliderValue))
                            }
                        }
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Slider(value: $sliderValue)
                    }
                case .overlay:
                    ZStack {
                        ArtifactUIImage(artifact: before, data: imageData[before.id])
                        ArtifactUIImage(artifact: after, data: imageData[after.id])
                            .opacity(0.52)
                            .blendMode(.screen)
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}

private struct ArtifactImagePreview: View {
    let artifact: RemoteArtifactRecord
    let data: Data?
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr(label))
                .font(.caption.weight(.semibold))
                .foregroundStyle(VQTheme.secondaryText)
            ArtifactUIImage(artifact: artifact, data: data)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct ArtifactUIImage: View {
    let artifact: RemoteArtifactRecord
    let data: Data?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.25))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(VQTheme.accent)
                    Text(artifact.title)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VQTheme.control.opacity(0.32))
            }
        }
    }

    private var image: UIImage? {
        data.flatMap(UIImage.init(data:)) ?? UIImage(contentsOfFile: artifact.path)
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
                            Text(L10n.tr("Artifacts appear here after a real Mac Host run produces files or receives image attachments from iOS."))
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            if store.remoteHost.isPaired {
                                Button(action: store.refreshRemoteHostStatus) {
                                    Label(L10n.tr("Refresh Host"), systemImage: "arrow.clockwise")
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
    @State private var namedOnly = false
    @State private var sessionNameDraft = ""

    private var displayedSessions: [RemoteHistorySession] {
        namedOnly ? store.remoteHistorySessions.filter { store.hasCustomHistoryTitle($0) } : store.remoteHistorySessions
    }

    var body: some View {
        ScreenScaffold(title: "History", systemImage: "clock.arrow.circlepath") {
            VQPanel("Filters", systemImage: "line.3.horizontal.decrease.circle") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Picker("Tool", selection: $toolFilter) {
                            Text(L10n.tr("All")).tag("all")
                            Text("Claude").tag(RemoteHistoryTool.claude.rawValue)
                            Text("Codex").tag(RemoteHistoryTool.codex.rawValue)
                        }
                        .pickerStyle(.segmented)

                        Button(action: refresh) {
                            Label(L10n.tr("Refresh"), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))

                        Button {
                            store.startNewDirectSession(.codex)
                        } label: {
                            Label(L10n.tr("New Codex"), systemImage: "curlybraces.square")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))

                        Button {
                            store.startNewDirectSession(.claude)
                        } label: {
                            Label(L10n.tr("New Claude"), systemImage: "text.bubble")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                    }

                    HStack(spacing: 10) {
                        Picker("Project", selection: $projectFilter) {
                            Text(L10n.tr("All Projects")).tag("all")
                            ForEach(store.remoteHistoryProjects, id: \.self) { project in
                                Text(project).tag(project)
                            }
                        }
                        .frame(maxWidth: 260)

                        TextField(L10n.tr("Search prompts, tools, output"), text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(refresh)

                        TextField("YYYY-MM-DD", text: $dateFilter)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 132)
                            .onSubmit(refresh)

                        Toggle(L10n.tr("Named only"), isOn: $namedOnly)
                            .toggleStyle(.switch)
                            .font(.caption.weight(.semibold))
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
                    } else if displayedSessions.isEmpty {
                        Text(store.remoteHost.isPaired ? L10n.tr("No Claude or Codex sessions matched this filter.") : L10n.tr("Pair with Mac Host to read Claude/Codex history."))
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(displayedSessions) { session in
                            Button {
                                store.loadRemoteHistoryDetail(session)
                                sessionNameDraft = store.historyTitle(for: session)
                            } label: {
                                HistorySessionRow(session: session, displayTitle: store.historyTitle(for: session), isSelected: store.selectedHistorySession?.id == session.id)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    store.continueHistorySession(session)
                                } label: {
                                    Label(L10n.tr("Continue"), systemImage: "arrowshape.turn.up.right")
                                }
                                .tint(.accentColor)
                            }
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
                                Text(store.historyTitle(for: session))
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
                                Label(L10n.tr("Continue"), systemImage: "arrowshape.turn.up.right")
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                            StatusPill(title: "\(store.remoteHistoryTurns.count) \(L10n.tr("turns"))", tint: VQTheme.accent)
                        }

                        HStack(spacing: 8) {
                            TextField(L10n.tr("Session name"), text: $sessionNameDraft)
                                .textFieldStyle(.roundedBorder)
                            Button(L10n.tr("Save Name")) {
                                store.renameHistorySession(session, title: sessionNameDraft)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                        }
                        .font(.footnote.weight(.semibold))

                        if store.remoteHistoryTurns.isEmpty, store.isLoadingRemoteHistory {
                            ProgressView()
                                .padding(.vertical, 18)
                        } else if store.remoteHistoryTurns.isEmpty {
                            Text(L10n.tr("Select a session to load turns."))
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
                    Text(L10n.tr("Select a Claude or Codex session from the table."))
                        .font(.subheadline)
                        .foregroundStyle(VQTheme.secondaryText)
                }
            }
        }
        .onAppear {
            if store.remoteHistorySessions.isEmpty {
                refresh()
            }
            if let session = store.selectedHistorySession {
                sessionNameDraft = store.historyTitle(for: session)
            }
        }
        .onChange(of: store.selectedHistorySession) { _, session in
            sessionNameDraft = session.map(store.historyTitle(for:)) ?? ""
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
            Text(L10n.tr("Tool")).frame(width: 72, alignment: .leading)
            Text(L10n.tr("Project")).frame(width: 140, alignment: .leading)
            Text(L10n.tr("Started")).frame(width: 150, alignment: .leading)
            Text(L10n.tr("Turns")).frame(width: 56, alignment: .trailing)
            Text(L10n.tr("Prompt Summary")).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(VQTheme.secondaryText)
        .padding(.vertical, 6)
    }
}

private struct HistorySessionRow: View {
    let session: RemoteHistorySession
    let displayTitle: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            StatusPill(title: session.tool.title, tint: session.tool == .claude ? VQTheme.violet : VQTheme.green)
                .frame(width: 72, alignment: .leading)
            Text(session.project)
                .frame(width: 140, alignment: .leading)
                .lineLimit(1)
            Text(session.startedAt.map(Self.dateFormatter.string(from:)) ?? L10n.tr("Unknown"))
                .font(.caption.monospaced())
                .foregroundStyle(VQTheme.secondaryText)
                .frame(width: 150, alignment: .leading)
            Text("\(session.messageCount)")
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(VQTheme.ink)
                .frame(width: 56, alignment: .trailing)
            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
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
                    Button(L10n.tr(expanded ? "Collapse" : "Expand")) {
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
        turn.text.isEmpty ? L10n.tr("(empty)") : turn.text
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
                FlowLayout(items: [L10n.tr("File deletion"), L10n.tr("Billing"), L10n.tr("Production"), L10n.tr("Secrets"), L10n.tr("Screen control")])
            }

            let pending = store.pendingApprovals()
            if pending.isEmpty {
                VQPanel("Queue", systemImage: "checkmark.shield") {
                    Text(L10n.tr("No pending approvals. Risky commands stop here and run from the Mac build after approval."))
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
                ApprovalActionButtons(approval: approval)
                    .frame(maxWidth: 260)
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
            VQPanel("Hermes プロジェクト記憶", systemImage: "sparkles.rectangle.stack") {
                ProjectMemoryReadOnlyView()
            }

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
                            Label(L10n.tr(store.isLoadingRemoteMemory ? "Loading" : "Refresh"), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .disabled(store.isLoadingRemoteMemory || !(store.remoteHost.isEnabled && store.remoteHost.isPaired))
                    }
                    .font(.footnote.weight(.semibold))

                    if !(store.remoteHost.isEnabled && store.remoteHost.isPaired) {
                        Text(L10n.tr("DevicesでMac HostをQRペアリングすると、Mac上のHermesメモリをここから確認・編集できます。"))
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
                    Text(L10n.tr("Use Hermes Memory Files above to load live USER.md, MEMORY.md, and skills from the paired Mac Host."))
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
            if store.remoteHost.isEnabled,
               store.remoteHost.isPaired,
               store.remoteProjectMemory?.projectID != store.selectedAgentProject?.id {
                store.refreshRemoteProjectMemory()
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
                    GitHubStep(title: "Pull Request", value: github.pullRequestURL.isEmpty ? L10n.tr("Not opened") : github.pullRequestURL, status: github.pullRequestState, tint: github.pullRequestURL.isEmpty ? VQTheme.secondaryText : VQTheme.accent)
                    GitHubStep(title: "CI", value: github.checksSummary, status: github.checksSummary.localizedCaseInsensitiveContains("failing") ? "Failing" : "Status", tint: github.checksSummary.localizedCaseInsensitiveContains("failing") ? VQTheme.red : VQTheme.secondaryText)
                    GitHubStep(title: "Deploy", value: L10n.tr("Approval required"), status: "Locked", tint: VQTheme.red)

                    HStack(spacing: 8) {
                        Button(action: store.refreshGitHubStatus) {
                            Label(L10n.tr("Refresh"), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .disabled(!store.remoteHost.isPaired)

                        Button(action: store.createDraftPRFromHost) {
                            Label(L10n.tr("Create Draft PR"), systemImage: "plus.square.on.square")
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
                    KeyValueLine(key: "Ahead/behind", value: github.aheadBehind.isEmpty ? L10n.tr("No upstream data") : github.aheadBehind)
                    KeyValueLine(key: "Review mode", value: L10n.tr("Branch + commit + draft PR automatic, merge/deploy approval"))
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
            changedFiles == 0 ? L10n.tr("Clean") : "\(changedFiles) \(L10n.tr("changed files"))"
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

private struct ReviewNote: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(symbol.contains("exclamationmark") ? VQTheme.amber : VQTheme.green)
                .padding(.top, 1)
            Text(L10n.tr(text))
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

private struct ProjectMemoryReadOnlyView: View {
    @EnvironmentObject private var store: CommandCenterStore

    private var displayedSnapshot: RemoteProjectMemoryResponse? {
        guard let snapshot = store.remoteProjectMemory else { return nil }
        guard snapshot.projectID == store.selectedAgentProject?.id else { return nil }
        return snapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                StatusPill(
                    title: store.remoteHost.isEnabled && store.remoteHost.isPaired ? "Mac Host 接続済み" : "Mac Host 未接続",
                    tint: store.remoteHost.isEnabled && store.remoteHost.isPaired ? VQTheme.green : VQTheme.amber
                )
                StatusPill(title: "読み取り専用", tint: VQTheme.secondaryText)
                if let snapshot = displayedSnapshot {
                    StatusPill(title: "\(snapshot.sessions.count) セッション", tint: snapshot.sessions.isEmpty ? VQTheme.secondaryText : VQTheme.accent)
                }
                Spacer()
                Button {
                    store.refreshRemoteProjectMemory()
                } label: {
                    Label(store.isLoadingRemoteProjectMemory ? "読み込み中" : "更新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .disabled(store.isLoadingRemoteProjectMemory || !(store.remoteHost.isEnabled && store.remoteHost.isPaired))
            }
            .font(.footnote.weight(.semibold))

            if !(store.remoteHost.isEnabled && store.remoteHost.isPaired) {
                Text("Mac Host とペアリングすると、選択中の Hermes Project が使う native memory とセッションを確認できます。")
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let snapshot = displayedSnapshot {
                snapshotView(snapshot)
            } else {
                Text(store.isLoadingRemoteProjectMemory ? "プロジェクト記憶を読み込み中..." : "更新すると、選択中の Hermes Project の記憶を表示します。")
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !store.remoteProjectMemoryMessage.isEmpty {
                Text(store.remoteProjectMemoryMessage)
                    .font(.caption)
                    .foregroundStyle(store.remoteProjectMemoryMessage.contains("失敗") ? VQTheme.amber : VQTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func snapshotView(_ snapshot: RemoteProjectMemoryResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.projectName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                    .lineLimit(1)
                Text("Hermes source: \(snapshot.source)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(snapshot.memoryFile.relativePath)
                    .font(.caption2.monospaced())
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(1)
            }

            if snapshot.memoryContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("表示できるプロジェクト記憶はまだありません。Chat で覚えた事実が Hermes native memory に保存されるとここに出ます。")
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    Text(snapshot.memoryContent)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(VQTheme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(minHeight: 160, maxHeight: 280)
                .background(VQTheme.control.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(VQTheme.hairline, lineWidth: 1)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Hermes セッション")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.secondaryText)
                if snapshot.sessions.isEmpty {
                    Text("このプロジェクトのセッションはまだありません。")
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                } else {
                    ForEach(snapshot.sessions.prefix(8)) { session in
                        ProjectMemorySessionRow(session: session)
                    }
                }
            }

            ForEach(snapshot.warnings, id: \.self) { warning in
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(VQTheme.amber)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ProjectMemorySessionRow: View {
    let session: RemoteProjectMemorySession

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(session.endedAt == nil ? VQTheme.green : VQTheme.secondaryText)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title?.vqNilIfBlank ?? session.id)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(session.messageCount)")
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(VQTheme.ink)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(VQTheme.control.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var detail: String {
        let date = session.startedAt?.formatted(date: .abbreviated, time: .shortened) ?? "日時不明"
        let model = session.model?.vqNilIfBlank ?? "モデル未記録"
        let usage = "入力 \(session.inputTokens) / 出力 \(session.outputTokens)"
        return "\(date) ・ \(model) ・ \(usage)"
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
                    Text(L10n.tr("No Hermes memory files loaded."))
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
                    Text(selectedFile?.relativePath ?? L10n.tr("Select a file"))
                        .font(.caption.weight(.semibold))
                    if let selectedFile {
                        Text("\(selectedFile.bytes) \(L10n.tr("bytes"))")
                            .font(.caption2)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                }
                Spacer()
                Button {
                    store.previewRemoteMemoryDiff()
                } label: {
                    Label(L10n.tr("Diff"), systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .disabled(selectedFile == nil || store.isLoadingRemoteMemory)

                Button {
                    store.saveRemoteMemory()
                } label: {
                    Label(L10n.tr("Save"), systemImage: "square.and.arrow.down")
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
                Text(L10n.tr(title))
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
