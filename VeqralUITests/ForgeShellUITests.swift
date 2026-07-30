import XCTest

final class ForgeShellUITests: XCTestCase {
    @MainActor
    func testMissionSurfaceIsPrimary() {
        let app = launchFixture()

        XCTAssertTrue(app.tabBars.buttons["ミッション"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["要対応"].exists)
        XCTAssertTrue(app.tabBars.buttons["接続"].exists)

        let mission = app.buttons["forge.mission.veqral-forge"]
        XCTAssertTrue(mission.waitForExistence(timeout: 3))
        mission.tap()

        XCTAssertTrue(app.staticTexts["Veqral Forge"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Hermes"].exists)
        XCTAssertTrue(app.buttons["forge.new-task"].exists)
    }

    @MainActor
    func testAttentionQueueAndConnectionStaySeparate() {
        let app = launchFixture()

        app.tabBars.buttons["要対応"].tap()
        XCTAssertTrue(app.buttons["forge.attention.approval-run"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Raw chat"].exists)

        app.tabBars.buttons["接続"].tap()
        XCTAssertTrue(app.otherElements["forge.connection.host"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["UI Test Mac"].exists)
        XCTAssertTrue(app.staticTexts["Codex"].exists)
        XCTAssertTrue(app.staticTexts["Claude"].exists)
        XCTAssertFalse(app.staticTexts["Shell"].exists)
        XCTAssertTrue(app.staticTexts["Shell はForge操作対象外です"].exists)
    }

    @MainActor
    func testAttentionRefreshFailureNeverAppearsAsAnEmptyQueue() {
        let app = launchFixture(staleAttention: true)

        app.tabBars.buttons["要対応"].tap()
        XCTAssertTrue(app.staticTexts["要対応の状態を確認できません"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["対応待ちはありません"].exists)
        XCTAssertTrue(app.buttons["forge.attention.approval-run"].exists)
    }

    @MainActor
    func testInputAttentionCannotUseApprovalControls() {
        let app = launchFixture()

        app.tabBars.buttons["要対応"].tap()
        let input = app.buttons["forge.attention.input-run"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.tap()

        XCTAssertTrue(app.staticTexts["AIから確認があります"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["内容を承認"].exists)
        XCTAssertFalse(app.buttons["却下"].exists)
    }

    @MainActor
    func testRunningInteractionAppearsAsInputAttention() {
        let app = launchFixture()

        app.tabBars.buttons["要対応"].tap()
        let runningInput = app.buttons["forge.attention.running-input-run"]
        XCTAssertTrue(runningInput.waitForExistence(timeout: 2))
        runningInput.tap()

        XCTAssertTrue(app.staticTexts["Need a release note before continuing."].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["内容を承認"].exists)
        XCTAssertFalse(app.buttons["却下"].exists)
    }

    @MainActor
    func testStreamInteractionUpdatesTheAttentionQueue() {
        let app = launchFixture()

        let mission = app.buttons["forge.mission.veqral-forge"]
        XCTAssertTrue(mission.waitForExistence(timeout: 2))
        mission.tap()
        let task = app.buttons["forge.task.chat-retry-task"]
        XCTAssertTrue(task.waitForExistence(timeout: 2))
        task.tap()

        XCTAssertTrue(app.staticTexts["Provide the late deployment choice."].waitForExistence(timeout: 2))
        app.tabBars.buttons["要対応"].tap()
        XCTAssertTrue(app.buttons["forge.attention.active-run"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testTaskDetailResolvesTheCurrentAttempt() {
        let app = launchFixture()

        let mission = app.buttons["forge.mission.veqral-forge"]
        XCTAssertTrue(mission.waitForExistence(timeout: 2))
        mission.tap()

        let task = app.buttons["forge.task.chat-retry-task"]
        XCTAssertTrue(task.waitForExistence(timeout: 2))
        task.tap()

        XCTAssertTrue(app.otherElements["forge.current-attempt.active-run"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.otherElements["forge.current-attempt.old-attempt"].exists)
    }

    @MainActor
    func testHighApprovalRequiresContextConfirmation() {
        let app = launchFixture()

        app.tabBars.buttons["要対応"].tap()
        let approval = app.buttons["forge.attention.approval-run"]
        XCTAssertTrue(approval.waitForExistence(timeout: 2))
        approval.tap()

        let approve = app.buttons["内容を承認"]
        XCTAssertTrue(approve.waitForExistence(timeout: 2))
        approve.tap()

        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "依頼:")).firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "変更:")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "成果物:")).firstMatch.exists)
        XCTAssertTrue(app.buttons["承認して続行"].exists)
    }

    @MainActor
    func testNewTaskOnlyOffersSupportedRuntimes() {
        let app = launchFixture()

        let create = app.buttons["forge.new-task"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 30))
        create.tap()

        XCTAssertTrue(app.navigationBars["Taskを作成"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["Hermes"].exists)
        XCTAssertTrue(app.buttons["Codex"].exists)
        XCTAssertTrue(app.buttons["Claude"].exists)
        XCTAssertFalse(app.buttons["Shell"].exists)
    }

    @MainActor
    private func launchFixture(staleAttention: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["VEQRAL_UI_TEST_FIXTURE"] = "1"
        if staleAttention {
            app.launchEnvironment["VEQRAL_UI_TEST_STALE_ATTENTION"] = "1"
        }
        app.launch()
        return app
    }
}
