import Foundation
import SwiftUI
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(Speech)
import Speech
#endif

struct AppearanceToggleButton: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        Button {
            store.refreshWorkspace()
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 34)
                .foregroundStyle(VQTheme.accent)
                .background(VQTheme.control)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(VQTheme.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(L10n.tr("Refresh workspace"))
    }
}

struct CommandCenterSidebar: View {
    @EnvironmentObject private var store: CommandCenterStore
    @Binding var selection: AppSection?

    private var sidebarGroups: [(String, [AppSection])] {
        [
            (L10n.tr("Command"), AppSection.commandGroup),
            (L10n.tr("Operations"), AppSection.operationGroup),
            (L10n.tr("System"), AppSection.systemGroup)
        ]
    }

    private func count(for section: AppSection) -> Int? {
        switch section {
        case .runs:
            store.runs.count
        case .approvals:
            store.pendingApprovals().count
        default:
            nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    SpinningCommandNodeMark(size: 28)
                    Spacer()
                }

                HStack(spacing: 8) {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        HStack(spacing: 8) {
                            Text(context.date, format: .dateTime.hour().minute())
                            Text(context.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        }
                    }
                    Spacer()
                    AppearanceToggleButton()
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(VQTheme.ink)
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(sidebarGroups, id: \.0) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            SidebarSectionTitle(group.0)
                            ForEach(group.1) { section in
                                SidebarActionRow(
                                    identifier: "gate2.sidebar.\(section.rawValue)",
                                    title: section.title,
                                    symbol: section.symbol,
                                    count: count(for: section),
                                    isSelected: selection == section,
                                    isWarning: section == .approvals
                                ) {
                                    selection = section
                                }
                            }
                        }
                    }

                    SidebarSectionTitle(L10n.tr("Favorites"))
                    VStack(spacing: 10) {
                        FavoriteRow(color: VQTheme.amber, title: VQDisplay.workspaceName(store.workspace))
                        FavoriteRow(color: VQTheme.accent, title: store.workspace.branchLabel)
                        FavoriteRow(color: VQTheme.violet, title: store.workspace.cleanlinessLabel)
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer(minLength: 12)

            Menu {
                Picker(L10n.tr("App Language"), selection: $store.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                    Text(store.appLanguage.title)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(VQTheme.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(VQTheme.control.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)

            HStack(spacing: 10) {
                Circle()
                    .fill(VQTheme.control)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Text("JD")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VQTheme.ink)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("Local Operator"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    Text(VQDisplay.hostName(store))
                        .font(.caption2)
                        .foregroundStyle(VQTheme.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VQTheme.secondaryText)
            }
            .padding(10)
            .background(VQTheme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(VQTheme.hairline, lineWidth: 1)
            }
            .padding(10)
        }
        .background {
            ZStack {
                VQTheme.sidebar
                LinearGradient(
                    colors: [Color.white.opacity(0.026), Color.clear, Color.black.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

struct CommandCenterRunView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var selectedSurface = WorkSurface.terminal

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HostConnectionStrip()

                    if let run = store.selectedRun {
                        RunHeader(run: run)
                        RunPhaseTracker(run: run)

                        VStack(spacing: 0) {
                            WorkSurfacePicker(selectedSurface: $selectedSurface)
                            Divider().overlay(VQTheme.hairline)
                            RunWorkSurface(
                                selectedSurface: selectedSurface,
                                logs: store.logEntries(for: run.id),
                                diffs: store.diffEntries(for: run.id)
                            )
                        }
                        .background(VQTheme.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(VQTheme.hairline, lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 14)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
            }

            RunStatusBar(run: store.selectedRun)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CommandSubmitPanel()
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(VQTheme.hairline)
                        .frame(height: 1)
                }
        }
        .background {
            ZStack {
                VQTheme.canvas
                LinearGradient(
                    colors: [Color.white.opacity(0.020), Color.clear, Color.black.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("gate2.screen.command")
    }
}

struct CommandCenterInspectorView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @Binding var selection: AppSection?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.tr("Run Inspector"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                    .padding(.top, 18)

                InspectorPanel(title: L10n.tr("Approvals"), count: store.pendingApprovals().count) {
                    VStack(spacing: 8) {
                        let pending = store.pendingApprovals(limit: 3)
                        if pending.isEmpty {
                            InspectorGuardrailSummary()
                        } else {
                            ForEach(pending) { approval in
                                InspectorApprovalRow(approval: approval)
                            }
                        }
                        Button(L10n.tr("View all approvals ->")) {
                            selection = .approvals
                        }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VQTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 2)
                    }
                }

                InspectorPanel(title: L10n.tr("Context Pack"), trailing: L10n.tr("Unified")) {
                    InspectorLinkedRow(
                        symbol: "doc.badge.gearshape",
                        title: "\(VQDisplay.workspaceName(store.workspace)) \(L10n.tr("Pack"))",
                        detail: "\(ContextPackage.items.count) \(L10n.tr("items")) - \(store.workspace.branchLabel)"
                    )
                }

                InspectorPanel(title: L10n.tr("Assigned Agent")) {
                    VStack(spacing: 8) {
                        InspectorAgentRow(color: VQTheme.accent, title: "Hermes", detail: store.remoteHost.isPaired ? L10n.tr("Mac Host runtime") : L10n.tr("Pairing required"), status: store.remoteHost.isPaired ? VQTheme.green : VQTheme.amber)
                        InspectorAgentRow(color: VQTheme.ink, title: "Codex CLI", detail: L10n.tr("Direct history is isolated"), status: store.remoteHost.isPaired ? VQTheme.secondaryText : VQTheme.unavailable)
                        InspectorAgentRow(color: VQTheme.green, title: L10n.tr("Context"), detail: "\(ContextPackage.items.count) \(L10n.tr("package items"))", status: VQTheme.green)
                    }
                }

                InspectorPanel(title: L10n.tr("Mac Device")) {
                    InspectorLinkedRow(symbol: "laptopcomputer", title: VQDisplay.hostName(store), detail: store.workspace.hostName, trailing: store.workspace.canRunLocalCommands ? L10n.tr("Online") : L10n.tr("Waiting"))
                }

                InspectorPanel(title: L10n.tr("Model")) {
                    InspectorLinkedRow(
                        symbol: store.selectedRuntime.symbol,
                        title: store.selectedRuntime.title,
                        detail: store.selectedRuntime == .hermesAgent ? store.workspace.hermesLabel : store.workspace.remoteLabel,
                        trailing: store.selectedRuntime == .hermesAgent && store.workspace.canRunHermes ? L10n.tr("Ready") : nil
                    )
                }
            }
            .padding(12)
        }
        .background(VQTheme.canvas)
    }
}

struct CommandCenterPhoneDashboard: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(L10n.tr("Command"))
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(VQTheme.ink)
                    Spacer()
                    AppearanceToggleButton()
                }
                .padding(.top, 8)

                HostConnectionStrip()

                let visibleRuns = Array(store.visibleRuns().prefix(5))
                PhoneSectionHeader(title: L10n.tr("Active Runs"), count: nil, showAction: !visibleRuns.isEmpty)
                VStack(spacing: 0) {
                    if visibleRuns.isEmpty {
                        PhoneEmptyState(symbol: "play.rectangle", text: L10n.tr("No active runs. Send an instruction to start one."))
                    }
                    ForEach(visibleRuns) { run in
                        PhoneRunRow(run: run)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.selectRun(run.id)
                            }
                        if run.id != visibleRuns.last?.id {
                            Divider().overlay(VQTheme.hairline)
                        }
                    }
                }
                .commandPanel()

                PhoneSectionHeader(title: store.selectedRuntime.dashboardSectionTitle, count: nil, showAction: false)
                PhoneComposer()

                PhoneSectionHeader(title: L10n.tr("Approvals"), count: store.pendingApprovals().count)
                VStack(spacing: 8) {
                    let pending = store.pendingApprovals(limit: 3)
                    if pending.isEmpty {
                        ProtectionSummaryCard()
                    } else {
                        ForEach(pending) { approval in
                            CompactApprovalStrip(approval: approval)
                        }
                    }
                }

                let visibleDevices = Array(store.visibleRemoteDevices.prefix(4))
                PhoneSectionHeader(title: L10n.tr("Devices"), count: visibleDevices.count, trailing: store.remoteHost.isPaired ? L10n.tr("Connected") : L10n.tr("Pair Mac Host"))
                if visibleDevices.isEmpty {
                    PhoneEmptyState(
                        symbol: "iphone.slash",
                        text: store.remoteHost.isPaired ? L10n.tr("No other paired devices yet.") : L10n.tr("Pair a Mac Host to list trusted iPhone/iPad clients.")
                    )
                    .commandPanel()
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(visibleDevices) { device in
                            PhoneDeviceCard(
                                name: device.name,
                                detail: device.lastSeenAt == nil ? L10n.tr("Paired") : L10n.tr("Seen"),
                                status: device.lastSeenAt == nil ? .offline : .online
                            )
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    PhoneArtifactsPanel()
                    PhoneProjectStatusPanel()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background {
            ZStack {
                VQTheme.canvas.ignoresSafeArea()
                LinearGradient(
                    colors: [Color.white.opacity(0.024), Color.clear, Color.black.opacity(0.20)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }
}

struct CommandCenterMobileChatView: View {
    @EnvironmentObject private var store: CommandCenterStore
    let openDrawer: () -> Void
    let openSection: (AppSection) -> Void

    private var visibleRuns: [CommandRun] {
        Array(store.visibleRuns().prefix(12))
    }

    var body: some View {
        VStack(spacing: 0) {
            mobileTopBar

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    HostConnectionStrip()

                    if visibleRuns.isEmpty {
                        MobileWelcomePanel(openSection: openSection)
                    } else {
                        ForEach(visibleRuns) { run in
                            PhoneRunRow(run: run)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.selectRun(run.id)
                                }
                                .commandPanel()
                        }
                    }

                    if let run = store.selectedRun {
                        MobileRunDetail(run: run, openSection: openSection)
                    }

                    MobileQuickAccess(openSection: openSection)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 18)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PhoneComposer(showsRuntimePicker: false, prominentVoice: true)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(VQTheme.hairline)
                        .frame(height: 1)
                }
        }
        .background(VQTheme.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var mobileTopBar: some View {
        HStack(spacing: 10) {
            Button(action: openDrawer) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .background(VQTheme.control.opacity(0.72))
            .clipShape(Circle())
            .accessibilityLabel(L10n.tr("Open navigation"))
            .accessibilityIdentifier("gate2.mobile.menu")

            Menu {
                ForEach(CommandRuntime.allCases) { runtime in
                    Button {
                        store.selectRuntime(runtime)
                    } label: {
                        Label(runtime.title, systemImage: runtime.symbol)
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: store.selectedRuntime.symbol)
                    Text(store.selectedRuntime.shortTitle)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VQTheme.ink)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(VQTheme.control.opacity(0.72))
                .clipShape(Capsule())
            }
            .accessibilityLabel(L10n.tr("Select agent"))

            Spacer()

            Button {
                store.commandDraft = ""
                store.selectedRunID = nil
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .background(VQTheme.control.opacity(0.72))
            .clipShape(Circle())
            .accessibilityLabel(L10n.tr("New command"))
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(VQTheme.canvas.opacity(0.94))
    }
}

private struct MobileWelcomePanel: View {
    @EnvironmentObject private var store: CommandCenterStore
    let openSection: (AppSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("What should the agents do?"))
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(VQTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.tr("Choose Hermes, Codex, Claude, or Shell above, then send a command from the bottom composer."))
                    .font(.subheadline)
                    .foregroundStyle(VQTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MobileActionTile(symbol: "clock.arrow.circlepath", title: L10n.tr("Resume History"), tint: VQTheme.accent) {
                    openSection(.history)
                }
                MobileActionTile(symbol: "brain.head.profile", title: L10n.tr("Project Memory"), tint: VQTheme.green) {
                    openSection(.memory)
                }
                MobileActionTile(symbol: "hand.raised", title: L10n.tr("Approvals"), tint: store.pendingApprovals().isEmpty ? VQTheme.secondaryText : VQTheme.red) {
                    openSection(.approvals)
                }
                MobileActionTile(symbol: "rectangle.3.group", title: L10n.tr("Portfolio"), tint: VQTheme.amber) {
                    openSection(.portfolio)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
    }
}

private struct MobileRunDetail: View {
    @EnvironmentObject private var store: CommandCenterStore
    let run: CommandRun
    let openSection: (AppSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(run.title)
                        .font(.headline)
                        .foregroundStyle(VQTheme.ink)
                        .lineLimit(2)
                    HStack(spacing: 7) {
                        StatusPill(title: run.status.title, tint: run.status.tint)
                        Text(run.runtimeOrDefault.shortTitle)
                        Text(run.elapsedLabel)
                    }
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
                }
                Spacer()
                Button {
                    openSection(.runs)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .background(VQTheme.control.opacity(0.72))
                .clipShape(Circle())
                .accessibilityLabel(L10n.tr("Open run details"))
            }

            if let usage = run.usage, usage.hasDisplayValues {
                RunUsageSummary(usage: usage)
            }

            if let approval = store.pendingApproval(for: run.id) {
                RunApprovalCallout(approval: approval, compact: true)
            }

            let recentLogs = Array(store.logEntries(for: run.id).suffix(5))
            if recentLogs.isEmpty {
                PhoneEmptyState(symbol: "text.alignleft", text: L10n.tr("Run logs appear here."))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(recentLogs) { entry in
                        Text(entry.message)
                            .font(.caption.monospaced())
                            .foregroundStyle(entry.stream == "error" ? VQTheme.red : VQTheme.secondaryText)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(10)
                .background(VQTheme.control.opacity(0.34))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(14)
        .commandPanel()
    }
}

private struct MobileQuickAccess: View {
    @EnvironmentObject private var store: CommandCenterStore
    let openSection: (AppSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.tr("Quick access"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.secondaryText)
                Spacer()
                if store.remoteHost.isPaired {
                    StatusPill(title: L10n.tr("Connected"), tint: VQTheme.green)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    MobileQuickButton(section: .devices, title: L10n.tr("Devices"), openSection: openSection)
                    MobileQuickButton(section: .projects, title: L10n.tr("Projects"), openSection: openSection)
                    MobileQuickButton(section: .diff, title: L10n.tr("Diff"), openSection: openSection)
                    MobileQuickButton(section: .artifacts, title: L10n.tr("Artifacts"), openSection: openSection)
                    MobileQuickButton(section: .github, title: "GitHub", openSection: openSection)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.bottom, 4)
    }
}

private struct MobileQuickButton: View {
    let section: AppSection
    let title: String
    let openSection: (AppSection) -> Void

    var body: some View {
        Button {
            openSection(section)
        } label: {
            Label(title, systemImage: section.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VQTheme.ink)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(VQTheme.control.opacity(0.62))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct MobileActionTile: View {
    let symbol: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(minHeight: 92, alignment: .topLeading)
            .background(VQTheme.control.opacity(0.50))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(VQTheme.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private enum WorkSurface: String, CaseIterable, Identifiable {
    case terminal = "Terminal"
    case diff = "Diff"
    case preview = "Preview"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .terminal: "terminal"
        case .diff: "arrow.triangle.branch"
        case .preview: "eye"
        }
    }

    var title: String {
        L10n.tr(rawValue)
    }
}

private struct ApprovalGuardrail: Identifiable {
    let id: String
    let title: String
    let detail: String
    let risk: String
    let tint: Color
}

private let approvalGuardrails = [
    ApprovalGuardrail(id: "delete", title: L10n.tr("File deletion"), detail: "rm, git clean, reset --hard", risk: L10n.tr("High risk only"), tint: VQTheme.red),
    ApprovalGuardrail(id: "secrets", title: L10n.tr("Secrets"), detail: ".env, token, keychain, private key", risk: L10n.tr("Review required"), tint: VQTheme.amber),
    ApprovalGuardrail(id: "screen", title: L10n.tr("Screen control"), detail: "open, osascript, screenshot", risk: L10n.tr("Review required"), tint: VQTheme.amber)
]

private struct ProtectionSummaryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(VQTheme.secondaryText)
                Text(L10n.tr("Protection active"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                Spacer()
                StatusPill(title: L10n.tr("No pending approvals."), tint: VQTheme.unavailable)
            }
            Text(L10n.tr("File deletion, secrets, screen control, billing, and production changes pause for review."))
                .font(.caption2)
                .foregroundStyle(VQTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(VQTheme.control.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VQTheme.hairline, lineWidth: 1)
        }
    }
}

private struct PhoneEmptyState: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.caption)
                .frame(width: 24, height: 24)
                .foregroundStyle(VQTheme.secondaryText)
                .background(VQTheme.control.opacity(0.58))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(text)
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(10)
    }
}

private struct SidebarActionRow: View {
    let identifier: String?
    let title: String
    let symbol: String
    let count: Int?
    let isSelected: Bool
    let isWarning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 22)
                    .foregroundStyle(isSelected ? VQTheme.accent : VQTheme.ink)
                Text(L10n.tr(title))
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? VQTheme.ink : VQTheme.secondaryText)
                    .lineLimit(1)
                Spacer()
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(isWarning ? VQTheme.red : VQTheme.control)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    LinearGradient(
                        colors: [VQTheme.control.opacity(0.96), VQTheme.control.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.clear
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? VQTheme.hairline : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? "")
    }
}

private struct SidebarSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(VQTheme.mutedText)
            .padding(.horizontal, 10)
    }
}

private struct FavoriteRow: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
            Spacer()
        }
        .padding(.horizontal, 10)
    }
}

private struct RunHeader: View {
    @EnvironmentObject private var store: CommandCenterStore
    let run: CommandRun

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    if let newest = store.runs.first?.id {
                        store.selectRun(newest)
                    }
                } label: {
                    Label(L10n.tr("Back to Active Runs"), systemImage: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VQTheme.accent)
                }
                .buttonStyle(.plain)
                Spacer()
                Button(action: store.pauseOrResumeSelectedRun) {
                    Label(L10n.tr(run.status == .waiting ? "Resume" : "Pause"), systemImage: run.status == .waiting ? "play" : "pause")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(CommandButtonStyle())
                Menu {
                    Button(L10n.tr("Refresh workspace")) {
                        store.refreshWorkspace()
                    }
                    Button(L10n.tr(run.status == .waiting ? "Resume run" : "Pause run")) {
                        store.pauseOrResumeSelectedRun()
                    }
                    Button(L10n.tr("Show latest run")) {
                        if let newest = store.runs.first?.id {
                            store.selectRun(newest)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(CommandButtonStyle())
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(run.title)
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(VQTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                StatusPill(title: run.status.title, tint: run.status.tint)
                Spacer()
            }

            HStack(spacing: 10) {
                Label(VQDisplay.workspaceName(store.workspace), systemImage: "doc.text")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(run.runtimeOrDefault.title)
                Text("\(L10n.tr("Started")) \(run.elapsedLabel)")
                Text("\(L10n.tr("Run ID")) \(run.shortID)")
                Image(systemName: "doc.on.doc")
            }
            .font(.caption)
            .foregroundStyle(VQTheme.secondaryText)

            if run.runtimeOrDefault != .hermesAgent {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 10) {
                        handoffIntro
                        Spacer()
                        handoffButton
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        handoffIntro
                        handoffButton
                    }
                }
                .padding(10)
                .background(VQTheme.control.opacity(0.38))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(VQTheme.hairline, lineWidth: 1)
                }
            }

            if let usage = run.usage, usage.hasDisplayValues {
                RunUsageSummary(usage: usage)
            }

            CostGovernancePanel(summary: store.costSummary(for: run), compact: true)
                .onAppear {
                    store.refreshCostGovernance()
                }

            if let approval = store.pendingApproval(for: run.id) {
                RunApprovalCallout(approval: approval)
            }
        }
    }

    private var handoffIntro: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label("Project 記憶へ引き継ぐ", systemImage: "arrow.triangle.branch")
                .font(.caption.weight(.semibold))
                .foregroundStyle(VQTheme.ink)
            Text("直接モードの履歴は分離されています。Hermes に整理すると別 Chat/別モデルで続けられます。")
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
                .lineLimit(2)
        }
    }

    private var handoffButton: some View {
        Button {
            store.handoffRunContextToHermes(run)
        } label: {
            Label("Hermesへ送る", systemImage: "paperplane")
        }
        .buttonStyle(CommandButtonStyle())
    }
}

private struct RunUsageSummary: View {
    let usage: CommandRunUsage

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let input = usage.inputTokens {
                    RunUsageChip(title: L10n.tr("Input Tokens"), value: formatTokens(input), symbol: "arrow.down.left")
                }
                if let output = usage.outputTokens {
                    RunUsageChip(title: L10n.tr("Output Tokens"), value: formatTokens(output), symbol: "arrow.up.right")
                }
                if let reasoning = usage.reasoningTokens {
                    RunUsageChip(title: L10n.tr("Reasoning Tokens"), value: formatTokens(reasoning), symbol: "brain")
                }
                if let total = usage.totalTokensOrDerived {
                    RunUsageChip(title: L10n.tr("Total Tokens"), value: formatTokens(total), symbol: "sum")
                }
                if let cacheRead = usage.cacheReadTokens {
                    RunUsageChip(title: L10n.tr("Cache Read"), value: formatTokens(cacheRead), symbol: "externaldrive")
                }
                if let cacheWrite = usage.cacheWriteTokens {
                    RunUsageChip(title: L10n.tr("Cache Write"), value: formatTokens(cacheWrite), symbol: "square.and.pencil")
                }
                if let cost = usage.costUSD {
                    RunUsageChip(
                        title: L10n.tr(usage.actualCostUSD == nil ? "Estimated Cost" : "Actual Cost"),
                        value: formatCost(cost),
                        symbol: "dollarsign.circle"
                    )
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityLabel(L10n.tr("Run Usage"))
    }

    private func formatTokens(_ value: Int) -> String {
        Self.tokenFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formatCost(_ value: Double) -> String {
        value < 0.0001 ? String(format: "$%.6f", value) : String(format: "$%.4f", value)
    }

    private static let tokenFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

private struct RunUsageChip: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption2.weight(.semibold))
            Text(title)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(VQTheme.ink)
        }
        .font(.caption)
        .foregroundStyle(VQTheme.secondaryText)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(VQTheme.control)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VQTheme.hairline, lineWidth: 1)
        }
    }
}

struct CostGovernancePanel: View {
    @EnvironmentObject private var store: CommandCenterStore
    let summary: RemoteProjectCostSummary
    var compact: Bool = false
    @State private var budgetText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("コストガード", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                StatusPill(title: statusTitle, tint: statusTint)
                Spacer()
                Text(summary.displayName)
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                RunUsageChip(title: "累積 token", value: tokenString(summary.totalTokens), symbol: "sum")
                RunUsageChip(title: "累積費用", value: costString(summary.costUSD), symbol: "dollarsign.circle")
                if let limit = summary.budgetLimitUSD {
                    RunUsageChip(title: "上限", value: costString(limit), symbol: "lock")
                }
            }

            if let limit = summary.budgetLimitUSD, limit > 0 {
                ProgressView(value: min(max(summary.costUSD / limit, 0), 1))
                    .tint(statusTint)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    budgetInput
                    actionButtons
                }
                VStack(alignment: .leading, spacing: 8) {
                    budgetInput
                    actionButtons
                }
            }

            if !store.costGovernanceMessage.isEmpty, !compact {
                Text(store.costGovernanceMessage)
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
            }
        }
        .padding(10)
        .background(VQTheme.control.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VQTheme.hairline, lineWidth: 1)
        }
        .onAppear(perform: syncBudgetText)
        .onChange(of: summary.budgetLimitUSD) { _, _ in
            syncBudgetText()
        }
    }

    private var budgetInput: some View {
        TextField("上限 USD", text: $budgetText)
            .textFieldStyle(.plain)
            .font(.caption.monospacedDigit())
            .frame(width: 110)
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(VQTheme.elevated.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(VQTheme.hairline, lineWidth: 1)
            }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                store.saveCostBudget(summary: summary, limitUSD: parsedBudget, paused: false)
            } label: {
                Label("保存", systemImage: "checkmark")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 8))
            .controlSize(.small)

            if summary.paused {
                Button {
                    store.saveCostBudget(summary: summary, limitUSD: summary.budgetLimitUSD, paused: false)
                } label: {
                    Label("再開", systemImage: "play")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .controlSize(.small)
            }
        }
        .font(.caption.weight(.semibold))
    }

    private var parsedBudget: Double? {
        let clean = budgetText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        return Double(clean.replacingOccurrences(of: ",", with: ""))
    }

    private var statusTitle: String {
        if summary.paused { return "停止中" }
        if summary.isOverLimit { return "上限超過" }
        if summary.isNearLimit { return "しきい値超過" }
        if summary.budgetLimitUSD != nil { return "監視中" }
        return "未設定"
    }

    private var statusTint: Color {
        if summary.paused || summary.isOverLimit { return VQTheme.red }
        if summary.isNearLimit { return VQTheme.amber }
        if summary.budgetLimitUSD != nil { return VQTheme.green }
        return VQTheme.steel
    }

    private func syncBudgetText() {
        if let limit = summary.budgetLimitUSD {
            budgetText = String(format: "%.4f", limit)
        } else {
            budgetText = ""
        }
    }

    private func tokenString(_ value: Int) -> String {
        Self.tokenFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func costString(_ value: Double) -> String {
        value < 0.0001 ? String(format: "$%.6f", value) : String(format: "$%.4f", value)
    }

    private static let tokenFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

private struct RunPhaseTracker: View {
    let run: CommandRun

    private var steps: [(String, String, Color, Bool)] {
        [
            (L10n.tr("Plan"), run.progress > 0.0 ? L10n.tr("Ready") : L10n.tr("Pending"), VQTheme.green, true),
            (L10n.tr("Implementation"), run.status == .failed ? L10n.tr("Failed") : L10n.tr("In Progress"), run.status == .failed ? VQTheme.red : VQTheme.green, run.progress > 0.1),
            (L10n.tr("Testing"), run.status == .complete ? L10n.tr("Complete") : L10n.tr("In Progress"), run.status == .complete ? VQTheme.green : VQTheme.accent, run.progress > 0.55),
            (L10n.tr("Review"), run.status == .approval ? L10n.tr("Approval") : L10n.tr("Pending"), run.status == .approval ? VQTheme.amber : VQTheme.mutedText, run.status == .approval),
            (L10n.tr("Complete"), run.status == .complete ? L10n.tr("Done") : L10n.tr("Pending"), run.status == .complete ? VQTheme.green : VQTheme.mutedText, run.status == .complete)
        ]
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(steps.indices, id: \.self) { index in
                    HStack(spacing: 0) {
                        Circle()
                            .fill(steps[index].3 ? steps[index].2 : VQTheme.canvas)
                            .frame(width: 18, height: 18)
                            .overlay {
                                Circle()
                                    .stroke(steps[index].2, lineWidth: 2)
                            }
                            .overlay {
                                if index < 2 {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        if index != steps.indices.last {
                            Rectangle()
                                .fill(index < 2 ? steps[index].2 : VQTheme.hairline)
                                .frame(height: 2)
                        }
                    }
                }
            }

            HStack {
                ForEach(steps.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(steps[index].0)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(index == 2 ? VQTheme.accent : VQTheme.ink)
                        Text(steps[index].1)
                            .font(.caption2)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.bottom, 8)
    }
}

private struct CommandSubmitPanel: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var isVoiceInputPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RuntimeSegmentedControl()

            HStack(spacing: 10) {
                TextField(store.selectedRuntime.commandPlaceholder, text: $store.commandDraft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .lineLimit(1...3)
                    .padding(10)
                    .background(VQTheme.control.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onSubmit {
                        store.submitDraft()
                    }
                    .accessibilityIdentifier("gate2.command.input")

                Button {
                    store.saveCurrentCommandDraft()
                } label: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 15, weight: .bold))
                }
                .buttonStyle(CommandButtonStyle(tint: store.canSaveCurrentCommandDraft ? VQTheme.accent : VQTheme.ink))
                .disabled(!store.canSaveCurrentCommandDraft)
                .help(L10n.tr("Save current command as a reusable draft"))
                .accessibilityLabel(L10n.tr("Save current command as a reusable draft"))
                .accessibilityIdentifier("gate2.command.save")

                Button {
                    isVoiceInputPresented = true
                } label: {
                    Image(systemName: "mic")
                        .font(.system(size: 15, weight: .bold))
                }
                .buttonStyle(CommandButtonStyle(tint: VQTheme.ink))
                .help(L10n.tr("Voice input"))
                .accessibilityIdentifier("gate2.voice.open")

                Button(action: store.submitDraft) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                }
                .buttonStyle(CommandButtonStyle(tint: VQTheme.accent))
                .help(L10n.tr("Run"))
                .accessibilityIdentifier("gate2.command.submit")
            }

            #if targetEnvironment(macCatalyst)
            HStack(spacing: 8) {
                Image(systemName: store.selectedRuntime.symbol)
                Text(store.selectedRuntime.title)
                Text(L10n.tr("in"))
                Image(systemName: "folder")
                TextField(L10n.tr("Working directory"), text: $store.workingDirectory)
                    .textFieldStyle(.plain)
                    .font(.caption.monospaced())
                    .onSubmit {
                        store.refreshWorkspace()
                    }
            }
            .foregroundStyle(VQTheme.secondaryText)
            .padding(.horizontal, 4)
            #else
            Text(L10n.tr("On iPhone and iPad this creates a run. Execution starts after a Mac Host is connected."))
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
            #endif

            SavedCommandDraftBar(compact: false)
            CommandAttachmentControls()
            CommandRequirementMemo()
        }
        .padding(12)
        .commandPanel()
        .sheet(isPresented: $isVoiceInputPresented) {
            VoiceCommandSheet()
                .environmentObject(store)
        }
    }
}

private struct CommandRequirementMemo: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var store: CommandCenterStore

    private var selectedRunText: String {
        guard let run = store.selectedRun else {
            return L10n.tr("No run selected")
        }
        return run.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Label(L10n.tr("Requirement Memo"), systemImage: "checklist")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                Spacer()
                StatusPill(title: store.selectedRuntime.shortTitle, tint: VQTheme.accent)
            }

            Text(selectedRunText)
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
                .lineLimit(2)

            HStack(spacing: 8) {
                Button {
                    store.commandDraft = L10n.tr("Summarize requirements, acceptance criteria, and risks for this work before implementing.")
                } label: {
                    Label(L10n.tr("Requirements"), systemImage: "text.badge.checkmark")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))

                memoryControl

                Spacer()
            }
            .font(.caption.weight(.semibold))
        }
        .padding(10)
        .background(VQTheme.control.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var memoryControl: some View {
        if horizontalSizeClass == .compact {
            NavigationLink(value: AppSection.memory) {
                Label(L10n.tr("Memory"), systemImage: "brain.head.profile")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 8))
            .accessibilityIdentifier("gate2.command.memory")
        } else {
            Button {
                store.requestedSection = .memory
            } label: {
                Label(L10n.tr("Memory"), systemImage: "brain.head.profile")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 8))
            .accessibilityIdentifier("gate2.command.memory")
        }
    }
}

private struct WorkSurfacePicker: View {
    @Binding var selectedSurface: WorkSurface

    var body: some View {
        HStack(spacing: 18) {
            ForEach(WorkSurface.allCases) { surface in
                Button {
                    selectedSurface = surface
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: surface.symbol)
                            .frame(width: 30, height: 30)
                            .background(selectedSurface == surface ? VQTheme.control : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        Text(surface.title)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(selectedSurface == surface ? VQTheme.accent : VQTheme.secondaryText)
                }
                .buttonStyle(.plain)

                if surface != WorkSurface.allCases.last {
                    Rectangle()
                        .fill(VQTheme.hairline)
                        .frame(width: 1, height: 30)
                }
            }
            Spacer()
        }
        .padding(14)
    }
}

private struct RunWorkSurface: View {
    let selectedSurface: WorkSurface
    let logs: [CommandLogEntry]
    let diffs: [CommandDiffEntry]

    var body: some View {
        GeometryReader { geometry in
            let useColumns = geometry.size.width > 610
            Group {
                if selectedSurface == .preview {
                    PreviewEmptyState()
                } else if selectedSurface == .diff {
                    DiffListPanel(diffs: diffs)
                } else {
                    if useColumns {
                        HStack(spacing: 0) {
                            TerminalTranscript(logs: logs)
                                .frame(maxWidth: .infinity)
                            Divider().overlay(VQTheme.hairline)
                            DiffListPanel(diffs: diffs)
                                .frame(width: 280)
                        }
                    } else {
                        VStack(spacing: 0) {
                            TerminalTranscript(logs: logs)
                            Divider().overlay(VQTheme.hairline)
                            DiffListPanel(diffs: diffs)
                                .frame(height: 280)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 486)
    }
}

private struct TerminalTranscript: View {
    let logs: [CommandLogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if logs.isEmpty {
                Text(L10n.tr("まだログはありません。Commandを送るとここに表示されます。"))
                    .foregroundStyle(VQTheme.secondaryText)
            }
            ForEach(logs) { line in
                HStack(alignment: .top, spacing: 8) {
                    Text(line.time.commandTime)
                        .foregroundStyle(VQTheme.secondaryText)
                        .frame(width: 58, alignment: .leading)
                    Text(line.statusSymbol)
                        .foregroundStyle(line.statusColor)
                        .frame(width: 12)
                    Text(line.message)
                        .foregroundStyle(line.statusColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "shield")
                    .foregroundStyle(VQTheme.ink)
                Rectangle()
                    .fill(VQTheme.accent)
                    .frame(width: 8, height: 18)
                    .opacity(0.8)
            }
            .padding(.top, 4)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(VQTheme.terminal.opacity(0.96))
    }

}

private struct DiffListPanel: View {
    let diffs: [CommandDiffEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("Diff"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    Text("\(diffs.count) \(L10n.tr("files changed"))")
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                }
                Spacer()
                Text("+\(diffs.map(\.additions).reduce(0, +))  -\(diffs.map(\.deletions).reduce(0, +))")
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(VQTheme.green)
            }

            if diffs.isEmpty {
                Text(L10n.tr("No git diff yet. Point the Mac build at a git workspace to collect changed files."))
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
            }

            ForEach(diffs) { file in
                HStack(spacing: 9) {
                    Image(systemName: file.path.hasSuffix("json") ? "curlybraces" : "doc.text")
                        .font(.caption)
                        .frame(width: 22, height: 22)
                        .foregroundStyle(file.deletions > 12 ? VQTheme.red : VQTheme.accent)
                        .background((file.deletions > 12 ? VQTheme.red : VQTheme.accent).opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    Text(file.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(VQTheme.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text("+\(file.additions)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(VQTheme.green)
                    Text("-\(file.deletions)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(file.deletions == 0 ? VQTheme.secondaryText : VQTheme.red)
                }
                Divider().overlay(VQTheme.hairline)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct PreviewEmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "safari")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(VQTheme.accent)
            Text(L10n.tr("Preview is waiting for a local web target"))
                .font(.headline)
                .foregroundStyle(VQTheme.ink)
            Text(L10n.tr("After a Mac Host connects, screenshots and web previews appear here."))
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct RunStatusBar: View {
    let run: CommandRun?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                Label(run?.model ?? L10n.tr("Local Shell"), systemImage: "asterisk.circle.fill")
                    .foregroundStyle(VQTheme.amber)
                Divider().frame(height: 20).overlay(VQTheme.hairline)
                Label(run?.agent ?? L10n.tr("Local Mac"), systemImage: "person.crop.circle")
                Divider().frame(height: 20).overlay(VQTheme.hairline)
                Label(run?.elapsedLabel ?? L10n.tr("Waiting"), systemImage: "timer")
                Divider().frame(height: 20).overlay(VQTheme.hairline)
                Label("\(Int((run?.progress ?? 0) * 100))%", systemImage: "gearshape")
                Divider().frame(height: 20).overlay(VQTheme.hairline)
                Circle().fill((run?.status ?? .waiting).tint).frame(width: 7, height: 7)
                Text(run?.status.title ?? L10n.tr("Waiting"))
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 18)
        }
        .font(.caption)
        .foregroundStyle(VQTheme.secondaryText)
        .frame(height: 44)
        .background(VQTheme.elevated)
        .overlay(alignment: .top) {
            Rectangle().fill(VQTheme.hairline).frame(height: 1)
        }
    }
}

private struct InspectorPanel<Content: View>: View {
    let title: String
    let count: Int?
    let trailing: String?
    let content: Content

    init(title: String, count: Int? = nil, trailing: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.count = count
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VQTheme.secondaryText)
                Spacer()
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(VQTheme.red)
                        .clipShape(Circle())
                }
                if let trailing {
                    StatusPill(title: trailing, tint: VQTheme.green)
                }
            }

            content
        }
        .padding(10)
        .commandPanel()
    }
}

private struct InspectorApprovalRow: View {
    let approval: CommandApproval

    private var tint: Color {
        approval.tintName == "amber" ? VQTheme.amber : VQTheme.red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(approval.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                    Text(approval.detail)
                        .font(.caption2)
                        .foregroundStyle(tint)
                }
                Spacer()
            }
            ApprovalActionButtons(approval: approval, compact: true)
        }
        .padding(9)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(tint.opacity(0.65), lineWidth: 1)
        }
    }
}

private struct InspectorGuardrailRow: View {
    let guardrail: ApprovalGuardrail

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(guardrail.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(guardrail.tint)
                    Text(guardrail.detail)
                        .font(.caption2)
                        .foregroundStyle(guardrail.tint.opacity(0.88))
                }
                Spacer()
                Text(guardrail.risk)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(guardrail.tint)
            }
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                Text(L10n.tr("Approval gate ready"))
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(VQTheme.secondaryText)
        }
        .padding(9)
        .background(guardrail.tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(guardrail.tint.opacity(0.58), lineWidth: 1)
        }
    }
}

private struct InspectorGuardrailSummary: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield")
                .frame(width: 28, height: 28)
                .foregroundStyle(VQTheme.secondaryText)
                .background(VQTheme.control.opacity(0.58))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.tr("Protection active"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                Text(L10n.tr("High-risk actions pause here only when a real request appears."))
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
            }
            Spacer()
        }
        .padding(9)
        .background(VQTheme.control.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct InspectorLinkedRow: View {
    let symbol: String
    let title: String
    let detail: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 28, height: 28)
                .foregroundStyle(VQTheme.accent)
                .background(VQTheme.accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.green)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(VQTheme.secondaryText)
            }
        }
        .padding(8)
        .background(VQTheme.control.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct InspectorAgentRow: View {
    let color: Color
    let title: String
    let detail: String
    let status: Color

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
            }
            Spacer()
            Circle().fill(status).frame(width: 7, height: 7)
        }
    }
}

private struct PhoneSectionHeader: View {
    let title: String
    var count: Int?
    var trailing: String = "View All"
    var showAction: Bool = true

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(VQTheme.secondaryText)
            if let count, count > 0 {
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(VQTheme.red)
                    .clipShape(Circle())
            }
            Spacer()
            if showAction {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.accent)
            }
        }
    }
}

private struct PhoneRunRow: View {
    @EnvironmentObject private var store: CommandCenterStore
    let run: CommandRun

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "doc.badge.gearshape")
                    .font(.caption)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(run.status.tint)
                    .background(run.status.tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Circle().stroke(run.status.tint, lineWidth: 1).frame(width: 8, height: 8)
                        Text(run.phase.commandTitle)
                    }
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
                }
                Spacer()
                Text(elapsed)
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
            }

            if run.runtimeOrDefault != .hermesAgent {
                Button {
                    store.handoffRunContextToHermes(run)
                } label: {
                    Label("Hermesへ引き継ぐ", systemImage: "arrow.triangle.branch")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .controlSize(.small)
            }

            if let approval = store.pendingApproval(for: run.id) {
                RunApprovalCallout(approval: approval, compact: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }

    private var elapsed: String {
        run.elapsedLabel
    }
}

private struct PhoneComposer: View {
    @EnvironmentObject private var store: CommandCenterStore
    var showsRuntimePicker = true
    var prominentVoice = false
    @State private var isVoiceInputPresented = false

    var body: some View {
        VStack(spacing: 8) {
            if showsRuntimePicker {
                RuntimeSegmentedControl()
            }

            HStack(spacing: 8) {
                TextField(store.selectedRuntime.commandPlaceholder, text: $store.commandDraft, axis: .vertical)
                    .font(prominentVoice ? .subheadline : .caption)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .onSubmit {
                        store.submitDraft()
                    }
                    .accessibilityIdentifier("gate2.command.input")
                Button {
                    store.saveCurrentCommandDraft()
                } label: {
                    Image(systemName: "bookmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(store.canSaveCurrentCommandDraft ? VQTheme.accent : VQTheme.ink)
                        .background(VQTheme.control)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!store.canSaveCurrentCommandDraft)
                .accessibilityLabel(L10n.tr("Save current command as a reusable draft"))
                .accessibilityIdentifier("gate2.command.save")
                Button {
                    isVoiceInputPresented = true
                } label: {
                    Image(systemName: "mic")
                        .font(.system(size: prominentVoice ? 17 : 12, weight: .bold))
                        .frame(width: prominentVoice ? 38 : 28, height: prominentVoice ? 38 : 28)
                        .foregroundStyle(prominentVoice ? .black : VQTheme.ink)
                        .background(prominentVoice ? VQTheme.accent : VQTheme.control)
                        .clipShape(RoundedRectangle(cornerRadius: prominentVoice ? 12 : 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("gate2.voice.open")
                Button(action: store.submitDraft) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: prominentVoice ? 17 : 12, weight: .bold))
                        .frame(width: prominentVoice ? 38 : 28, height: prominentVoice ? 38 : 28)
                        .foregroundStyle(.white)
                        .background(store.commandDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? VQTheme.secondaryText : VQTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: prominentVoice ? 12 : 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("gate2.command.submit")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(VQTheme.control.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if showsRuntimePicker {
                HStack {
                    CommandChip(title: L10n.tr("Implementation"), symbol: "chevron.left.forwardslash.chevron.right", command: "Implement the current approved requirements.")
                    CommandChip(title: L10n.tr("Testing"), symbol: "flask", command: "Run the relevant tests and fix failures if they are in scope.")
                    CommandChip(title: "", symbol: "ellipsis", command: "Show available next actions for this project.")
                    Spacer()
                }
            }

            SavedCommandDraftBar(compact: true)
            CommandAttachmentControls()
            if showsRuntimePicker {
                CommandRequirementMemo()
            }
        }
        .padding(prominentVoice ? 10 : 8)
        .commandPanel()
        .sheet(isPresented: $isVoiceInputPresented) {
            VoiceCommandSheet()
                .environmentObject(store)
        }
    }
}

private struct CommandChip: View {
    @EnvironmentObject private var store: CommandCenterStore
    let title: String
    let symbol: String
    let command: String

    var body: some View {
        Button {
            store.commandDraft = command
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                if !title.isEmpty {
                    Text(title)
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(VQTheme.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(VQTheme.control)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct VoiceCommandSheet: View {
    @EnvironmentObject private var store: CommandCenterStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session = VoiceCommandSession()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: session.phase.symbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(session.phase.tint)
                        .frame(width: 40, height: 40)
                        .background(session.phase.tint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.phase.title)
                            .font(.headline)
                            .foregroundStyle(VQTheme.ink)
                        Text(session.statusMessage)
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("gate2.voice.status")
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.tr("Raw Dictation"), systemImage: "waveform")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    Text(session.rawText.isEmpty ? L10n.tr("Listening text appears here.") : session.rawText)
                        .font(.subheadline)
                        .foregroundStyle(session.rawText.isEmpty ? VQTheme.secondaryText : VQTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
                        .padding(10)
                        .background(VQTheme.control.opacity(0.38))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityIdentifier("gate2.voice.raw")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.tr("Cleaned Command"), systemImage: "text.badge.checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    TextEditor(text: $session.cleanedText)
                        .font(.subheadline)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 96)
                        .padding(8)
                        .background(VQTheme.control.opacity(0.38))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityIdentifier("gate2.voice.cleaned")
                }

                if !session.cleanupNote.isEmpty {
                    Text(session.cleanupNote)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Button(role: .cancel) {
                        session.cancel()
                        dismiss()
                    } label: {
                        Label(L10n.tr("Discard"), systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    if session.phase == .listening {
                        Button {
                            stopAndClean()
                        } label: {
                            Label(L10n.tr("Stop"), systemImage: "stop.fill")
                                .frame(minWidth: 92, minHeight: 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .contentShape(Rectangle())
                        .simultaneousGesture(TapGesture().onEnded {
                            stopAndClean()
                        })
                        .accessibilityIdentifier("gate2.voice.stop")
                    } else {
                        Button {
                            session.startListening()
                        } label: {
                            Label(L10n.tr(session.phase == .ready ? "Record Again" : "Start Recording"), systemImage: "mic.fill")
                                .frame(minWidth: 92, minHeight: 40)
                        }
                        .buttonStyle(.bordered)
                        .disabled(session.phase == .cleaning)
                        .accessibilityIdentifier("gate2.voice.start")
                    }

                    Button {
                        sendCleanedCommand()
                    } label: {
                        Label(L10n.tr("Send"), systemImage: "arrow.up")
                            .frame(minWidth: 84, minHeight: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!session.canSend)
                    .accessibilityIdentifier("gate2.voice.send")
                }
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .font(.footnote.weight(.semibold))
                .padding(.bottom, 22)
            }
            .padding(18)
            .frame(minWidth: 360, minHeight: 520)
            .background(VQTheme.canvas.ignoresSafeArea())
            .navigationTitle(L10n.tr("Voice Command"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Cancel")) {
                        session.cancel()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if session.phase == .idle {
                    session.startListening()
                }
            }
            .onDisappear {
                session.cancel()
            }
        }
    }

    private func stopAndClean() {
        guard session.phase == .listening else { return }
        session.stopListening()
        Task {
            await cleanupWithAgent()
        }
    }

    @MainActor
    private func cleanupWithAgent() async {
        let ruleBased = session.ruleBasedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ruleBased.isEmpty else { return }
        session.beginCleaning()
        if ProcessInfo.processInfo.environment["VEQRAL_UI_TESTING"] == "1" {
            session.finishCleaning(text: ruleBased, note: "XCUITest cleanup used rule-based command.")
            return
        }
        guard store.remoteHost.isEnabled, store.remoteHost.isPaired else {
            session.finishCleaning(text: ruleBased, note: L10n.tr("Mac Host is not connected. Using rule-based cleanup."))
            return
        }

        do {
            let response = try await RemoteHostClient(configuration: store.remoteHost).cleanupVoiceCommand(
                RemoteVoiceCleanupRequest(
                    rawText: session.rawText,
                    ruleBasedText: ruleBased,
                    preferredEngine: store.selectedRuntime.remoteEngine,
                    workingDirectory: store.workingDirectory,
                    provider: store.selectedRuntime == .hermesAgent ? store.selectedHermesProvider : nil,
                    model: store.selectedRuntime == .hermesAgent ? store.selectedHermesModel : nil
                )
            )
            let responseText = response.cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleaned = responseText.isEmpty ? ruleBased : responseText
            let note = response.fallbackUsed ? L10n.tr("LLM cleanup was unavailable. Using rule-based cleanup.") : L10n.tr("LLM cleanup finished. Review before sending.")
            session.finishCleaning(text: cleaned, note: note)
        } catch {
            session.finishCleaning(text: ruleBased, note: "\(L10n.tr("LLM cleanup failed. Using rule-based cleanup.")) \(error.localizedDescription)")
        }
    }

    private func sendCleanedCommand() {
        let cleaned = session.cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        store.commandDraft = ""
        store.submitCommand(cleaned)
        dismiss()
    }
}

@MainActor
private final class VoiceCommandSession: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case listening
        case cleaning
        case ready
        case error(String)

        var title: String {
            switch self {
            case .idle:
                L10n.tr("Voice Command")
            case .listening:
                L10n.tr("Listening")
            case .cleaning:
                L10n.tr("Cleaning")
            case .ready:
                L10n.tr("Ready")
            case .error:
                L10n.tr("Voice Error")
            }
        }

        var symbol: String {
            switch self {
            case .idle:
                "mic"
            case .listening:
                "waveform"
            case .cleaning:
                "sparkles"
            case .ready:
                "checkmark.circle"
            case .error:
                "exclamationmark.triangle"
            }
        }

        var tint: Color {
            switch self {
            case .idle:
                VQTheme.steel
            case .listening:
                VQTheme.accent
            case .cleaning:
                VQTheme.amber
            case .ready:
                VQTheme.green
            case .error:
                VQTheme.red
            }
        }
    }

    @Published var phase: Phase = .idle
    @Published var rawText: String = ""
    @Published var ruleBasedText: String = ""
    @Published var cleanedText: String = ""
    @Published var cleanupNote: String = ""
    @Published var statusMessage: String = L10n.tr("Tap stop when you finish speaking.")

    var canSend: Bool {
        phase == .ready && !cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    #if canImport(Speech) && canImport(AVFoundation) && !targetEnvironment(macCatalyst)
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var activeRecognitionID = UUID()
    private var hasInputTap = false
    private var hasActiveAudioSession = false
    private var interruptionObserver: NSObjectProtocol?
    #endif

    func startListening() {
        guard phase != .listening && phase != .cleaning else { return }
        rawText = ""
        ruleBasedText = ""
        cleanedText = ""
        cleanupNote = ""
        statusMessage = L10n.tr("Requesting microphone and speech recognition permission.")

        let forcedError = ProcessInfo.processInfo.environment["VEQRAL_UI_TEST_VOICE_FORCE_ERROR"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let forcedError, !forcedError.isEmpty {
            fail(Self.forcedVoiceErrorMessage(forcedError))
            return
        }

        let injectedTranscript = ProcessInfo.processInfo.environment["VEQRAL_UI_TEST_VOICE_TRANSCRIPT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let transcript = injectedTranscript, !transcript.isEmpty {
            rawText = transcript
            phase = .listening
            statusMessage = "XCUITest transcript injected."
            return
        }

        #if canImport(Speech) && canImport(AVFoundation) && !targetEnvironment(macCatalyst)
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            fail(L10n.tr("Speech recognition is unavailable."))
            return
        }
        requestSpeechAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                switch status {
                case .authorized:
                    self.requestMicrophonePermission { [weak self] granted in
                        Task { @MainActor in
                            guard let self else { return }
                            guard granted else {
                                self.fail(L10n.tr("Microphone permission was denied."))
                                return
                            }
                            do {
                                try self.startAudioRecognition()
                            } catch {
                                self.fail(error.localizedDescription)
                            }
                        }
                    }
                case .denied:
                    self.fail(L10n.tr("Speech recognition permission was denied."))
                case .restricted:
                    self.fail(L10n.tr("Speech recognition is restricted on this device."))
                case .notDetermined:
                    self.fail(L10n.tr("Speech recognition permission is not decided."))
                @unknown default:
                    self.fail(L10n.tr("Speech recognition is unavailable."))
                }
            }
        }
        #else
        fail(L10n.tr("Voice input is available on iPhone and iPad."))
        #endif
    }

    func stopListening() {
        guard phase == .listening else { return }
        #if canImport(Speech) && canImport(AVFoundation) && !targetEnvironment(macCatalyst)
        stopAudioCapture(cancelTask: false)
        #endif
        ruleBasedText = VoiceCommandRuleCleaner.clean(rawText)
        cleanedText = ruleBasedText
        if ruleBasedText.isEmpty {
            fail(L10n.tr("Dictation was too short."))
        } else {
            phase = .ready
            statusMessage = L10n.tr("Review the command before sending.")
        }
    }

    func beginCleaning() {
        phase = .cleaning
        statusMessage = L10n.tr("Cleaning dictated text with the selected agent.")
    }

    func finishCleaning(text: String, note: String) {
        cleanedText = text
        cleanupNote = note
        phase = .ready
        statusMessage = L10n.tr("Review the command before sending.")
    }

    func cancel() {
        #if canImport(Speech) && canImport(AVFoundation) && !targetEnvironment(macCatalyst)
        stopAudioCapture(cancelTask: true)
        #endif
    }

    private func fail(_ message: String) {
        cancel()
        phase = .error(message)
        statusMessage = message
    }

    #if canImport(Speech) && canImport(AVFoundation) && !targetEnvironment(macCatalyst)
    private func requestSpeechAuthorization(_ completion: @escaping (SFSpeechRecognizerAuthorizationStatus) -> Void) {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized, .denied, .restricted:
            completion(SFSpeechRecognizer.authorizationStatus())
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization(completion)
        @unknown default:
            completion(.denied)
        }
    }

    private func requestMicrophonePermission(_ completion: @escaping @Sendable (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .denied, .restricted:
            completion(false)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
        @unknown default:
            completion(false)
        }
    }

    private func startAudioRecognition() throws {
        stopAudioCapture(cancelTask: true)
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceCommandCaptureError.speechUnavailable
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true)
        hasActiveAudioSession = true
        installInterruptionObserver()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw VoiceCommandCaptureError.invalidInputFormat
        }
        if hasInputTap {
            inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        hasInputTap = true

        audioEngine.prepare()
        try audioEngine.start()
        phase = .listening
        statusMessage = L10n.tr("Listening. Speak your command in Japanese.")

        let recognitionID = UUID()
        activeRecognitionID = recognitionID
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                guard self.activeRecognitionID == recognitionID else { return }
                if let result {
                    self.rawText = result.bestTranscription.formattedString
                }
                if let error, self.phase == .listening {
                    self.fail(error.localizedDescription)
                }
            }
        }
    }

    private func stopAudioCapture(cancelTask: Bool) {
        activeRecognitionID = UUID()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInputTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }
        recognitionRequest?.endAudio()
        if cancelTask {
            recognitionTask?.cancel()
        } else {
            recognitionTask?.finish()
        }
        recognitionTask = nil
        recognitionRequest = nil
        if hasActiveAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            hasActiveAudioSession = false
        }
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
    }

    private func installInterruptionObserver() {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor in
                guard let self, self.phase == .listening else { return }
                let type = rawType.flatMap(AVAudioSession.InterruptionType.init(rawValue:))
                if type == .began {
                    self.fail(L10n.tr("Recording was interrupted."))
                }
            }
        }
    }
    #endif

    private static func forcedVoiceErrorMessage(_ value: String) -> String {
        switch value {
        case "speechDenied":
            L10n.tr("Speech recognition permission was denied.")
        case "microphoneDenied":
            L10n.tr("Microphone permission was denied.")
        case "unavailable":
            L10n.tr("Speech recognition is unavailable.")
        default:
            L10n.tr("Voice input is unavailable.")
        }
    }
}

#if canImport(Speech) && canImport(AVFoundation) && !targetEnvironment(macCatalyst)
private enum VoiceCommandCaptureError: LocalizedError {
    case speechUnavailable
    case invalidInputFormat

    var errorDescription: String? {
        switch self {
        case .speechUnavailable:
            L10n.tr("Speech recognition is unavailable.")
        case .invalidInputFormat:
            L10n.tr("Microphone input is unavailable.")
        }
    }
}
#endif

private enum VoiceCommandRuleCleaner {
    static func clean(_ rawText: String) -> String {
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        let cancellationMarkers = ["やっぱなし", "今のなし", "さっきのなし", "いや違う", "じゃなくて", "取り消し", "戻して"]
        if let range = latestRange(of: cancellationMarkers, in: text) {
            text = String(text[range.upperBound...])
        }

        let fillerPattern = #"(えー|あー|えっと|うーん|なんか|まあ|その)[、。,\s　]*"#
        text = text.replacingOccurrences(of: fillerPattern, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[\s　]+"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: " 。", with: "。")
        text = text.replacingOccurrences(of: " 、", with: "、")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func latestRange(of markers: [String], in text: String) -> Range<String.Index>? {
        markers
            .compactMap { text.range(of: $0, options: .backwards) }
            .max { lhs, rhs in lhs.lowerBound < rhs.lowerBound }
    }
}

private struct SavedCommandDraftBar: View {
    @EnvironmentObject private var store: CommandCenterStore
    let compact: Bool

    private var visibleDrafts: [SavedCommandDraft] {
        Array(store.savedCommandDrafts.prefix(compact ? 6 : 12))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(L10n.tr("Saved Commands"), systemImage: "bookmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                Spacer()
                Button {
                    store.saveCurrentCommandDraft()
                } label: {
                    Image(systemName: "bookmark.badge.plus")
                        .font(.caption.weight(.semibold))
                        .frame(width: 36, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(store.canSaveCurrentCommandDraft ? VQTheme.accent : VQTheme.secondaryText)
                .disabled(!store.canSaveCurrentCommandDraft)
                .help(L10n.tr("Save current command as a reusable draft"))
                .accessibilityLabel(L10n.tr("Save current command as a reusable draft"))
                .accessibilityIdentifier("gate2.command.saveFromDraftBar")
            }

            if visibleDrafts.isEmpty {
                Text(L10n.tr("Saved command drafts appear here."))
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(2)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(visibleDrafts.enumerated()), id: \.element.id) { index, draft in
                            SavedCommandDraftChip(draft: draft, compact: compact, isFirst: index == 0)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            if !store.savedCommandDraftMessage.isEmpty {
                Text(store.savedCommandDraftMessage)
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(1)
                    .accessibilityIdentifier("gate2.savedCommand.message")
            }
        }
        .padding(10)
        .background(VQTheme.control.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SavedCommandDraftChip: View {
    @EnvironmentObject private var store: CommandCenterStore
    let draft: SavedCommandDraft
    let compact: Bool
    let isFirst: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button {
                store.insertSavedCommandDraft(draft)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: draft.runtime?.symbol ?? "text.badge.plus")
                    VStack(alignment: .leading, spacing: 1) {
                        Text(draft.title)
                            .lineLimit(1)
                        if !compact, let runtime = draft.runtime {
                            Text(runtime.shortTitle)
                                .font(.caption2)
                                .foregroundStyle(VQTheme.secondaryText)
                        }
                    }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(VQTheme.ink)
                .padding(.leading, 9)
                .padding(.trailing, 7)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Insert saved command draft"))
            .accessibilityLabel(draft.title)
            .accessibilityValue(draft.command)
            .accessibilityIdentifier(isFirst ? "gate2.savedCommand.first" : "gate2.savedCommand.\(draft.id.uuidString)")

            Menu {
                Button {
                    store.insertSavedCommandDraft(draft)
                } label: {
                    Label(L10n.tr("Insert"), systemImage: "arrow.turn.down.left")
                }
                Button(role: .destructive) {
                    store.deleteSavedCommandDraft(draft)
                } label: {
                    Label(L10n.tr("Delete"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(VQTheme.secondaryText)
                    .frame(width: 24, height: compact ? 24 : 30)
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Saved command actions"))
        }
        .background(VQTheme.control)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(VQTheme.hairline, lineWidth: 1)
        }
    }
}

private struct CompactApprovalStrip: View {
    let approval: CommandApproval

    private var tint: Color {
        approval.tintName == "amber" ? VQTheme.amber : VQTheme.red
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(approval.title)
                    .font(.caption.weight(.semibold))
                Text(approval.detail)
                    .font(.caption2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(approval.risk)
                    .font(.caption2.weight(.semibold))
                ApprovalActionButtons(approval: approval, compact: true)
                    .frame(minWidth: 150)
            }
        }
        .foregroundStyle(tint)
        .padding(10)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.58), lineWidth: 1)
        }
    }
}

private struct CompactGuardrailStrip: View {
    let guardrail: ApprovalGuardrail

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(guardrail.title)
                    .font(.caption.weight(.semibold))
                Text(guardrail.detail)
                    .font(.caption2)
                    .lineLimit(1)
            }
            Spacer()
            Text(guardrail.risk)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(guardrail.tint)
        .padding(10)
        .background(guardrail.tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(guardrail.tint.opacity(0.58), lineWidth: 1)
        }
    }
}

private struct PhoneDeviceCard: View {
    let name: String
    let detail: String
    let status: DeviceStatus

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: name.contains("mini") ? "macmini" : "laptopcomputer")
                .font(.title3)
                .foregroundStyle(VQTheme.secondaryText)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
                Label(status.title, systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(status.tint)
            }
            Spacer()
        }
        .padding(10)
        .commandPanel()
    }
}

private struct PhoneArtifactsPanel: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.tr("Recent Artifacts"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VQTheme.secondaryText)
                Spacer()
                if !store.remoteArtifacts.isEmpty {
                    Text(L10n.tr("View All"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(VQTheme.accent)
                }
            }
            if store.remoteArtifacts.isEmpty {
                Text(L10n.tr("No artifacts yet"))
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
            }
            ForEach(store.remoteArtifacts.prefix(2)) { artifact in
                HStack {
                    Image(systemName: artifact.type.lowercased().contains("image") || ["png", "jpg", "jpeg"].contains(artifact.type.lowercased()) ? "photo" : "shippingbox")
                        .foregroundStyle(VQTheme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(artifact.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                        Text(artifact.type)
                            .font(.caption2)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                    Spacer()
                }
            }
        }
        .padding(10)
        .commandPanel()
    }
}

private struct PhoneProjectStatusPanel: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("Project Status"))
                .font(.caption.weight(.bold))
                .foregroundStyle(VQTheme.secondaryText)
            HStack {
                Text(VQDisplay.workspaceName(store.workspace))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                    .lineLimit(1)
                Spacer()
                Text(VQDisplay.workspaceStatus(store.workspace))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VQDisplay.workspaceStatusTint(store.workspace))
                    .lineLimit(1)
            }
            HStack {
                Text(L10n.tr("Branch"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                Spacer()
                Text(store.workspace.branchLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(1)
            }
            NavigationLink(value: AppSection.projects) {
                Text(L10n.tr("View All Projects ->"))
                    .frame(maxWidth: .infinity)
            }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(VQTheme.accent)
        }
        .padding(10)
        .commandPanel()
    }
}

private struct CommandButtonStyle: ButtonStyle {
    var tint: Color = VQTheme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(VQTheme.control.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(VQTheme.hairline, lineWidth: 1)
            }
    }
}

private extension View {
    func commandPanel() -> some View {
        background {
            ZStack {
                VQTheme.elevated
                LinearGradient(
                    colors: [Color.white.opacity(0.030), Color.clear, Color.black.opacity(0.040)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(VQTheme.hairline, lineWidth: 1)
            }
    }
}

private extension CommandLogEntry {
    var statusSymbol: String {
        switch stream {
        case "ok": "v"
        case "warn": "!"
        case "approval": "!"
        default: ">"
        }
    }

    var statusColor: Color {
        switch stream {
        case "ok": VQTheme.green
        case "warn": VQTheme.amber
        case "approval": VQTheme.red
        default: VQTheme.secondaryText
        }
    }
}

private extension CommandRun {
    var shortID: String {
        String(id.uuidString.prefix(8)).lowercased()
    }
}

extension Date {
    var commandTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: self)
    }
}

private extension RunPhase {
    var commandTitle: String {
        switch self {
        case .requirements: L10n.tr("Requirements")
        case .implementation: L10n.tr("Implementation")
        case .testing: L10n.tr("Testing")
        case .github: "GitHub"
        case .deploy: L10n.tr("Deploy")
        }
    }
}

private extension CommandRuntime {
    var commandPlaceholder: String {
        switch self {
        case .hermesAgent:
            L10n.tr("Send instructions to Hermes...")
        case .codexDirect:
            L10n.tr("Send instructions to Codex...")
        case .claudeDirect:
            L10n.tr("Send instructions to Claude...")
        case .localShell:
            L10n.tr("Enter a shell command...")
        }
    }

    var dashboardSectionTitle: String {
        switch self {
        case .hermesAgent:
            L10n.tr("Hermes command")
        case .codexDirect, .claudeDirect:
            L10n.tr("Direct run")
        case .localShell:
            L10n.tr("Shell command")
        }
    }
}
