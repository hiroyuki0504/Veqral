import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RootView: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        Group {
            #if targetEnvironment(macCatalyst)
            MacRootView()
            #else
            CompactRootView()
            #endif
        }
        .preferredColorScheme(.dark)
        .environment(\.locale, store.appLanguage.locale)
        .overlay(alignment: .topTrailing) {
            if Self.isUITesting {
                Gate2AcceptanceStatus()
                    .environmentObject(store)
            }
        }
        .onAppear {
            CatalystWindowConfigurator.applyMinimumSize()
        }
    }

    private static var isUITesting: Bool {
        CommandLine.arguments.contains("-veqral-ui-testing")
            || ProcessInfo.processInfo.environment["VEQRAL_UI_TESTING"] == "1"
    }
}

private struct Gate2AcceptanceStatus: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        VStack(spacing: 0) {
            Button {
                store.requestedSection = nil
                DispatchQueue.main.async {
                    store.requestedSection = .home
                }
            } label: {
                Text("Command")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("gate2.nav.command")
            .accessibilityLabel("gate2.nav.command")

            Button {
                store.requestedSection = nil
                DispatchQueue.main.async {
                    store.requestedSection = .github
                }
            } label: {
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("gate2.nav.more")
            .accessibilityLabel("gate2.nav.more")

            Text("pendingApprovals:\(store.pendingApprovals().count)")
                .font(.caption2)
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("gate2.approval.pendingCount")
                .accessibilityLabel("pendingApprovals:\(store.pendingApprovals().count)")
        }
    }
}

private enum CatalystWindowConfigurator {
    @MainActor
    static func applyMinimumSize() {
        #if targetEnvironment(macCatalyst)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .forEach { scene in
                scene.sizeRestrictions?.minimumSize = CGSize(width: 780, height: 520)
            }
        #endif
    }
}

private struct MacRootView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var utilitySheet: MacUtilitySheet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    SpinningCommandNodeMark(size: 34)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Veqral Mac Host")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(VQTheme.ink)
                        Text("Mac版はターミナル運用。操作は iPhone / iPad から。")
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                    }

                    Spacer()

                    Button {
                        refreshHost()
                    } label: {
                        Label("更新", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VQTheme.accent)
                    .disabled(store.isRefreshingRemoteHost)
                }

                MacHostStatusPanel()

                HStack(alignment: .top, spacing: 14) {
                    MacTerminalPanel(rows: terminalRows)
                    MacUtilityPanel(selection: $utilitySheet)
                        .frame(width: 250)
                }
            }
            .padding(24)
        }
        .background {
            ZStack {
                VQTheme.canvas.ignoresSafeArea()
                LinearGradient(
                    colors: [Color.white.opacity(0.022), Color.clear, Color.black.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    utilitySheet = .devices
                } label: {
                    Label("端末", systemImage: "macbook.and.iphone")
                }

                Button {
                    utilitySheet = .approvals
                } label: {
                    Label("承認", systemImage: "hand.raised")
                }
            }
        }
        .onChange(of: store.requestedSection) { _, section in
            guard let section else { return }
            utilitySheet = MacUtilitySheet(section: section)
            store.requestedSection = nil
        }
        .sheet(item: $utilitySheet) { sheet in
            NavigationStack {
                sectionDestination(sheet.section)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") {
                                utilitySheet = nil
                            }
                        }
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            if CommandLine.arguments.contains("-veqral-ui-testing")
                || ProcessInfo.processInfo.environment["VEQRAL_UI_TESTING"] == "1" {
                Button {
                    utilitySheet = .memory
                } label: {
                    Text("Memory")
                        .font(.caption2)
                        .foregroundStyle(.clear)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.001))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("gate2.nav.memory")
                .accessibilityLabel("gate2.nav.memory")
                .padding(.top, 96)
            }
        }
    }

    private var terminalRows: [MacTerminalCommand] {
        let root = nonBlank(store.workspace.rootPath) ?? store.workspace.workingDirectory
        return [
            MacTerminalCommand(
                title: "Host起動",
                command: "cd \(shellQuoted(root))\ncd MacHost\nswift run VeqralHost"
            ),
            MacTerminalCommand(
                title: "Pairing確認",
                command: "curl http://127.0.0.1:7878/v1/pairing"
            ),
            MacTerminalCommand(
                title: "ログ",
                command: "tail -f ~/.veqral-host/launchd/stdout.log ~/.veqral-host/launchd/stderr.log"
            )
        ]
    }

    private func refreshHost() {
        store.refreshWorkspace()
        store.refreshRemoteHostStatus()
        store.refreshRemoteHostTelemetry()
    }

    private func shellQuoted(_ value: String) -> String {
        let trimmed = nonBlank(value) ?? NSHomeDirectory()
        return "'" + trimmed.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func nonBlank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }
}

private enum MacUtilitySheet: String, Identifiable {
    case devices
    case approvals
    case runs
    case memory

    var id: String { rawValue }

    var section: AppSection {
        switch self {
        case .devices: .devices
        case .approvals: .approvals
        case .runs: .runs
        case .memory: .memory
        }
    }

    init?(section: AppSection) {
        switch section {
        case .devices:
            self = .devices
        case .approvals:
            self = .approvals
        case .runs, .home:
            self = .runs
        case .memory:
            self = .memory
        default:
            return nil
        }
    }
}

private struct MacHostStatusPanel: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: statusSymbol)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(statusTint)
                    .background(statusTint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.headline)
                        .foregroundStyle(VQTheme.ink)
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                StatusPill(title: statusPill, tint: statusTint)
            }

            Divider().overlay(VQTheme.hairline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                MacMetricTile(title: "実行", value: "\(store.runs.count)", symbol: "play.rectangle")
                MacMetricTile(title: "承認", value: "\(store.pendingApprovals().count)", symbol: "hand.raised")
                MacMetricTile(title: "端末", value: "\(store.visibleRemoteDevices.count)", symbol: "iphone")
                MacMetricTile(title: "作業場所", value: VQDisplay.workspaceName(store.workspace), symbol: "folder")
            }
        }
        .padding(16)
        .background(VQTheme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VQTheme.hairline, lineWidth: 1)
        }
    }

    private var isOnline: Bool {
        store.remoteHost.isEnabled && store.remoteHost.isPaired && store.remoteHostHealth?.status == "ok"
    }

    private var statusTitle: String {
        if isOnline { return "Mac Host 接続中" }
        if store.remoteHost.isPaired { return "Mac Host ペアリング済み" }
        return "Mac Host ターミナル運用"
    }

    private var statusDetail: String {
        if store.remoteHost.isPaired {
            return store.remoteHost.displayEndpoint
        }
        return "127.0.0.1:7878 / Tailscale endpoint"
    }

    private var statusPill: String {
        if isOnline { return "接続中" }
        if store.remoteHost.isPaired { return "ペアリング済み" }
        return "ターミナル"
    }

    private var statusSymbol: String {
        isOnline ? "checkmark.circle" : "terminal"
    }

    private var statusTint: Color {
        isOnline ? VQTheme.green : VQTheme.amber
    }
}

private struct MacMetricTile: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .frame(width: 24, height: 24)
                .foregroundStyle(VQTheme.accent)
                .background(VQTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VQTheme.secondaryText)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(VQTheme.control.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MacTerminalCommand: Identifiable {
    let id = UUID()
    let title: String
    let command: String
}

private struct MacTerminalPanel: View {
    let rows: [MacTerminalCommand]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("ターミナル", systemImage: "terminal")
                .font(.headline)
                .foregroundStyle(VQTheme.ink)

            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(row.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VQTheme.secondaryText)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = row.command
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                        .help("コピー")
                    }

                    Text(row.command)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(VQTheme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.black.opacity(0.28))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(VQTheme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VQTheme.hairline, lineWidth: 1)
        }
    }
}

private struct MacUtilityPanel: View {
    @EnvironmentObject private var store: CommandCenterStore
    @Binding var selection: MacUtilitySheet?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("最小操作", systemImage: "switch.2")
                .font(.headline)
                .foregroundStyle(VQTheme.ink)

            MacUtilityButton(title: "端末", symbol: "macbook.and.iphone") {
                selection = .devices
            }
            MacUtilityButton(title: "承認 \(store.pendingApprovals().count)", symbol: "hand.raised") {
                selection = .approvals
            }
            MacUtilityButton(title: "実行 \(store.runs.count)", symbol: "play.rectangle") {
                selection = .runs
            }
            MacUtilityButton(title: "記憶", symbol: "brain.head.profile") {
                selection = .memory
            }
        }
        .padding(16)
        .background(VQTheme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VQTheme.hairline, lineWidth: 1)
        }
    }
}

private struct MacUtilityButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .frame(width: 22)
                Text(title)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VQTheme.secondaryText)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(VQTheme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(VQTheme.control.opacity(0.52))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct CompactRootView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var selectedSection: AppSection = .home
    @State private var isDrawerPresented = false

    var body: some View {
        NavigationStack {
            Group {
                if selectedSection == .home {
                    CommandCenterMobileChatView(
                        openDrawer: {
                            isDrawerPresented = true
                        },
                        openSection: { section in
                            selectedSection = section
                        }
                    )
                } else {
                    sectionDestination(selectedSection)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    isDrawerPresented = true
                                } label: {
                                    Image(systemName: "line.3.horizontal")
                                }
                                .accessibilityLabel(L10n.tr("Open navigation"))
                                .accessibilityIdentifier("gate2.mobile.menu")
                            }

                            ToolbarItem(placement: .principal) {
                                Label(selectedSection.title, systemImage: selectedSection.symbol)
                                    .font(.subheadline.weight(.semibold))
                            }

                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    selectedSection = .home
                                    store.commandDraft = ""
                                    store.selectedRunID = nil
                                    store.ensureDirectClientRuntime()
                                } label: {
                                    Image(systemName: "plus")
                                }
                                .accessibilityLabel(L10n.tr("New command"))
                            }
                        }
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .tint(VQTheme.accent)
        .background(VQTheme.canvas.ignoresSafeArea())
        .sheet(isPresented: $isDrawerPresented) {
            MobileNavigationDrawer(
                selectedSection: $selectedSection,
                isPresented: $isDrawerPresented
            )
            .environmentObject(store)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: store.requestedSection) { _, section in
            guard let section else { return }
            selectedSection = section
            isDrawerPresented = false
            store.requestedSection = nil
        }
    }
}

private struct MobileNavigationDrawer: View {
    @EnvironmentObject private var store: CommandCenterStore
    @Binding var selectedSection: AppSection
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Veqral")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(VQTheme.ink)
                        Text(VQDisplay.hostName(store))
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                            .lineLimit(1)
                    }
                    .padding(.top, 8)

                    Button {
                        select(.home)
                        store.commandDraft = ""
                        store.selectedRunID = nil
                        store.ensureDirectClientRuntime()
                    } label: {
                        Label(L10n.tr("New command"), systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 10))

                    drawerSection(L10n.tr("Native Agents")) {
                        drawerRow(.home, identifier: "gate2.sidebar.home")
                        drawerRow(.history, identifier: "gate2.more.history")
                        drawerRow(.approvals, count: store.pendingApprovals().count, identifier: "gate2.sidebar.approvals")
                        drawerRow(.runs, identifier: "gate2.more.runs")
                    }

                    drawerSection(L10n.tr("Run Tools")) {
                        drawerRow(.diff, identifier: "gate2.more.diff")
                        drawerRow(.artifacts, identifier: "gate2.more.artifacts")
                        drawerRow(.salesLab, identifier: "gate2.more.salesLab")
                        drawerRow(.github, identifier: "gate2.more.github")
                    }

                    drawerSection(L10n.tr("System")) {
                        drawerRow(.devices, identifier: "gate2.sidebar.devices")
                        Picker(L10n.tr("App Language"), selection: $store.appLanguage) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.title).tag(language)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    drawerSection(L10n.tr("Parked")) {
                        Text(L10n.tr("Hermes orchestration and project memory now live in Hermes Desktop. These Veqral surfaces stay available for review while they are parked."))
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                        drawerRow(.projects, identifier: "gate2.more.projects")
                        drawerRow(.memory, identifier: "gate2.more.memory")
                        drawerRow(.portfolio, identifier: "gate2.sidebar.portfolio")
                    }
                }
                .padding(18)
            }
            .background(VQTheme.canvas.ignoresSafeArea())
            .navigationTitle(L10n.tr("Navigation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Close")) {
                        isPresented = false
                    }
                }
            }
        }
        .accessibilityIdentifier("gate2.mobile.drawer")
    }

    @ViewBuilder
    private func drawerSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(VQTheme.mutedText)
                .textCase(.uppercase)
            VStack(spacing: 4) {
                content()
            }
        }
    }

    private func drawerRow(_ section: AppSection, count: Int? = nil, identifier: String) -> some View {
        Button {
            select(section)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 24)
                    .foregroundStyle(selectedSection == section ? VQTheme.accent : VQTheme.secondaryText)
                Text(section.title)
                    .font(.subheadline.weight(selectedSection == section ? .semibold : .regular))
                    .foregroundStyle(VQTheme.ink)
                Spacer()
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(VQTheme.red)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(selectedSection == section ? VQTheme.control.opacity(0.82) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func select(_ section: AppSection) {
        selectedSection = section
        isPresented = false
    }
}

private struct RegularRootView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var selectedSection: AppSection? = .home

    var body: some View {
        HStack(spacing: 0) {
            CommandCenterSidebar(selection: $selectedSection)
                .frame(width: 278)

            Divider()
                .overlay(VQTheme.hairline)

            NavigationStack {
                sectionDestination(selectedSection ?? .home)
            }
            .frame(minWidth: 380, maxWidth: .infinity)

            Divider()
                .overlay(VQTheme.hairline)

            CommandCenterInspectorView(selection: $selectedSection)
                .frame(width: 326)
        }
        .background {
            ZStack {
                VQTheme.canvas.ignoresSafeArea()
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.025),
                        Color.clear,
                        Color.black.opacity(0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
        .onChange(of: store.requestedSection) { _, section in
            guard let section else { return }
            selectedSection = section
            store.requestedSection = nil
        }
        .overlay(alignment: .topTrailing) {
            if CommandLine.arguments.contains("-veqral-ui-testing")
                || ProcessInfo.processInfo.environment["VEQRAL_UI_TESTING"] == "1" {
                Button {
                    selectedSection = .memory
                    store.requestedSection = .memory
                } label: {
                    Text("Memory")
                        .font(.caption2)
                        .foregroundStyle(.clear)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.001))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("gate2.nav.memory")
                .accessibilityLabel("gate2.nav.memory")
                .padding(.top, 96)
            }
        }
    }
}

@MainActor
@ViewBuilder
private func sectionDestination(_ section: AppSection) -> some View {
    switch section {
    case .home:
        CommandCenterRunView()
    case .portfolio:
        PortfolioView()
    case .projects:
        ProjectsView()
    case .devices:
        DevicesView()
    case .runs:
        RunsView()
    case .diff:
        DiffView()
    case .artifacts:
        ArtifactsView()
    case .history:
        HistoryView()
    case .salesLab:
        SalesLabView()
    case .approvals:
        ApprovalsView()
    case .memory:
        MemoryView()
    case .github:
        GitHubOpsView()
    }
}
