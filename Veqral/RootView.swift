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
        .onAppear {
            CatalystWindowConfigurator.applyMinimumSize()
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

            NavigationStack {
                ApprovalsView()
            }
            .tabItem { Label(AppSection.approvals.title, systemImage: AppSection.approvals.symbol) }
            .tag(AppSection.approvals)

            NavigationStack {
                ProjectsView()
            }
            .tabItem { Label(AppSection.projects.title, systemImage: AppSection.projects.symbol) }
            .tag(AppSection.projects)

            NavigationStack {
                DevicesView()
            }
            .tabItem { Label(AppSection.devices.title, systemImage: AppSection.devices.symbol) }
            .tag(AppSection.devices)

            NavigationStack {
                MoreView()
            }
            .tabItem { Label(L10n.tr("More"), systemImage: "ellipsis.circle") }
            .tag(AppSection.github)
        }
        .tint(VQTheme.accent)
        .toolbarBackground(VQTheme.canvas, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onChange(of: store.requestedSection) { _, section in
            guard let section else { return }
            selectedTab = AppSection.primaryTabs.contains(section) ? section : .home
            store.requestedSection = nil
        }
    }
}

private struct MoreView: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        List {
            Section(L10n.tr("Command")) {
                ForEach(AppSection.commandGroup.filter { !AppSection.primaryTabs.contains($0) }) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.symbol)
                    }
                }
            }

            Section(L10n.tr("Operations")) {
                ForEach(AppSection.operationGroup.filter { !AppSection.primaryTabs.contains($0) }) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.symbol)
                    }
                }
            }

            Section(L10n.tr("System")) {
                ForEach(AppSection.systemGroup.filter { !AppSection.primaryTabs.contains($0) }) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.symbol)
                    }
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
    }
}

@MainActor
@ViewBuilder
private func sectionDestination(_ section: AppSection) -> some View {
    switch section {
    case .home:
        CommandCenterRunView()
    case .chat:
        IntentCaptureView()
    case .requirements:
        RequirementsView()
    case .projects:
        ProjectsView()
    case .devices:
        DevicesView()
    case .agents:
        AgentsView()
    case .models:
        ModelAssignmentView()
    case .runs:
        RunsView()
    case .terminal:
        TerminalView()
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
