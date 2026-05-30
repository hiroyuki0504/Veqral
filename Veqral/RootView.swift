import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.dark.rawValue

    private var mode: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .dark
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                CompactRootView()
            } else {
                RegularRootView()
            }
        }
        .preferredColorScheme(mode.colorScheme)
    }
}

private struct CompactRootView: View {
    @State private var selectedTab: AppSection = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            CommandCenterPhoneDashboard()
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
            .tabItem { Label("More", systemImage: "ellipsis.circle") }
            .tag(AppSection.github)
        }
    }
}

private struct MoreView: View {
    var body: some View {
        List {
            Section("Command") {
                ForEach(AppSection.commandGroup.filter { !AppSection.primaryTabs.contains($0) }) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.symbol)
                    }
                }
            }

            Section("Operations") {
                ForEach(AppSection.operationGroup.filter { !AppSection.primaryTabs.contains($0) }) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.symbol)
                    }
                }
            }

            Section("System") {
                ForEach(AppSection.systemGroup.filter { !AppSection.primaryTabs.contains($0) }) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.symbol)
                    }
                }
            }
        }
        .navigationTitle("Veqral")
        .navigationDestination(for: AppSection.self) { section in
            sectionDestination(section)
        }
    }
}

private struct RegularRootView: View {
    @State private var selectedSection: AppSection? = .runs

    var body: some View {
        HStack(spacing: 0) {
            CommandCenterSidebar(selection: $selectedSection)
                .frame(width: 250)

            Divider()
                .overlay(VQTheme.hairline)

            NavigationStack {
                sectionDestination(selectedSection ?? .home)
            }
            .frame(minWidth: 380, maxWidth: .infinity)

            Divider()
                .overlay(VQTheme.hairline)

            CommandCenterInspectorView()
                .frame(width: 330)
        }
        .background(VQTheme.canvas.ignoresSafeArea())
    }
}

private struct SidebarView: View {
    @Binding var selection: AppSection?

    var body: some View {
        List(selection: $selection) {
            Section("Command") {
                ForEach(AppSection.commandGroup) { section in
                    Label(section.title, systemImage: section.symbol)
                        .tag(section)
                }
            }

            Section("Operations") {
                ForEach(AppSection.operationGroup) { section in
                    Label(section.title, systemImage: section.symbol)
                        .tag(section)
                }
            }

            Section("System") {
                ForEach(AppSection.systemGroup) { section in
                    Label(section.title, systemImage: section.symbol)
                        .tag(section)
                }
            }
        }
        .navigationTitle("Veqral")
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                EmptyDivider()
                HStack {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .foregroundStyle(VQTheme.green)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Agent Host")
                            .font(.caption.weight(.semibold))
                        Text("2 Macs reachable")
                            .font(.caption2)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .background(.regularMaterial)
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
    case .runs:
        CommandCenterRunView()
    case .terminal:
        TerminalView()
    case .diff:
        DiffView()
    case .artifacts:
        ArtifactsView()
    case .approvals:
        ApprovalsView()
    case .memory:
        MemoryView()
    case .github:
        GitHubOpsView()
    }
}
