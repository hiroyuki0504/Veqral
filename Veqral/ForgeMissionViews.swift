import SwiftUI

struct ForgeMissionListView: View {
    @EnvironmentObject private var store: ForgeStore
    @Binding var showsNewTask: Bool

    private var missions: [ForgeMission] { store.projection.missions }
    private var activeCount: Int {
        missions.flatMap(\.tasks).count { $0.state == .running }
    }

    var body: some View {
        Group {
            if store.host == nil {
                ForgeEmptyState(
                    symbol: "macbook.and.iphone",
                    title: "Macと接続してください",
                    message: "Mac Hostのペアリングリンクは「接続」タブから登録できます。"
                )
            } else if missions.isEmpty {
                ForgeEmptyState(
                    symbol: "scope",
                    title: "Missionはまだありません",
                    message: "最初のTaskを作成すると、MissionとWorkstreamが自動で整理されます。",
                    actionTitle: "Taskを作成",
                    action: { showsNewTask = true }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForgeOverviewCard(
                            missionCount: missions.count,
                            activeCount: activeCount,
                            attentionCount: store.projection.attention.count
                        )
                        ForEach(missions) { mission in
                            NavigationLink {
                                ForgeMissionDetailView(missionID: mission.id)
                            } label: {
                                ForgeMissionCard(mission: mission)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("forge.mission.\(mission.id.forgeAccessibilitySlug)")
                        }
                    }
                    .padding()
                }
                .refreshable { try? await store.refresh() }
            }
        }
        .navigationTitle("Veqral Forge")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ForgeConnectionBadge(isConnected: store.health?.status == "ok")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsNewTask = true
                } label: {
                    Label("Taskを作成", systemImage: "plus")
                }
                .disabled(store.host == nil)
                .accessibilityIdentifier("forge.new-task")
            }
        }
    }
}

private struct ForgeOverviewCard: View {
    let missionCount: Int
    let activeCount: Int
    let attentionCount: Int

    var body: some View {
        ForgeCard {
            Text("現在の状況")
                .font(.headline)
            HStack(spacing: 12) {
                ForgeMetric(value: "\(missionCount)", label: "Mission", tint: ForgeTheme.accent)
                ForgeMetric(value: "\(activeCount)", label: "実行中", tint: ForgeTheme.running)
                ForgeMetric(value: "\(attentionCount)", label: "要対応", tint: attentionCount == 0 ? ForgeTheme.success : ForgeTheme.approval)
            }
            .padding(.top, 6)
        }
    }
}

private struct ForgeMissionCard: View {
    let mission: ForgeMission

    var body: some View {
        ForgeCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(mission.title.forgeDisplayTitle)
                        .font(.headline)
                    Text("\(mission.workstreams.count) Workstream ・ \(mission.taskCount) Task")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            ProgressView(value: mission.completionFraction)
                .tint(ForgeTheme.success)
                .padding(.vertical, 4)
            if let critical = mission.criticalTask {
                HStack(spacing: 8) {
                    ForgeStatusPill(state: critical.state)
                    Text(critical.title)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("すべてのTaskが完了", systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(ForgeTheme.success)
            }
        }
    }
}

struct ForgeMissionDetailView: View {
    @EnvironmentObject private var store: ForgeStore
    let missionID: String
    @State private var showsNewTask = false

    private var mission: ForgeMission? {
        store.projection.missions.first { $0.id == missionID }
    }

    var body: some View {
        Group {
            if let mission {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForgeCard {
                            HStack {
                                ForgeMetric(value: "\(mission.taskCount)", label: "Task", tint: ForgeTheme.accent)
                                ForgeMetric(
                                    value: "\(Int(mission.completionFraction * 100))%",
                                    label: "完了",
                                    tint: ForgeTheme.success
                                )
                            }
                            ProgressView(value: mission.completionFraction)
                                .tint(ForgeTheme.success)
                                .padding(.top, 6)
                        }

                        ForEach(mission.workstreams) { workstream in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(workstream.title)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(workstream.tasks.count) Task")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                ForEach(workstream.tasks) { task in
                                    NavigationLink {
                                        ForgeTaskDetailView(taskID: task.id)
                                    } label: {
                                        ForgeTaskRow(task: task)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("forge.task.\(task.id.forgeAccessibilitySlug)")
                                }
                            }
                        }
                    }
                    .padding()
                }
                .refreshable { try? await store.refresh() }
                .navigationTitle(mission.title.forgeDisplayTitle)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showsNewTask = true
                        } label: {
                            Label("Taskを作成", systemImage: "plus")
                        }
                        .accessibilityIdentifier("forge.new-task")
                    }
                }
                .sheet(isPresented: $showsNewTask) {
                    ForgeNewTaskView(initialMissionID: mission.id)
                        .environmentObject(store)
                }
            } else {
                ForgeEmptyState(symbol: "questionmark.folder", title: "Missionが見つかりません", message: "一覧を更新してください。")
            }
        }
    }
}

struct ForgeTaskRow: View {
    let task: ForgeTask

    var body: some View {
        ForgeCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: task.state.forgeSymbol)
                    .foregroundStyle(task.state.forgeTint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        ForgeStatusPill(state: task.state)
                        Text(task.startedAt.forgeRelativeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct ForgeAttentionQueueView: View {
    @EnvironmentObject private var store: ForgeStore

    var body: some View {
        TimelineView(PeriodicTimelineSchedule(from: Date(), by: 15.0)) { context in
            attentionList(at: context.date)
        }
        .navigationTitle("要対応")
        .task { await refreshAttention() }
    }

    private func attentionList(at date: Date) -> some View {
        List {
            if store.isAttentionStateStale(at: date) {
                Section {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("要対応の状態を確認できません", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(ForgeTheme.failure)
                        Text(store.runsRefreshErrorMessage ?? "最終更新から時間が経過しています。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let refreshedAt = store.lastRunsRefreshAt {
                            Text("最終更新: \(refreshedAt.formatted(date: .omitted, time: .standard))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text("下の項目は最後に確認できた内容です。操作時にはMac Hostの最新状態を再確認します。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 5)
                }
            }

            if !store.isAttentionStateStale(at: date), store.projection.attention.isEmpty {
                Section {
                    ForgeEmptyState(
                        symbol: "checkmark.circle",
                        title: "対応待ちはありません",
                        message: "承認・質問・blockerだけがここに集まります。"
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }

            ForEach(store.projection.attention) { item in
                NavigationLink {
                    ForgeTaskDetailView(taskID: item.taskID)
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Label(
                                item.kind.forgeTitle,
                                systemImage: item.kind.forgeSymbol
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(item.kind.forgeTint)
                            Spacer()
                            if let severity = item.approvalSeverity {
                                Text("リスク \(severity.forgeTitle)")
                                    .font(.caption2)
                                    .foregroundStyle(severity.forgeTint)
                            }
                        }
                        Text(item.taskTitle)
                            .font(.headline)
                        Text(item.missionTitle.forgeDisplayTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 5)
                }
                .accessibilityIdentifier("forge.attention.\((item.runID ?? item.taskID).forgeAccessibilitySlug)")
            }
        }
        .refreshable { await refreshAttention() }
    }

    @MainActor
    private func refreshAttention() async {
        do {
            try await store.refresh()
        } catch {
            // ForgeStore records a dedicated Run-list freshness error for this surface.
        }
    }
}

struct ForgeConnectionView: View {
    @EnvironmentObject private var store: ForgeStore
    @State private var pairingLink = ""
    @State private var isPairing = false
    @State private var message: String?

    var body: some View {
        Form {
            if let host = store.host {
                Section("Mac Host") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "macbook")
                                .font(.title2)
                                .foregroundStyle(ForgeTheme.accent)
                            VStack(alignment: .leading) {
                                Text(host.name)
                                    .font(.headline)
                                Text(host.endpoint)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent("接続", value: store.health?.status == "ok" ? "正常" : "未確認")
                        LabeledContent("Hermes", value: store.health?.hermesVersion ?? "未確認")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("forge.connection.host")
                }

                let supportedTools = (store.health?.toolStatuses ?? []).filter {
                    ForgeRuntime(rawValue: $0.engine.lowercased()) != nil
                }
                if !supportedTools.isEmpty {
                    Section("Runtime") {
                        ForEach(supportedTools) { tool in
                            HStack {
                                Text(tool.title)
                                Spacer()
                                Text(tool.isInstalled ? tool.versionSummary : "未導入")
                                    .foregroundStyle(tool.isKnownCompatible ? .secondary : ForgeTheme.approval)
                            }
                        }
                    }
                }

                let unsupportedTools = (store.health?.toolStatuses ?? []).filter {
                    ForgeRuntime(rawValue: $0.engine.lowercased()) == nil
                }
                if !unsupportedTools.isEmpty {
                    Section("未対応Runtime診断") {
                        ForEach(unsupportedTools) { tool in
                            Label("\(tool.title) はForge操作対象外です", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(ForgeTheme.approval)
                        }
                    }
                }

                Section {
                    Button("接続状態を更新") {
                        Task { await refresh() }
                    }
                }
            }

            Section("ペアリング") {
                Text("Mac Hostに表示された `veqral://pair` リンクを貼り付けます。コードや管理者パスワードは保存しません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("veqral://pair?...", text: $pairingLink, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.caption.monospaced())
                Button {
                    Task { await pair() }
                } label: {
                    if isPairing {
                        ProgressView()
                    } else {
                        Text(store.host == nil ? "Macと接続" : "別のMacと接続")
                    }
                }
                .disabled(pairingLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPairing)
            }
        }
        .navigationTitle("接続")
        .alert("接続結果", isPresented: messageBinding) {
            Button("閉じる") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    @MainActor
    private func pair() async {
        guard let url = URL(string: pairingLink.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            message = "ペアリングリンクを確認してください。"
            return
        }
        isPairing = true
        defer { isPairing = false }
        do {
            _ = try await store.pair(using: url, deviceName: "Veqral Forge")
            try await store.refresh()
            pairingLink = ""
            message = "Macと安全に接続しました。"
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func refresh() async {
        do {
            try await store.refresh()
            message = "接続状態を更新しました。"
        } catch {
            message = error.localizedDescription
        }
    }

    private var messageBinding: Binding<Bool> {
        Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )
    }
}

struct ForgeNewTaskView: View {
    @EnvironmentObject private var store: ForgeStore
    @Environment(\.dismiss) private var dismiss
    let initialMissionID: String?

    @State private var prompt = ""
    @State private var workingDirectory = ""
    @State private var missionID = ""
    @State private var runtime: ForgeRuntime = .hermes
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(initialMissionID: String? = nil) {
        self.initialMissionID = initialMissionID
        _missionID = State(initialValue: initialMissionID?.hasPrefix("/") == false ? (initialMissionID ?? "") : "")
        _workingDirectory = State(initialValue: initialMissionID?.hasPrefix("/") == true ? (initialMissionID ?? "") : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("AIに依頼する内容", text: $prompt, axis: .vertical)
                        .lineLimit(4...10)
                }
                Section("Mission") {
                    TextField("Mission ID（任意）", text: $missionID)
                        .textInputAutocapitalization(.never)
                    TextField("Mac上の作業フォルダ", text: $workingDirectory)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.caption.monospaced())
                }
                Section("Runtime") {
                    Picker("Runtime", selection: $runtime) {
                        ForEach(ForgeRuntime.allCases) { runtime in
                            Text(runtime.title).tag(runtime)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("モデルはMac側のresolverが選択します。アプリには固定しません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Taskを作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("開始") {
                        Task { await submit() }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .alert("Taskを開始できません", isPresented: errorBinding) {
                Button("閉じる") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var canSubmit: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await store.createRun(ForgeRunRequest(
                prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
                workingDirectory: workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines),
                runtime: runtime,
                projectID: missionID.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
            ))
            try await store.refreshRuns()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

