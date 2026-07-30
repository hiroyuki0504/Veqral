import SwiftUI

struct ForgeTaskDetailView: View {
    @EnvironmentObject private var store: ForgeStore
    let taskID: String

    @State private var detail: RemoteRunSnapshotResponse?
    @State private var liveEvents: [RemoteHostLogEvent] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingAction: ControlAction?
    @State private var pendingRunID: String?

    private enum ControlAction: String, Identifiable {
        case approve
        case reject
        case cancel
        case resume

        var id: String { rawValue }
    }

    private var task: ForgeTask? {
        store.projection.missions
            .flatMap(\.workstreams)
            .flatMap(\.tasks)
            .first { $0.id == taskID }
    }

    private var currentRunID: String? {
        task?.currentAttemptID
    }

    private var run: RemoteRunRecord? {
        guard let currentRunID else { return nil }
        if detail?.run.id == currentRunID { return detail?.run }
        return store.runs.first { $0.id == currentRunID }
    }

    private var attention: ForgeAttentionItem? {
        guard let currentRunID else { return nil }
        return store.projection.attention.first { $0.runID == currentRunID }
    }

    var body: some View {
        Group {
            if let run, let task {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        summary(run: run, task: task)
                        if attention?.kind == .input, let interaction = run.interaction {
                            interactionCard(interaction)
                        }
                        actionCard(run: run, task: task)
                        handoffCard(task: task)
                        artifactCard
                        diffCard
                        logCard
                    }
                    .padding()
                }
                .navigationTitle("Task")
                .navigationBarTitleDisplayMode(.inline)
                .refreshable {
                    guard let currentRunID else { return }
                    await load(runID: currentRunID)
                }
            } else if isLoading {
                ProgressView("Taskを読み込み中")
            } else {
                ForgeEmptyState(symbol: "questionmark.circle", title: "Taskが見つかりません", message: "Mac Hostから一覧を更新してください。")
            }
        }
        .task(id: currentRunID) {
            detail = nil
            liveEvents = []
            guard let currentRunID else { return }
            await load(runID: currentRunID)
            await streamEvents(runID: currentRunID)
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { pendingAction != nil },
                set: {
                    if !$0 {
                        pendingAction = nil
                        pendingRunID = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let action = pendingAction, let targetRunID = pendingRunID {
                Button(actionTitle(action), role: action == .approve || action == .cancel ? .destructive : nil) {
                    Task { await perform(action, runID: targetRunID) }
                }
                Button("戻る", role: .cancel) { pendingAction = nil }
            }
        } message: {
            Text(confirmationMessage)
        }
        .alert("操作を完了できません", isPresented: errorBinding) {
            Button("閉じる") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func summary(run: RemoteRunRecord, task: ForgeTask) -> some View {
        ForgeCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(task.title)
                        .font(.title3.bold())
                    Text(run.workingDirectory)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                ForgeStatusPill(state: task.state)
            }
            Divider().padding(.vertical, 4)
            if let runtime = ForgeRuntime(rawValue: (run.engine ?? "hermes").lowercased()) {
                LabeledContent("Runtime", value: runtime.title)
            } else {
                LabeledContent("未対応Runtime診断", value: run.engine ?? "unknown")
                    .foregroundStyle(ForgeTheme.approval)
            }
            LabeledContent("開始", value: run.startedAt.formatted(date: .abbreviated, time: .shortened))
            if let sessionID = run.sessionID {
                LabeledContent("Session", value: sessionID)
                    .font(.caption)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("forge.current-attempt.\(run.id.forgeAccessibilitySlug)")
    }

    @ViewBuilder
    private func interactionCard(_ interaction: CommandInteractionPrompt) -> some View {
        ForgeCard {
            Label("AIから確認があります", systemImage: "questionmark.bubble.fill")
                .font(.headline)
                .foregroundStyle(ForgeTheme.approval)
            Text(interaction.prompt)
                .padding(.vertical, 4)
            if interaction.isChoicePrompt {
                ForEach(interaction.choices) { choice in
                    Button(choice.label) {
                        Task { await submitInput(choice.value) }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                TextField("返信", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("返信を送る") {
                    Task { await submitInput(inputText) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @ViewBuilder
    private func actionCard(run: RemoteRunRecord, task: ForgeTask) -> some View {
        if task.state == .needsAttention || task.state == .running || task.state == .failed || task.state == .cancelled {
            ForgeCard {
                Text("操作")
                    .font(.headline)
                HStack {
                    if attention?.allowsApproval == true {
                        Button("内容を承認") {
                            Task { await prepareApproval() }
                        }
                            .buttonStyle(.borderedProminent)
                            .tint(ForgeTheme.approval)
                        Button("却下") { stage(.reject) }
                            .buttonStyle(.bordered)
                    }
                    if task.state == .running {
                        Button("実行を中止") { stage(.cancel) }
                            .buttonStyle(.bordered)
                            .tint(ForgeTheme.failure)
                    }
                    if task.state == .failed || task.state == .cancelled {
                        Button("再開") { stage(.resume) }
                            .buttonStyle(.borderedProminent)
                    }
                }
                if task.state == .needsAttention, attention?.allowsApproval != true {
                    Label(
                        attention?.detail ?? "分類できない要対応項目です。Mac上で内容を確認してください。",
                        systemImage: "lock.shield.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(ForgeTheme.failure)
                } else if attention?.approvalSeverity == .high {
                    Label("高リスク操作です。差分・成果物を確認してから承認してください。", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(ForgeTheme.failure)
                }
            }
        }
    }

    private func handoffCard(task: ForgeTask) -> some View {
        ForgeCard {
            Label("Handoff", systemImage: "arrowshape.turn.up.right.fill")
                .font(.headline)
            switch task.handoffState {
            case .readyForReview:
                Text("明示的なHandoffがあります。成果物と差分を確認し、次のTaskへ引き継げます。")
                    .foregroundStyle(ForgeTheme.success)
            case .blocked:
                Text("このTaskはblocker状態です。原因を確認して再開してください。")
                    .foregroundStyle(ForgeTheme.failure)
            case .notReady:
                Text("明示的なHandoffはまだありません。")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var artifactCard: some View {
        if let artifacts = detail?.artifacts, !artifacts.isEmpty {
            ForgeCard {
                Label("Artifacts", systemImage: "shippingbox.fill")
                    .font(.headline)
                ForEach(artifacts) { artifact in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(artifact.title)
                                .font(.subheadline.weight(.semibold))
                            Text(artifact.path)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: Int64(artifact.bytes), countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if artifact.id != artifacts.last?.id { Divider() }
                }
            }
        }
    }

    @ViewBuilder
    private var diffCard: some View {
        if let files = detail?.diff, !files.isEmpty {
            ForgeCard {
                Label("変更差分", systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                ForEach(Array(files.enumerated()), id: \.offset) { _, file in
                    HStack {
                        Text(file.path)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                        Spacer()
                        Text("+\(file.additions)")
                            .foregroundStyle(ForgeTheme.success)
                        Text("−\(file.deletions)")
                            .foregroundStyle(ForgeTheme.failure)
                    }
                }
            }
        }
    }

    private var logCard: some View {
        ForgeCard {
            DisclosureGroup("実行ログ（必要な時だけ表示）") {
                let events = liveEvents.isEmpty ? (detail?.logs ?? []) : liveEvents
                if events.isEmpty {
                    Text("ログはまだありません。")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                            Text("[\(event.stream)] \(VeqralRedactor.redact(event.message, limit: 2_000))")
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    @MainActor
    private func load(runID targetRunID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await store.snapshot(runID: targetRunID)
            guard currentRunID == targetRunID else { return }
            detail = snapshot
            liveEvents = snapshot.logs
        } catch {
            guard currentRunID == targetRunID else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func streamEvents(runID targetRunID: String) async {
        do {
            let stream = try store.stream(runID: targetRunID)
            for try await event in stream {
                await MainActor.run {
                    guard currentRunID == targetRunID else { return }
                    store.ingestStreamEvent(event)
                    liveEvents.append(event)
                    if liveEvents.count > 500 {
                        liveEvents.removeFirst(liveEvents.count - 500)
                    }
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard currentRunID == targetRunID else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func stage(_ action: ControlAction, runID targetRunID: String? = nil) {
        guard let targetRunID = targetRunID ?? currentRunID else {
            errorMessage = "現在のRun attemptを確認できません。一覧を更新してください。"
            return
        }
        pendingRunID = targetRunID
        pendingAction = action
    }

    @MainActor
    private func prepareApproval() async {
        guard let targetRunID = currentRunID else {
            errorMessage = "現在のRun attemptを確認できません。一覧を更新してください。"
            return
        }
        if attention?.approvalSeverity == .high {
            await load(runID: targetRunID)
            guard currentRunID == targetRunID, detail?.run.id == targetRunID else { return }
        }
        stage(.approve, runID: targetRunID)
    }

    @MainActor
    private func perform(_ action: ControlAction, runID targetRunID: String) async {
        pendingAction = nil
        pendingRunID = nil
        guard currentRunID == targetRunID else {
            errorMessage = "Run attemptが更新されたため操作を中止しました。最新状態を確認してください。"
            return
        }
        do {
            switch action {
            case .approve: try await store.approve(runID: targetRunID)
            case .reject: try await store.reject(runID: targetRunID)
            case .cancel: try await store.cancel(runID: targetRunID)
            case .resume: try await store.resume(runID: targetRunID)
            }
            try await store.refreshRuns()
            if let currentRunID {
                await load(runID: currentRunID)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func submitInput(_ value: String) async {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let targetRunID = currentRunID else { return }
        do {
            try await store.submitInput(trimmed, runID: targetRunID)
            inputText = ""
            try await store.refreshRuns()
            if let currentRunID {
                await load(runID: currentRunID)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var confirmationTitle: String {
        switch pendingAction {
        case .approve: "この操作を承認しますか？"
        case .reject: "この操作を却下しますか？"
        case .cancel: "実行を中止しますか？"
        case .resume: "Taskを再開しますか？"
        case nil: "確認"
        }
    }

    private var confirmationMessage: String {
        guard pendingAction == .approve else {
            return "この操作はMac Hostへ署名付きで送信されます。"
        }
        guard attention?.approvalSeverity == .high else {
            return "承認後、Mac上で処理が続行されます。管理者パスワードは送信されません。"
        }
        let prompt = VeqralRedactor.redact(run?.prompt ?? "", limit: 300)
        let files = detail?.diff.count ?? 0
        let additions = detail?.diff.reduce(0) { $0 + $1.additions } ?? 0
        let deletions = detail?.diff.reduce(0) { $0 + $1.deletions } ?? 0
        let artifacts = detail?.artifacts.count ?? 0
        return "依頼: \(prompt)\n変更: \(files)ファイル (+\(additions) / −\(deletions))\n成果物: \(artifacts)件\n内容を確認したうえでMac上の処理を続行します。管理者パスワードは送信されません。"
    }

    private func actionTitle(_ action: ControlAction) -> String {
        switch action {
        case .approve: "承認して続行"
        case .reject: "却下"
        case .cancel: "中止"
        case .resume: "再開"
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
