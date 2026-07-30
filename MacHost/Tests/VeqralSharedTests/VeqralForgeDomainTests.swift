import XCTest
import VeqralShared

final class VeqralForgeDomainTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000)

    func testProjectionGroupsRunsIntoMissionsAndWorkstreams() {
        let runs = [
            run(id: "run-1", mission: "veqral", missionTitle: "Veqral Forge", workstream: "hermes", state: .running, startedAt: now),
            run(id: "run-2", mission: "veqral", missionTitle: "Veqral Forge", workstream: "codex", state: .succeeded, startedAt: now.addingTimeInterval(-10)),
            run(id: "run-3", mission: "pipeline", missionTitle: "Restaurant Pipeline", workstream: "hermes", state: .queued, startedAt: now.addingTimeInterval(-20))
        ]

        let snapshot = ForgeProjection.snapshot(from: runs, generatedAt: now)

        XCTAssertEqual(snapshot.missions.map(\.id), ["veqral", "pipeline"])
        XCTAssertEqual(snapshot.missions[0].workstreams.map(\.id), ["codex", "hermes"])
        XCTAssertEqual(snapshot.missions[0].taskCount, 2)
    }

    func testAttentionQueuePrioritizesHighApproval() {
        let failed = run(
            id: "failed",
            mission: "m",
            missionTitle: "Mission",
            workstream: "hermes",
            state: .failed,
            startedAt: now
        )
        var approval = run(
            id: "approval",
            mission: "m",
            missionTitle: "Mission",
            workstream: "codex",
            state: .needsAttention,
            startedAt: now.addingTimeInterval(-60)
        )
        approval.attention = ForgeAttentionProjection(
            kind: .approval,
            detail: "本番反映の承認",
            raisedAt: now.addingTimeInterval(-30),
            approvalSeverity: .high
        )

        let snapshot = ForgeProjection.snapshot(from: [failed, approval], generatedAt: now)

        XCTAssertEqual(snapshot.attention.map(\.taskID), ["task-approval", "task-failed"])
        XCTAssertEqual(snapshot.attention.first?.kind, .approval)
        XCTAssertEqual(snapshot.attention.first?.approvalSeverity, .high)
    }

    func testInputAttentionRemainsInputAndCannotBeApproved() {
        var input = run(
            id: "question",
            mission: "m",
            missionTitle: "Mission",
            workstream: "hermes",
            state: .needsAttention,
            startedAt: now.addingTimeInterval(-300)
        )
        input.attention = ForgeAttentionProjection(
            kind: .input,
            detail: "Which deployment target?",
            raisedAt: now,
            approvalSeverity: nil
        )

        let snapshot = ForgeProjection.snapshot(from: [input], generatedAt: now)
        let item = try! XCTUnwrap(snapshot.attention.first)

        XCTAssertEqual(item.kind, .input)
        XCTAssertFalse(item.allowsApproval)
        XCTAssertEqual(item.createdAt, now)
    }

    func testAttentionRetainsTaskAndCurrentRunAttemptIdentity() {
        var approval = run(
            id: "run-2",
            taskID: "task-1",
            mission: "m",
            missionTitle: "Mission",
            workstream: "codex",
            state: .needsAttention,
            startedAt: now
        )

        approval.attention = ForgeAttentionProjection(
            kind: .approval,
            detail: "Approve",
            raisedAt: now,
            approvalSeverity: .high
        )

        let item = try! XCTUnwrap(
            ForgeProjection.snapshot(from: [approval], generatedAt: now).attention.first
        )

        XCTAssertEqual(item.taskID, "task-1")
        XCTAssertEqual(item.runID, "run-2")
    }

    func testMissionProgressCountsOnlySuccessfulTasksAndKeepsFailureCritical() {
        let runs = [
            run(id: "done", mission: "m", missionTitle: "Mission", workstream: "hermes", state: .succeeded, startedAt: now),
            run(id: "failed", mission: "m", missionTitle: "Mission", workstream: "hermes", state: .failed, startedAt: now.addingTimeInterval(-1)),
            run(id: "cancelled", mission: "m", missionTitle: "Mission", workstream: "hermes", state: .cancelled, startedAt: now.addingTimeInterval(-2)),
            run(id: "active", mission: "m", missionTitle: "Mission", workstream: "hermes", state: .running, startedAt: now.addingTimeInterval(-3))
        ]

        let mission = ForgeProjection.snapshot(from: runs, generatedAt: now).missions[0]

        XCTAssertEqual(mission.completionFraction, 1.0 / 4.0, accuracy: 0.0001)
        XCTAssertEqual(mission.criticalTask?.id, "task-failed")
    }

    func testFailureUsesCompletionTimeAndDoesNotReuseApprovalSeverity() {
        let failed = run(
            id: "failed",
            mission: "m",
            missionTitle: "Mission",
            workstream: "hermes",
            state: .failed,
            startedAt: now.addingTimeInterval(-60),
            attentionSummary: "Execution failed",
            approvalSeverity: .high
        )

        let item = try! XCTUnwrap(
            ForgeProjection.snapshot(from: [failed], generatedAt: now).attention.first
        )

        XCTAssertEqual(item.kind, .blocker)
        XCTAssertNil(item.approvalSeverity)
        XCTAssertEqual(item.createdAt, failed.completedAt)
    }

    func testArtifactRetainsIdentityKindReferenceAndTaskRelationship() {
        let artifact = ForgeArtifact(
            id: "artifact-1",
            taskID: "task-1",
            runID: "run-1",
            kind: .handoff,
            title: "Verified handoff",
            reference: "artifact://run-1/artifact-1"
        )
        var projectedRun = run(
            id: "run-1",
            taskID: "task-1",
            mission: "m",
            missionTitle: "Mission",
            workstream: "hermes",
            state: .succeeded,
            startedAt: now
        )

        projectedRun.artifacts = [artifact]

        let snapshot = ForgeProjection.snapshot(from: [projectedRun], generatedAt: now)
        let task = snapshot.missions[0].workstreams[0].tasks[0]

        XCTAssertEqual(snapshot.artifacts, [artifact])
        XCTAssertEqual(task.id, "task-1")
        XCTAssertEqual(task.artifacts, [artifact])
    }

    func testSuccessfulTaskDoesNotInventHandoff() {
        let completed = run(
            id: "done",
            mission: "m",
            missionTitle: "Mission",
            workstream: "hermes",
            state: .succeeded,
            startedAt: now
        )

        let snapshot = ForgeProjection.snapshot(from: [completed], generatedAt: now)
        let task = snapshot.missions[0].workstreams[0].tasks[0]

        XCTAssertTrue(task.handoffs.isEmpty)
        XCTAssertEqual(task.handoffState, .notReady)
        XCTAssertTrue(snapshot.attention.isEmpty)
    }

    func testExplicitHandoffLinksArtifactsAndCreatesReviewAttention() {
        let handoff = ForgeHandoff(
            id: "handoff-1",
            taskID: "task-1",
            sourceWorkstreamID: "hermes",
            targetWorkstreamID: "review",
            artifactIDs: ["artifact-1"],
            summary: "Ready for human review",
            state: .readyForReview,
            createdAt: now,
            reviewedAt: nil
        )
        var completed = run(
            id: "run-1",
            taskID: "task-1",
            mission: "m",
            missionTitle: "Mission",
            workstream: "hermes",
            state: .succeeded,
            startedAt: now.addingTimeInterval(-60)
        )


        let snapshot = ForgeProjection.snapshot(
            from: [completed],
            handoffs: [handoff],
            generatedAt: now
        )
        let task = snapshot.missions[0].workstreams[0].tasks[0]
        let attention = try! XCTUnwrap(snapshot.attention.first)

        XCTAssertEqual(snapshot.handoffs, [handoff])
        XCTAssertEqual(task.handoffs, [handoff])
        XCTAssertEqual(task.handoffState, .readyForReview)
        XCTAssertEqual(attention.kind, .review)
        XCTAssertFalse(attention.allowsApproval)
        XCTAssertEqual(attention.createdAt, now)
    }

    func testMultipleRunAttemptsProjectAsOneTask() {
        var failedAttempt = run(
            id: "run-1",
            taskID: "task-1",
            mission: "m",
            missionTitle: "Mission",
            workstream: "hermes",
            state: .failed,
            startedAt: now.addingTimeInterval(-60)
        )
        var successfulRetry = run(
            id: "run-2",
            taskID: "task-1",
            mission: "m",
            missionTitle: "Mission",
            workstream: "codex",
            state: .succeeded,
            startedAt: now
        )


        let snapshot = ForgeProjection.snapshot(
            from: [failedAttempt, successfulRetry],
            generatedAt: now
        )
        let mission = snapshot.missions[0]
        let task = try! XCTUnwrap(mission.tasks.first)

        XCTAssertEqual(mission.taskCount, 1)
        XCTAssertEqual(task.id, "task-1")
        XCTAssertEqual(task.attemptIDs, ["run-2", "run-1"])
        XCTAssertEqual(task.currentAttemptID, "run-2")
        XCTAssertEqual(task.state, .succeeded)
        XCTAssertTrue(snapshot.attention.isEmpty)
    }

    private func run(
        id: String,
        taskID: String? = nil,
        mission: String,
        missionTitle: String,
        workstream: String,
        state: ForgeTaskState,
        startedAt: Date,
        attentionSummary: String? = nil,
        approvalSeverity: ForgeAttentionSeverity? = nil
    ) -> ForgeRunProjection {
        ForgeRunProjection(
            id: id,
            taskID: taskID ?? "task-\(id)",
            title: id,
            missionKey: mission,
            missionTitle: missionTitle,
            workstreamKey: workstream,
            workstreamTitle: workstream.capitalized,
            state: state,
            startedAt: startedAt,
            completedAt: state.isTerminal ? startedAt.addingTimeInterval(1) : nil,
            attentionSummary: attentionSummary,
            approvalSeverity: approvalSeverity,
            artifactCount: 0
        )
    }
}
