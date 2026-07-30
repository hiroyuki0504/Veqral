import Foundation

public enum ForgeTaskState: String, Codable, CaseIterable, Sendable {
    case queued
    case running
    case needsAttention
    case succeeded
    case failed
    case cancelled

    public var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .cancelled:
            true
        case .queued, .running, .needsAttention:
            false
        }
    }
}

public enum ForgeHandoffState: String, Codable, Sendable {
    case notReady
    case readyForReview
    case blocked
}

public struct ForgeHandoff: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var taskID: String
    public var sourceWorkstreamID: String
    public var targetWorkstreamID: String?
    public var artifactIDs: [String]
    public var summary: String
    public var state: ForgeHandoffState
    public var createdAt: Date
    public var reviewedAt: Date?

    public init(id: String, taskID: String, sourceWorkstreamID: String, targetWorkstreamID: String?, artifactIDs: [String], summary: String, state: ForgeHandoffState, createdAt: Date, reviewedAt: Date?) {
        self.id = id
        self.taskID = taskID
        self.sourceWorkstreamID = sourceWorkstreamID
        self.targetWorkstreamID = targetWorkstreamID
        self.artifactIDs = artifactIDs
        self.summary = summary
        self.state = state
        self.createdAt = createdAt
        self.reviewedAt = reviewedAt
    }
}

public enum ForgeArtifactKind: String, Codable, Sendable {
    case handoff
    case document
    case diff
    case media
    case data
    case other
}

public struct ForgeArtifact: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var taskID: String
    public var runID: String
    public var kind: ForgeArtifactKind
    public var title: String
    public var reference: String

    public init(id: String, taskID: String, runID: String, kind: ForgeArtifactKind, title: String, reference: String) {
        self.id = id
        self.taskID = taskID
        self.runID = runID
        self.kind = kind
        self.title = title
        self.reference = reference
    }
}

public enum ForgeAttentionKind: String, Codable, Sendable {
    case approval
    case input
    case review
    case blocker
    case unsupported
}

public enum ForgeAttentionSeverity: String, Codable, Sendable {
    case low
    case high
}

public struct ForgeAttentionProjection: Codable, Equatable, Sendable {
    public var kind: ForgeAttentionKind
    public var detail: String
    public var raisedAt: Date
    public var approvalSeverity: ForgeAttentionSeverity?

    public init(kind: ForgeAttentionKind, detail: String, raisedAt: Date, approvalSeverity: ForgeAttentionSeverity?) {
        self.kind = kind
        self.detail = detail
        self.raisedAt = raisedAt
        self.approvalSeverity = approvalSeverity
    }
}

public struct ForgeRunProjection: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var taskID: String
    public var title: String
    public var missionKey: String
    public var missionTitle: String
    public var workstreamKey: String
    public var workstreamTitle: String
    public var state: ForgeTaskState
    public var startedAt: Date
    public var completedAt: Date?
    public var attentionSummary: String?
    public var approvalSeverity: ForgeAttentionSeverity?
    public var artifactCount: Int
    public var artifacts: [ForgeArtifact]
    public var attention: ForgeAttentionProjection?

    public init(id: String, taskID: String, title: String, missionKey: String, missionTitle: String, workstreamKey: String, workstreamTitle: String, state: ForgeTaskState, startedAt: Date, completedAt: Date?, attentionSummary: String?, approvalSeverity: ForgeAttentionSeverity?, artifactCount: Int) {
        precondition(!taskID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "A Forge run requires a Task ID")
        precondition(id != taskID, "Task identity must be distinct from Run attempt identity")
        self.id = id
        self.taskID = taskID
        self.title = title
        self.missionKey = missionKey
        self.missionTitle = missionTitle
        self.workstreamKey = workstreamKey
        self.workstreamTitle = workstreamTitle
        self.state = state
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.attentionSummary = attentionSummary
        self.approvalSeverity = approvalSeverity
        self.artifactCount = artifactCount
        self.artifacts = []
        self.attention = nil
    }
}

public struct ForgeTask: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var attemptIDs: [String]
    public var currentAttemptID: String
    public var title: String
    public var state: ForgeTaskState
    public var startedAt: Date
    public var completedAt: Date?
    public var attentionSummary: String?
    public var approvalSeverity: ForgeAttentionSeverity?
    public var artifactCount: Int
    public var artifacts: [ForgeArtifact]
    public var handoffs: [ForgeHandoff]

    public init(id: String, currentAttemptID: String, title: String, state: ForgeTaskState, startedAt: Date, completedAt: Date?, attentionSummary: String?, approvalSeverity: ForgeAttentionSeverity?, artifactCount: Int) {
        precondition(!currentAttemptID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "A Forge task requires a current Run attempt")
        precondition(id != currentAttemptID, "Task identity must be distinct from Run attempt identity")
        self.id = id
        self.attemptIDs = [currentAttemptID]
        self.currentAttemptID = currentAttemptID
        self.title = title
        self.state = state
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.attentionSummary = attentionSummary
        self.approvalSeverity = approvalSeverity
        self.artifactCount = artifactCount
        self.artifacts = []
        self.handoffs = []
    }

    public var handoffState: ForgeHandoffState {
        handoffs.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id < $1.id
        }
        .first?.state ?? .notReady
    }
}

public struct ForgeWorkstream: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var tasks: [ForgeTask]

    public init(id: String, title: String, tasks: [ForgeTask]) {
        self.id = id
        self.title = title
        self.tasks = tasks
    }

    public var activeTaskCount: Int {
        tasks.count { $0.state == .running }
    }

    public var attentionTaskCount: Int {
        tasks.count { $0.state == .needsAttention || $0.state == .failed }
    }
}

public struct ForgeMission: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var workstreams: [ForgeWorkstream]
    public var updatedAt: Date

    public init(id: String, title: String, workstreams: [ForgeWorkstream], updatedAt: Date) {
        self.id = id
        self.title = title
        self.workstreams = workstreams
        self.updatedAt = updatedAt
    }

    public var tasks: [ForgeTask] {
        workstreams.flatMap(\.tasks)
    }

    public var taskCount: Int {
        tasks.count
    }

    public var completionFraction: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.count(where: { $0.state == .succeeded })) / Double(tasks.count)
    }

    public var criticalTask: ForgeTask? {
        tasks
            .filter { $0.state != .succeeded }
            .sorted {
                let lhs = Self.criticalRank($0.state)
                let rhs = Self.criticalRank($1.state)
                if lhs != rhs { return lhs < rhs }
                if $0.startedAt != $1.startedAt { return $0.startedAt > $1.startedAt }
                return $0.id < $1.id
            }
            .first
    }

    private static func criticalRank(_ state: ForgeTaskState) -> Int {
        switch state {
        case .failed: 0
        case .needsAttention: 1
        case .running: 2
        case .queued: 3
        case .cancelled: 4
        case .succeeded: 5
        }
    }
}

public struct ForgeAttentionItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var missionID: String
    public var missionTitle: String
    public var taskID: String
    public var runID: String?
    public var taskTitle: String
    public var kind: ForgeAttentionKind
    public var approvalSeverity: ForgeAttentionSeverity?
    public var detail: String
    public var createdAt: Date

    public var allowsApproval: Bool {
        kind == .approval
    }

    public init(id: String, missionID: String, missionTitle: String, taskID: String, runID: String? = nil, taskTitle: String, kind: ForgeAttentionKind, approvalSeverity: ForgeAttentionSeverity?, detail: String, createdAt: Date) {
        self.id = id
        self.missionID = missionID
        self.missionTitle = missionTitle
        self.taskID = taskID
        self.runID = runID
        self.taskTitle = taskTitle
        self.kind = kind
        self.approvalSeverity = kind == .approval ? approvalSeverity : nil
        self.detail = detail
        self.createdAt = createdAt
    }
}

public struct ForgeSnapshot: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var missions: [ForgeMission]
    public var attention: [ForgeAttentionItem]
    public var artifacts: [ForgeArtifact]
    public var handoffs: [ForgeHandoff]

    public init(generatedAt: Date, missions: [ForgeMission], attention: [ForgeAttentionItem], artifacts: [ForgeArtifact] = [], handoffs: [ForgeHandoff] = []) {
        self.generatedAt = generatedAt
        self.missions = missions
        self.attention = attention
        self.artifacts = artifacts
        self.handoffs = handoffs
    }
}

public enum ForgeProjection {
    public static func snapshot(
        from runs: [ForgeRunProjection],
        handoffs: [ForgeHandoff] = [],
        generatedAt: Date = Date()
    ) -> ForgeSnapshot {
        let canonicalHandoffs = Dictionary(
            handoffs.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        .values
        .sorted { $0.id < $1.id }
        let handoffsByTaskID = Dictionary(grouping: canonicalHandoffs, by: \.taskID)
        let taskAttempts = Dictionary(grouping: runs) {
            normalized($0.taskID, fallback: $0.id)
        }
        let missionGroups = Dictionary(grouping: Array(taskAttempts.values)) {
            normalized(currentRun(in: $0).missionKey, fallback: "unassigned")
        }
        let missions = missionGroups.map { missionID, missionTaskAttempts in
            mission(
                from: missionTaskAttempts,
                id: missionID,
                handoffsByTaskID: handoffsByTaskID
            )
        }
        .sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id < $1.id
        }

        let currentRuns = taskAttempts.values.map(currentRun)
        let attention = (
            currentRuns.compactMap(attentionItem)
            + canonicalHandoffs.compactMap { reviewAttentionItem(from: $0, missions: missions) }
        )
        .sorted(by: attentionPrecedes)

        let artifacts = Dictionary(
            runs.flatMap(\.artifacts).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        .values
        .sorted { $0.id < $1.id }

        return ForgeSnapshot(
            generatedAt: generatedAt,
            missions: missions,
            attention: attention,
            artifacts: artifacts,
            handoffs: canonicalHandoffs
        )
    }

    private static func mission(
        from taskAttempts: [[ForgeRunProjection]],
        id: String,
        handoffsByTaskID: [String: [ForgeHandoff]]
    ) -> ForgeMission {
        let currentRuns = taskAttempts.map(currentRun).sorted {
            if $0.startedAt != $1.startedAt { return $0.startedAt > $1.startedAt }
            return $0.id < $1.id
        }
        let workstreamGroups = Dictionary(grouping: taskAttempts) {
            normalized(currentRun(in: $0).workstreamKey, fallback: "general")
        }
        let workstreams = workstreamGroups.map { workstreamID, workstreamTaskAttempts in
            let latest = workstreamTaskAttempts.map(currentRun).max {
                if $0.startedAt != $1.startedAt { return $0.startedAt < $1.startedAt }
                return $0.id > $1.id
            }
            let tasks = workstreamTaskAttempts.map { attempts in
                let current = currentRun(in: attempts)
                return task(
                    from: attempts,
                    handoffs: handoffsByTaskID[current.taskID] ?? []
                )
            }
            .sorted {
                if $0.startedAt != $1.startedAt { return $0.startedAt > $1.startedAt }
                return $0.id < $1.id
            }
            return ForgeWorkstream(
                id: workstreamID,
                title: normalized(latest?.workstreamTitle ?? workstreamID, fallback: workstreamID),
                tasks: tasks
            )
        }
        .sorted { $0.id < $1.id }

        let allAttempts = taskAttempts.flatMap { $0 }
        return ForgeMission(
            id: id,
            title: normalized(currentRuns.first?.missionTitle ?? id, fallback: id),
            workstreams: workstreams,
            updatedAt: allAttempts.compactMap { $0.completedAt ?? $0.startedAt }.max() ?? .distantPast
        )
    }

    private static func task(
        from attempts: [ForgeRunProjection],
        handoffs: [ForgeHandoff]
    ) -> ForgeTask {
        let orderedAttempts = attempts.sorted {
            if $0.startedAt != $1.startedAt { return $0.startedAt > $1.startedAt }
            return $0.id < $1.id
        }
        let current = currentRun(in: attempts)
        let artifacts = Dictionary(
            attempts.flatMap(\.artifacts).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        .values
        .sorted { $0.id < $1.id }
        var task = ForgeTask(
            id: current.taskID,
            currentAttemptID: current.id,
            title: normalized(current.title, fallback: "Task"),
            state: current.state,
            startedAt: attempts.map(\.startedAt).min() ?? current.startedAt,
            completedAt: current.completedAt,
            attentionSummary: current.attentionSummary,
            approvalSeverity: current.approvalSeverity,
            artifactCount: max(attempts.map(\.artifactCount).max() ?? 0, artifacts.count)
        )
        task.attemptIDs = orderedAttempts.map(\.id)
        task.currentAttemptID = current.id
        task.artifacts = artifacts
        task.handoffs = handoffs.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id < $1.id
        }
        return task
    }

    private static func currentRun(in attempts: [ForgeRunProjection]) -> ForgeRunProjection {
        precondition(!attempts.isEmpty, "A Forge task requires at least one run attempt")
        return attempts.sorted {
            if $0.startedAt != $1.startedAt { return $0.startedAt > $1.startedAt }
            return $0.id < $1.id
        }[0]
    }

    private static func reviewAttentionItem(
        from handoff: ForgeHandoff,
        missions: [ForgeMission]
    ) -> ForgeAttentionItem? {
        guard handoff.state == .readyForReview else { return nil }
        for mission in missions {
            if let task = mission.tasks.first(where: { $0.id == handoff.taskID }) {
                return ForgeAttentionItem(
                    id: "review:\(handoff.id)",
                    missionID: mission.id,
                    missionTitle: mission.title,
                    taskID: task.id,
                    runID: task.currentAttemptID,
                    taskTitle: task.title,
                    kind: .review,
                    approvalSeverity: nil,
                    detail: normalized(handoff.summary, fallback: "Handoff ready for review"),
                    createdAt: handoff.createdAt
                )
            }
        }
        return nil
    }

    private static func attentionPrecedes(_ lhs: ForgeAttentionItem, _ rhs: ForgeAttentionItem) -> Bool {
        let lhsRank = attentionRank(lhs)
        let rhsRank = attentionRank(rhs)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id < rhs.id
    }

    private static func attentionRank(_ item: ForgeAttentionItem) -> Int {
        switch (item.kind, item.approvalSeverity) {
        case (.unsupported, _), (.approval, .high): 0
        case (.blocker, _): 1
        case (.approval, .low), (.approval, nil): 2
        case (.input, _): 3
        case (.review, _): 4
        }
    }

    private static func attentionItem(from run: ForgeRunProjection) -> ForgeAttentionItem? {
        if let attention = run.attention {
            return ForgeAttentionItem(
                id: "\(attention.kind.rawValue):\(run.id)",
                missionID: normalized(run.missionKey, fallback: "unassigned"),
                missionTitle: normalized(
                    run.missionTitle,
                    fallback: normalized(run.missionKey, fallback: "unassigned")
                ),
                taskID: run.taskID,
                runID: run.id,
                taskTitle: normalized(run.title, fallback: "Task"),
                kind: attention.kind,
                approvalSeverity: attention.approvalSeverity,
                detail: normalized(attention.detail, fallback: "Human attention required"),
                createdAt: attention.raisedAt
            )
        }

        let kind: ForgeAttentionKind
        let defaultDetail: String
        let createdAt: Date
        switch run.state {
        case .needsAttention:
            kind = .unsupported
            defaultDetail = "Unclassified human attention required"
            createdAt = run.completedAt ?? run.startedAt
        case .failed:
            kind = .blocker
            defaultDetail = "Task failed"
            createdAt = run.completedAt ?? run.startedAt
        case .queued, .running, .succeeded, .cancelled:
            return nil
        }

        return ForgeAttentionItem(
            id: "\(kind.rawValue):\(run.taskID)",
            missionID: normalized(run.missionKey, fallback: "unassigned"),
            missionTitle: normalized(
                run.missionTitle,
                fallback: normalized(run.missionKey, fallback: "unassigned")
            ),
            taskID: run.taskID,
            runID: run.id,
            taskTitle: normalized(run.title, fallback: "Task"),
            kind: kind,
            approvalSeverity: nil,
            detail: normalized(run.attentionSummary ?? "", fallback: defaultDetail),
            createdAt: createdAt
        )
    }

    private static func normalized(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

private extension Collection {
    func count(where predicate: (Element) throws -> Bool) rethrows -> Int {
        try reduce(into: 0) { count, element in
            if try predicate(element) {
                count += 1
            }
        }
    }
}
