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
                requestSection(.home)
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
                requestSection(.github)
            } label: {
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("gate2.nav.more")
            .accessibilityLabel("gate2.nav.more")

            Button {
                requestSection(.devices)
            } label: {
                Text("Devices")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("gate2.nav.devices")
            .accessibilityLabel("gate2.nav.devices")

            Button {
                requestSection(.memory)
            } label: {
                Text("Memory")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("gate2.nav.memory")
            .accessibilityLabel("gate2.nav.memory")

            Text("pendingApprovals:\(store.pendingApprovals().count)")
                .font(.caption2)
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("gate2.approval.pendingCount")
                .accessibilityLabel("pendingApprovals:\(store.pendingApprovals().count)")
        }
    }

    private func requestSection(_ section: AppSection) {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        store.requestedSection = nil
        DispatchQueue.main.async {
            store.requestedSection = section
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
                    } label: {
                        Label(L10n.tr("New command"), systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 10))

                    drawerSection(L10n.tr("Today")) {
                        drawerRow(.home, identifier: "gate2.sidebar.home")
                        drawerRow(.approvals, count: store.pendingApprovals().count, identifier: "gate2.sidebar.approvals")
                        drawerRow(.history, identifier: "gate2.more.history")
                    }

                    drawerSection(L10n.tr("Workspaces")) {
                        drawerRow(.projects, identifier: "gate2.more.projects")
                        drawerRow(.portfolio, identifier: "gate2.sidebar.portfolio")
                        drawerRow(.memory, identifier: "gate2.more.memory")
                    }

                    drawerSection(L10n.tr("Tools")) {
                        drawerRow(.runs, identifier: "gate2.more.runs")
                        drawerRow(.diff, identifier: "gate2.more.diff")
                        drawerRow(.artifacts, identifier: "gate2.more.artifacts")
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
    case .approvals:
        ApprovalsView()
    case .memory:
        MemoryView()
    case .github:
        GitHubOpsView()
    }
}
