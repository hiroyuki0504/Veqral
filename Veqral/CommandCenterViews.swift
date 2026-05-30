import SwiftUI

struct AppearanceToggleButton: View {
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.dark.rawValue

    private var mode: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .dark
    }

    var body: some View {
        Button {
            appearanceMode = mode == .dark ? AppearanceMode.light.rawValue : AppearanceMode.dark.rawValue
        } label: {
            Image(systemName: mode.toggleSymbol)
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
        .help(mode.toggleTitle)
    }
}

struct CommandCenterSidebar: View {
    @EnvironmentObject private var store: CommandCenterStore
    @Binding var selection: AppSection?

    private var primary: [(AppSection, String, String, Int?)] {
        [
            (.home, "Command", "terminal", nil),
            (.runs, "Active Runs", "scope", store.runs.count),
            (.approvals, "承認待ち", "exclamationmark.triangle", store.pendingApprovals().count),
            (.projects, "Projects", "folder", nil),
            (.agents, "Agents", "person.3.sequence", nil),
            (.requirements, "Context Packs", "doc.badge.gearshape", nil),
            (.memory, "Models", "cpu", nil),
            (.devices, "Devices", "display", nil),
            (.artifacts, "Artifacts", "doc.richtext", nil)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("9:41 AM")
                Text("Tue May 13")
                Spacer()
                AppearanceToggleButton()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(VQTheme.ink)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 8) {
                        ForEach(primary, id: \.1) { item in
                            SidebarActionRow(
                                title: item.1,
                                symbol: item.2,
                                count: item.3,
                                isSelected: selection == item.0,
                                isWarning: item.0 == .approvals
                            ) {
                                selection = item.0
                            }
                        }
                    }

                    SidebarSectionTitle("Favorites")
                    VStack(spacing: 10) {
                        FavoriteRow(color: VQTheme.amber, title: "Acme Web Platform")
                        FavoriteRow(color: VQTheme.accent, title: "Data Pipeline")
                        FavoriteRow(color: VQTheme.violet, title: "iOS Companion")
                    }
                }
                .padding(.horizontal, 10)
            }

            Spacer(minLength: 12)

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
                    Text("Jordan Devlin")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    Text("Pro Plan")
                        .font(.caption2)
                        .foregroundStyle(VQTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VQTheme.secondaryText)
            }
            .padding(10)
            .background(VQTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(VQTheme.hairline, lineWidth: 1)
            }
            .padding(10)
        }
        .background(VQTheme.sidebar)
    }
}

struct CommandCenterRunView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var selectedSurface = WorkSurface.terminal

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let run = store.selectedRun {
                        RunHeader(run: run)
                        RunPhaseTracker(run: run)
                        CommandSubmitPanel()

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
                    } else {
                        CommandSubmitPanel()
                    }
                }
                .padding(18)
            }

            RunStatusBar(run: store.selectedRun)
        }
        .background(VQTheme.canvas)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CommandCenterInspectorView: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Run Inspector")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                    .padding(.top, 18)

                InspectorPanel(title: "承認待ち", count: store.pendingApprovals().count) {
                    VStack(spacing: 8) {
                        ForEach(store.pendingApprovals(limit: 3)) { approval in
                            InspectorApprovalRow(approval: approval)
                        }
                        Button("承認をすべて表示 ->", action: {})
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VQTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 2)
                    }
                }

                InspectorPanel(title: "Context Pack", trailing: "同期済み") {
                    InspectorLinkedRow(
                        symbol: "doc.badge.gearshape",
                        title: "Acme Web Platform Pack",
                        detail: "2分前更新 - 126 files"
                    )
                }

                InspectorPanel(title: "担当Agent") {
                    VStack(spacing: 8) {
                        InspectorAgentRow(color: .blue, title: "PM", detail: "Product Manager", status: VQTheme.green)
                        InspectorAgentRow(color: VQTheme.violet, title: "Architect", detail: "System Architect", status: VQTheme.green)
                        InspectorAgentRow(color: VQTheme.amber, title: "Reviewer", detail: "Code Reviewer", status: VQTheme.amber)
                        InspectorAgentRow(color: VQTheme.ink, title: "Claude", detail: "Implementer", status: VQTheme.accent)
                    }
                }

                InspectorPanel(title: "Mac Device") {
                    InspectorLinkedRow(symbol: "laptopcomputer", title: "MacBook Pro", detail: "16-inch - M3 Pro", trailing: "オンライン")
                }

                InspectorPanel(title: "Model") {
                    InspectorLinkedRow(symbol: "asterisk.circle.fill", title: "Claude 3.5 Sonnet", detail: "Context Window 200k")
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
                    Text("Command")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(VQTheme.ink)
                    Spacer()
                    AppearanceToggleButton()
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(VQTheme.ink)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)

                PhoneSectionHeader(title: "Active Runs", count: nil)
                VStack(spacing: 0) {
                    ForEach(Array(store.runs.prefix(5))) { run in
                        PhoneRunRow(run: run)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.selectRun(run.id)
                            }
                        if run.id != store.runs.prefix(5).last?.id {
                            Divider().overlay(VQTheme.hairline)
                        }
                    }
                }
                .commandPanel()

                PhoneSectionHeader(title: "Command", count: nil, showAction: false)
                PhoneComposer()

                PhoneSectionHeader(title: "承認待ち", count: store.pendingApprovals().count)
                VStack(spacing: 8) {
                    ForEach(store.pendingApprovals(limit: 3)) { approval in
                        CompactApprovalStrip(approval: approval)
                    }
                }

                PhoneSectionHeader(title: "Devices", count: nil, trailing: "正常")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    PhoneDeviceCard(name: "MacBook Pro", detail: "16-inch - M3 Pro")
                    PhoneDeviceCard(name: "Mac mini", detail: "M2 Pro")
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    PhoneArtifactsPanel()
                    PhoneProjectStatusPanel()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(VQTheme.canvas.ignoresSafeArea())
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
}

private struct SidebarActionRow: View {
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
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? VQTheme.ink : VQTheme.secondaryText)
                    .lineLimit(1)
                Spacer()
                if let count {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(isWarning ? VQTheme.red : VQTheme.control)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(isSelected ? VQTheme.control : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
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
                Label("Active Runsへ戻る", systemImage: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.accent)
                Spacer()
                Button(action: store.pauseOrResumeSelectedRun) {
                    Label(run.status == .waiting ? "再開" : "一時停止", systemImage: run.status == .waiting ? "play" : "pause")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(CommandButtonStyle())
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(CommandButtonStyle())
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(run.title)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(VQTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                StatusPill(title: run.status.title, tint: run.status.tint)
                Spacer()
            }

            HStack(spacing: 10) {
                Label(run.workingDirectory, systemImage: "folder")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(run.elapsedLabel)に開始")
                Text("Run ID 7f3b2e14")
                Image(systemName: "doc.on.doc")
            }
            .font(.caption)
            .foregroundStyle(VQTheme.secondaryText)
        }
    }
}

private struct RunPhaseTracker: View {
    let run: CommandRun

    private var steps: [(String, String, Color, Bool)] {
        [
            ("Plan", "完了", VQTheme.green, true),
            ("実装", run.status == .failed ? "失敗" : "進行中", run.status == .failed ? VQTheme.red : VQTheme.green, run.progress > 0.1),
            ("Test", run.status == .complete ? "完了" : "待機中", run.status == .complete ? VQTheme.green : VQTheme.accent, run.progress > 0.55),
            ("Review", run.status == .approval ? "承認待ち" : "待機中", run.status == .approval ? VQTheme.amber : VQTheme.mutedText, run.status == .approval),
            ("Complete", run.status == .complete ? "完了" : "待機中", run.status == .complete ? VQTheme.green : VQTheme.mutedText, run.status == .complete)
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
    }
}

private struct CommandSubmitPanel: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("やりたいこと、またはMacで実行するコマンド", text: $store.commandDraft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .lineLimit(1...3)
                    .padding(10)
                    .background(VQTheme.control.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onSubmit {
                        store.submitDraft()
                    }

                Button(action: store.submitDraft) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                }
                .buttonStyle(CommandButtonStyle(tint: VQTheme.accent))
                .help("Run")
            }

            #if targetEnvironment(macCatalyst)
            HStack(spacing: 8) {
                Image(systemName: "folder")
                TextField("Working directory", text: $store.workingDirectory)
                    .textFieldStyle(.plain)
                    .font(.caption.monospaced())
            }
            .foregroundStyle(VQTheme.secondaryText)
            .padding(.horizontal, 4)
            #else
            Text("iPhone/iPadではRunを作成して保存します。実行はMac版またはMac Host接続後に行います。")
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
            #endif
        }
        .padding(12)
        .commandPanel()
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
                        Text(surface.rawValue)
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
                    PreviewPlaceholder()
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
        .frame(minHeight: 470)
    }
}

private struct TerminalTranscript: View {
    let logs: [CommandLogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if logs.isEmpty {
                Text("まだログはありません。Commandを送るとここに表示されます。")
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
        .background(Color.black.opacity(0.001))
    }

}

private struct DiffListPanel: View {
    let diffs: [CommandDiffEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Diff")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    Text("\(diffs.count) files changed")
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                }
                Spacer()
                Text("+\(diffs.map(\.additions).reduce(0, +))  -\(diffs.map(\.deletions).reduce(0, +))")
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(VQTheme.green)
            }

            if diffs.isEmpty {
                Text("Git diffはまだありません。Mac版でgit管理下のフォルダを指定すると取得します。")
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

private struct PreviewPlaceholder: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "safari")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(VQTheme.accent)
            Text("PreviewはローカルWeb待ち")
                .font(.headline)
                .foregroundStyle(VQTheme.ink)
            Text("Mac Host接続後、スクリーンショットとWebプレビューをここに表示します。")
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
                Label(run?.model ?? "Local Shell", systemImage: "asterisk.circle.fill")
                    .foregroundStyle(VQTheme.amber)
                Divider().frame(height: 20).overlay(VQTheme.hairline)
                Label(run?.agent ?? "Local Mac", systemImage: "person.crop.circle")
                Divider().frame(height: 20).overlay(VQTheme.hairline)
                Label(run?.elapsedLabel ?? "待機中", systemImage: "timer")
                Divider().frame(height: 20).overlay(VQTheme.hairline)
                Label("\(Int((run?.progress ?? 0) * 100))%", systemImage: "gearshape")
                Divider().frame(height: 20).overlay(VQTheme.hairline)
                Circle().fill((run?.status ?? .waiting).tint).frame(width: 7, height: 7)
                Text(run?.status.title ?? "Waiting")
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
                if let count {
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
    @EnvironmentObject private var store: CommandCenterStore
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
            HStack {
                Spacer()
                Button("拒否") {
                    store.reject(approval)
                }
                    .buttonStyle(CommandButtonStyle())
                Button {
                    store.approve(approval)
                } label: {
                    Label("承認", systemImage: "checkmark")
                }
                .buttonStyle(CommandButtonStyle(tint: VQTheme.accent))
            }
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
    var trailing: String = "すべて表示"
    var showAction: Bool = true

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(VQTheme.secondaryText)
            if let count {
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
    let run: CommandRun

    var body: some View {
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
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }

    private var elapsed: String {
        run.elapsedLabel
    }
}

private struct PhoneComposer: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("何を作りますか？", text: $store.commandDraft)
                    .font(.caption)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        store.submitDraft()
                    }
                Button(action: store.submitDraft) {
                    Image(systemName: "arrow.up")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.white)
                        .background(VQTheme.secondaryText)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(VQTheme.control.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                CommandChip(title: "実装", symbol: "chevron.left.forwardslash.chevron.right")
                CommandChip(title: "Test", symbol: "flask")
                CommandChip(title: "", symbol: "ellipsis")
                Spacer()
            }
        }
        .padding(8)
        .commandPanel()
    }
}

private struct CommandChip: View {
    let title: String
    let symbol: String

    var body: some View {
        Button(action: {}) {
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

private struct CompactApprovalStrip: View {
    @EnvironmentObject private var store: CommandCenterStore
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
            VStack(spacing: 6) {
                Text(approval.risk)
                    .font(.caption2.weight(.semibold))
                Button("承認") {
                    store.approve(approval)
                }
                .font(.caption2.weight(.semibold))
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

private struct PhoneDeviceCard: View {
    let name: String
    let detail: String

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
                Label("オンライン", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(VQTheme.green)
            }
            Spacer()
        }
        .padding(10)
        .commandPanel()
    }
}

private struct PhoneArtifactsPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Artifacts")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VQTheme.secondaryText)
                Spacer()
                Text("すべて表示")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VQTheme.accent)
            }
            ForEach(MockData.artifacts.prefix(2)) { artifact in
                HStack {
                    Image(systemName: artifact.symbol)
                        .foregroundStyle(VQTheme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(artifact.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                        Text("2分前")
                            .font(.caption2)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                    Spacer()
                }
            }
            Rectangle()
                .fill(VQTheme.control)
                .frame(height: 40)
                .overlay {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                        Image(systemName: "doc.text.image")
                        Image(systemName: "chart.bar")
                    }
                    .foregroundStyle(VQTheme.secondaryText)
                }
        }
        .padding(10)
        .commandPanel()
    }
}

private struct PhoneProjectStatusPanel: View {
    private let projects = [
        ("Acme Web Platform", "順調", VQTheme.green),
        ("Data Pipeline", "順調", VQTheme.green),
        ("iOS Companion", "要注意", VQTheme.amber)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project Status")
                .font(.caption.weight(.bold))
                .foregroundStyle(VQTheme.secondaryText)
            ForEach(projects, id: \.0) { project in
                HStack {
                    Text(project.0)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                        .lineLimit(1)
                    Spacer()
                    Text(project.1)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(project.2)
                }
            }
            Button("Projectsをすべて表示 ->", action: {})
                .font(.caption2.weight(.semibold))
                .foregroundStyle(VQTheme.accent)
                .frame(maxWidth: .infinity)
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
        background(VQTheme.elevated)
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
        case .requirements: "Requirements"
        case .implementation: "実装"
        case .testing: "Test"
        case .github: "GitHub"
        case .deploy: "Deploy"
        }
    }
}
