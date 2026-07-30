import Foundation

/// Converts Mac Host wire models into Forge-owned Mission/Task/Artifact/Handoff projections.
enum ForgeRemoteProjection {
    static func snapshot(
        from runs: [RemoteRunRecord],
        artifactsByRunID: [String: [RemoteArtifactRecord]] = [:],
        handoffs: [RemoteHandoffRecord] = [],
        generatedAt: Date = Date()
    ) -> ForgeSnapshot {
        let projectedRuns = runs.map {
            projection(for: $0, artifacts: artifactsByRunID[$0.id] ?? [])
        }
        return ForgeProjection.snapshot(
            from: projectedRuns,
            handoffs: handoffs.map {
                ForgeHandoff(
                    id: $0.id,
                    taskID: $0.taskID,
                    sourceWorkstreamID: $0.sourceWorkstreamID,
                    targetWorkstreamID: $0.targetWorkstreamID,
                    artifactIDs: $0.artifactIDs,
                    summary: $0.summary,
                    state: $0.state,
                    createdAt: $0.createdAt,
                    reviewedAt: $0.reviewedAt
                )
            },
            generatedAt: generatedAt
        )
    }

    static func projection(
        for run: RemoteRunRecord,
        artifacts: [RemoteArtifactRecord] = []
    ) -> ForgeRunProjection {
        let mission = missionIdentity(for: run)
        let workstream = workstreamIdentity(for: run)
        let taskID = stableTaskID(for: run)
        var status = statusProjection(for: run)

        if workstream.runtime == nil {
            let detail = "Unsupported runtime '\(workstream.key)'. Manual review required."
            if status.state == .failed {
                status = StatusProjection(
                    state: .failed,
                    attention: ForgeAttentionProjection(
                        kind: .blocker,
                        detail: joined(status.attention?.detail, detail),
                        raisedAt: status.attention?.raisedAt ?? run.statusUpdatedAt ?? run.completedAt ?? run.startedAt,
                        approvalSeverity: nil
                    )
                )
            } else {
                status = StatusProjection(
                    state: .needsAttention,
                    attention: ForgeAttentionProjection(
                        kind: .unsupported,
                        detail: joined(status.attention?.detail, detail),
                        raisedAt: status.attention?.raisedAt ?? run.statusUpdatedAt ?? run.completedAt ?? run.startedAt,
                        approvalSeverity: nil
                    )
                )
            }
        }

        var projection = ForgeRunProjection(
            id: run.id,
            taskID: taskID,
            title: taskTitle(from: run.prompt),
            missionKey: mission.key,
            missionTitle: mission.title,
            workstreamKey: workstream.key,
            workstreamTitle: workstream.title,
            state: status.state,
            startedAt: run.startedAt,
            completedAt: run.completedAt,
            attentionSummary: status.attention?.detail,
            approvalSeverity: status.attention?.approvalSeverity,
            artifactCount: artifacts.count
        )
        projection.attention = status.attention
        projection.artifacts = artifacts.map {
            artifactProjection(from: $0, taskID: taskID, runID: run.id)
        }
        return projection
    }

    private struct Identity {
        var key: String
        var title: String
    }

    private struct WorkstreamIdentity {
        var key: String
        var title: String
        var runtime: ForgeRuntime?
    }

    private struct StatusProjection {
        var state: ForgeTaskState
        var attention: ForgeAttentionProjection?
    }

    private static func missionIdentity(for run: RemoteRunRecord) -> Identity {
        if let projectID = normalized(run.projectID) {
            return Identity(key: projectID, title: projectTitle(from: projectID))
        }
        if let workingDirectory = normalized(run.workingDirectory) {
            let pathTitle = normalized((workingDirectory as NSString).lastPathComponent) ?? workingDirectory
            return Identity(key: workingDirectory, title: pathTitle)
        }
        return Identity(key: "unassigned", title: "Unassigned")
    }

    private static func workstreamIdentity(for run: RemoteRunRecord) -> WorkstreamIdentity {
        // The Host treats old persisted runs without an engine as Hermes.
        let key = normalized(run.engine)?.lowercased() ?? ForgeRuntime.hermes.rawValue
        let runtime = ForgeRuntime(rawValue: key)
        return WorkstreamIdentity(
            key: key,
            title: runtime?.title ?? "Unsupported runtime: \(key)",
            runtime: runtime
        )
    }

    private static func stableTaskID(for run: RemoteRunRecord) -> String {
        if let taskID = normalized(run.taskID) {
            return taskID == run.id ? "legacy-task:\(taskID)" : taskID
        }
        if let chatID = normalized(run.chatID) { return "chat:\(chatID)" }
        return "legacy-run:\(run.id)"
    }

    private static func statusProjection(for run: RemoteRunRecord) -> StatusProjection {
        let status = run.status.trimmingCharacters(in: .whitespacesAndNewlines)
        let raisedAt = run.statusUpdatedAt ?? run.completedAt ?? run.startedAt
        let interactionDetail = normalized(run.interaction?.prompt)
        let approvalDetail = normalized(run.approvalReason)

        if let interactionDetail, status == "queued" || status == "running" {
            return StatusProjection(
                state: .needsAttention,
                attention: ForgeAttentionProjection(
                    kind: .input,
                    detail: interactionDetail,
                    raisedAt: raisedAt,
                    approvalSeverity: nil
                )
            )
        }

        switch status {
        case "queued":
            return StatusProjection(state: .queued, attention: nil)
        case "running":
            return StatusProjection(state: .running, attention: nil)
        case "waitingApproval":
            if let interactionDetail {
                return StatusProjection(
                    state: .needsAttention,
                    attention: ForgeAttentionProjection(
                        kind: .input,
                        detail: interactionDetail,
                        raisedAt: raisedAt,
                        approvalSeverity: nil
                    )
                )
            }
            if normalized(run.approvalProvenance?.state)?.lowercased() == "pending" {
                return StatusProjection(
                    state: .needsAttention,
                    attention: ForgeAttentionProjection(
                        kind: .approval,
                        detail: approvalDetail ?? "Approval required",
                        raisedAt: raisedAt,
                        approvalSeverity: severity(from: run.approvalSeverity)
                    )
                )
            }
            return StatusProjection(
                state: .needsAttention,
                attention: ForgeAttentionProjection(
                    kind: .unsupported,
                    detail: "Approval provenance is missing, unknown, or inconsistent. Manual review required.",
                    raisedAt: raisedAt,
                    approvalSeverity: nil
                )
            )
        case "needsAttention":
            let kind: ForgeAttentionKind = interactionDetail == nil ? .unsupported : .input
            return StatusProjection(
                state: .needsAttention,
                attention: ForgeAttentionProjection(
                    kind: kind,
                    detail: interactionDetail ?? approvalDetail ?? "Unclassified human input required",
                    raisedAt: raisedAt,
                    approvalSeverity: nil
                )
            )
        case "complete":
            return StatusProjection(state: .succeeded, attention: nil)
        case "failed":
            return StatusProjection(
                state: .failed,
                attention: ForgeAttentionProjection(
                    kind: .blocker,
                    detail: interactionDetail ?? approvalDetail ?? "Task failed",
                    raisedAt: run.completedAt ?? raisedAt,
                    approvalSeverity: nil
                )
            )
        case "cancelled":
            return StatusProjection(state: .cancelled, attention: nil)
        default:
            let displayedStatus = status.isEmpty ? "<empty>" : status
            return StatusProjection(
                state: .needsAttention,
                attention: ForgeAttentionProjection(
                    kind: .unsupported,
                    detail: "Unknown run status '\(displayedStatus)'. Manual review required.",
                    raisedAt: raisedAt,
                    approvalSeverity: nil
                )
            )
        }
    }

    private static func severity(from rawValue: String?) -> ForgeAttentionSeverity {
        switch normalized(rawValue)?.lowercased() {
        case "low": .low
        // Medium/unknown values fail closed to high until the Host emits low/high only.
        case "high", "medium", .none: .high
        default: .high
        }
    }

    private static func artifactProjection(
        from artifact: RemoteArtifactRecord,
        taskID: String,
        runID: String
    ) -> ForgeArtifact {
        ForgeArtifact(
            id: artifact.id,
            taskID: taskID,
            runID: runID,
            kind: artifactKind(from: artifact.type),
            title: normalized(artifact.title) ?? artifact.id,
            reference: artifact.path
        )
    }


    private static func artifactKind(from rawType: String) -> ForgeArtifactKind {
        let type = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if type == "handoff" { return .handoff }
        if ["diff", "patch"].contains(type) { return .diff }
        if ["image", "audio", "video"].contains(type) { return .media }
        if ["json", "csv", "data"].contains(type) { return .data }
        if ["markdown", "text", "document", "pdf"].contains(type) { return .document }
        return .other
    }

    private static func projectTitle(from projectID: String) -> String {
        let words = projectID
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard words.count > 1 else { return projectID }
        return words.map { word in
            guard let first = word.first else { return word }
            return first.uppercased() + word.dropFirst()
        }
        .joined(separator: " ")
    }

    private static func taskTitle(from prompt: String) -> String {
        let firstMeaningfulLine = prompt
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .compactMap(normalized)
            .first ?? "Task"
        let limit = 120
        guard firstMeaningfulLine.count > limit else { return firstMeaningfulLine }
        return String(firstMeaningfulLine.prefix(limit - 1)) + "…"
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func joined(_ first: String?, _ second: String) -> String {
        guard let first = normalized(first) else { return second }
        return "\(first) \(second)"
    }
}
