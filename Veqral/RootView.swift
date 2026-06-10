import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        Group {
            #if targetEnvironment(macCatalyst)
            MacRootView()
            #else
            if horizontalSizeClass == .compact {
                CompactRootView()
            } else {
                RegularRootView()
            }
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
                scene.sizeRestrictions?.minimumSize = CGSize(width: 1180, height: 720)
            }
        #endif
    }
}

private struct MacRootView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var selectedSection: AppSection? = .home

    var body: some View {
        NavigationSplitView {
            CommandCenterSidebar(selection: $selectedSection)
                .frame(minWidth: 260, idealWidth: 286, maxWidth: 320)
        } content: {
            NavigationStack {
                sectionDestination(selectedSection ?? .home)
            }
            .frame(minWidth: 620)
        } detail: {
            CommandCenterInspectorView(selection: $selectedSection)
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 380)
        }
        .navigationSplitViewStyle(.balanced)
        .background(VQTheme.canvas.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.refreshRemoteHostStatus()
                } label: {
                    Label(L10n.tr("Refresh"), systemImage: "arrow.clockwise")
                }
                .help(L10n.tr("Refresh Mac Host"))

                Button {
                    store.requestedSection = .devices
                } label: {
                    Label(L10n.tr("Pair Mac Host"), systemImage: "qrcode.viewfinder")
                }
                .help(L10n.tr("Open Devices"))
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

private struct CompactRootView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var selectedTab: AppSection = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CommandCenterPhoneDashboard()
                    .navigationDestination(for: AppSection.self) { section in
                        sectionDestination(section)
                    }
            }
            .tabItem { Label(AppSection.home.title, systemImage: AppSection.home.symbol) }
            .tag(AppSection.home)
            .accessibilityIdentifier("gate2.tab.home")

            NavigationStack {
                PortfolioView()
            }
            .tabItem { Label(AppSection.portfolio.title, systemImage: AppSection.portfolio.symbol) }
            .tag(AppSection.portfolio)
            .accessibilityIdentifier("gate2.tab.portfolio")

            NavigationStack {
                ApprovalsView()
            }
            .tabItem { Label(AppSection.approvals.title, systemImage: AppSection.approvals.symbol) }
            .tag(AppSection.approvals)
            .accessibilityIdentifier("gate2.tab.approvals")

            NavigationStack {
                DevicesView()
            }
            .tabItem { Label(AppSection.devices.title, systemImage: AppSection.devices.symbol) }
            .tag(AppSection.devices)
            .accessibilityIdentifier("gate2.tab.devices")

            NavigationStack {
                MoreView()
            }
            .tabItem { Label(L10n.tr("More"), systemImage: "ellipsis.circle") }
            .tag(AppSection.github)
            .accessibilityIdentifier("gate2.tab.more")
        }
        .tint(VQTheme.accent)
        .toolbarBackground(VQTheme.canvas, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onChange(of: store.requestedSection) { _, section in
            guard let section else { return }
            if section == .github {
                selectedTab = .github
            } else {
                selectedTab = AppSection.primaryTabs.contains(section) ? section : .home
            }
            store.requestedSection = nil
        }
    }
}

private struct MoreView: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        List {
            Section(L10n.tr("Operations")) {
                ForEach(AppSection.operationGroup.filter { !AppSection.primaryTabs.contains($0) }) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.symbol)
                            .accessibilityIdentifier("gate2.more.\(section.rawValue)")
                    }
                    .accessibilityIdentifier("gate2.more.\(section.rawValue)")
                }
            }

            Section(L10n.tr("System")) {
                ForEach(AppSection.systemGroup.filter { !AppSection.primaryTabs.contains($0) }) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.symbol)
                            .accessibilityIdentifier("gate2.more.\(section.rawValue)")
                    }
                    .accessibilityIdentifier("gate2.more.\(section.rawValue)")
                }
            }

            Section(L10n.tr("Settings")) {
                Picker(L10n.tr("App Language"), selection: $store.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                Text(L10n.tr("Japanese UI with English developer terms where useful."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("gate2.screen.more")
        .navigationTitle("Veqral")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                SpinningCommandNodeMark(size: 20)
            }
        }
        .navigationDestination(for: AppSection.self) { section in
            sectionDestination(section)
        }
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
    case .hermes:
        HermesControlView()
    case .approvals:
        ApprovalsView()
    case .memory:
        MemoryView()
    case .github:
        GitHubOpsView()
    }
}
