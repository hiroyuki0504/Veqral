import XCTest

@MainActor
final class Gate2AcceptanceUITests: XCTestCase {
    private var app: XCUIApplication!

    func testGate2Acceptance() throws {
        continueAfterFailure = false
        launchApp()
        pairWithMacHost()
        verifyTelemetry()
        verifyDiscordWebhook2xx()
        relaunchPreservingState()
        verifySavedCommandDraft()
        verifyMemoryVisibility()
        verifyHermesHistory()
        relaunchPreservingState()
        verifyVoiceTranscriptApprovalGate()
    }

    func testProductionRePairOnly() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-veqral-ui-testing",
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP"
        ]
        app.launchEnvironment = [
            "VEQRAL_UI_TESTING": "1",
            "VEQRAL_UI_TEST_RESET": "0",
            "VEQRAL_UI_TEST_PAIRING_URL": gate2Configuration(
                environment: "VEQRAL_GATE2_PAIRING_URL",
                infoKey: "VeqralGate2PairingURL",
                fallback: ""
            )
        ]
        addSystemPromptHandler()
        app.launch()
        handlePendingSystemPrompts()
        pairWithMacHost()
        verifyTelemetry()
    }

    func testInteractionRequiresExplicitInput() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-veqral-ui-testing"]
        app.launchEnvironment = [
            "VEQRAL_UI_TESTING": "1",
            "VEQRAL_UI_TEST_RESET": "1",
            "VEQRAL_UI_TEST_INTERACTION_FIXTURE": "1"
        ]
        app.launch()
        openSection(.approvals)

        XCTAssertTrue(
            app.descendants(matching: .any)["gate2.approval.interaction"].waitForExistence(timeout: 15),
            "Explicit interaction controls were not visible."
        )
        XCTAssertTrue(app.buttons["approval.interaction.choice.1"].exists, "The explicit negative choice was missing.")
        XCTAssertTrue(app.buttons["approval.interaction.choice.2"].exists, "The explicit positive choice was missing.")
        XCTAssertFalse(app.buttons["approval.action.approve"].exists, "Generic Approve must not appear for an interaction prompt.")
        XCTAssertFalse(app.buttons["approval.action.reject"].exists, "Generic Reject must not replace an explicit interaction response.")
    }

    private func launchApp() {
        app = XCUIApplication()
        app.launchArguments = [
            "-veqral-ui-testing",
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP"
        ]
        var launchEnvironment = [
            "VEQRAL_UI_TESTING": "1",
            "VEQRAL_UI_TEST_RESET": "1",
            "VEQRAL_UI_TEST_RUNTIME": "localShell",
            "VEQRAL_UI_TEST_WORKING_DIRECTORY": gate2Configuration(
                environment: "VEQRAL_GATE2_WORKING_DIRECTORY",
                infoKey: "VeqralGate2WorkingDirectory",
                fallback: "/Users/hiroyuki/Documents/Veqral"
            ),
            "VEQRAL_UI_TEST_PROJECT_ID": gate2Configuration(
                environment: "VEQRAL_GATE2_PROJECT_ID",
                infoKey: "VeqralGate2ProjectID",
                fallback: "gate2-xcuitest"
            ),
            "VEQRAL_UI_TEST_PROJECT_NAME": "Gate2 XCUITest",
            "VEQRAL_UI_TEST_VOICE_TRANSCRIPT": gate2Configuration(
                environment: "VEQRAL_GATE2_VOICE_TRANSCRIPT",
                infoKey: "VeqralGate2VoiceTranscript",
                fallback: "えっと 本番に deploy して .env の token を削除して"
            )
        ]
        let pairingURL = gate2Configuration(
            environment: "VEQRAL_GATE2_PAIRING_URL",
            infoKey: "VeqralGate2PairingURL",
            fallback: ""
        )
        if !pairingURL.isEmpty {
            launchEnvironment["VEQRAL_UI_TEST_PAIRING_URL"] = pairingURL
        }
        app.launchEnvironment = launchEnvironment
        addSystemPromptHandler()
        app.launch()
        handlePendingSystemPrompts()
    }

    private func gate2Configuration(environment: String, infoKey: String, fallback: String) -> String {
        if let value = ProcessInfo.processInfo.environment[environment]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }
        if let value = Bundle(for: Gate2AcceptanceUITests.self).object(forInfoDictionaryKey: infoKey) as? String {
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                return clean
            }
        }
        return fallback
    }

    private func relaunchPreservingState() {
        app.terminate()
        app.launchEnvironment["VEQRAL_UI_TEST_RESET"] = "0"
        app.launch()
    }

    private func pairWithMacHost() {
        openSection(.devices)
        let useLink = app.buttons["gate2.pairing.useLink"]
        XCTAssertTrue(useLink.waitForExistence(timeout: 15), "Pairing link button was not visible.")
        waitUntilHittable(useLink, timeout: 10)
        useLink.tap()

        let pairedState = app.descendants(matching: .any)["gate2.remote.pairedState"]
        XCTAssertTrue(pairedState.waitForText(containing: ["paired"], timeout: 30), "Mac Host pairing did not complete.")
    }

    private func verifyTelemetry() {
        openSection(.devices)
        let cpu = app.staticTexts["gate2.telemetry.cpu.value"]
        XCTAssertTrue(cpu.waitForExistence(timeout: 30), "CPU telemetry was not rendered.")
        XCTAssertTrue(app.staticTexts["gate2.telemetry.memory.value"].waitForExistence(timeout: 10), "Memory telemetry was not rendered.")
        XCTAssertTrue(app.staticTexts["gate2.telemetry.disk.value"].waitForExistence(timeout: 10), "Disk telemetry was not rendered.")
        XCTAssertTrue(app.staticTexts["gate2.telemetry.thermal.value"].waitForExistence(timeout: 10), "Thermal state was not rendered.")
        XCTAssertFalse((cpu.label as NSString).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "CPU telemetry value was empty.")
    }

    private func verifyDiscordWebhook2xx() {
        openSection(.devices)
        let button = app.buttons["gate2.discord.test"]
        XCTAssertTrue(button.waitForExistenceWithScrolling(in: app, timeout: 20), "Discord test button was not visible.")
        scrollTo(button)
        waitUntilHittable(button, timeout: 10)
        button.tap()
        let message = app.staticTexts["gate2.discord.message"]
        XCTAssertTrue(message.waitForText(containing: ["送信しました"], timeout: 30), "Discord test did not report a 2xx send.")
    }

    private func verifySavedCommandDraft() {
        openSection(.command)
        let command = "printf gate2-saved-command"
        let field = commandField(timeout: 20)
        XCTAssertTrue(field.exists, "Command composer was not visible.")
        scrollTo(field)
        field.clearAndTypeText(command)
        XCTAssertTrue(field.waitForValue(containing: command, timeout: 10), "Command composer did not receive typed text.")

        let save = app.buttons["gate2.command.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Save command button was not visible.")
        waitUntilEnabled(save, timeout: 10)
        save.tap()

        field.clearText()
        let savedChip = app.descendants(matching: .any)["gate2.savedCommand.first"]
        XCTAssertTrue(savedChip.waitForExistenceWithScrolling(in: app, timeout: 15), "Saved command chip was not created.")
        scrollTo(savedChip)
        waitUntilHittable(savedChip, timeout: 10)
        savedChip.tap()
        XCTAssertTrue(commandField(timeout: 10).waitForValue(containing: command, timeout: 10), "Saved command was not reinserted into the composer.")

        app.buttons["gate2.command.submit"].tap()
        dismissKeyboardIfPresent()
    }

    private func verifyMemoryVisibility() {
        openSection(.memory)
        XCTAssertTrue(app.descendants(matching: .any)["gate2.screen.memory"].waitForExistence(timeout: 10), "Memory screen was not visible.")
        scrollToTop()
        let refresh = app.buttons["gate2.memory.refreshProject"]
        XCTAssertTrue(refresh.waitForExistenceWithScrolling(in: app, timeout: 20), "Project memory refresh button was not visible.")
        waitUntilHittable(refresh, timeout: 10)
        refresh.tap()

        let content = app.staticTexts["gate2.memory.content"]
        let expectedFact = ProcessInfo.processInfo.environment["VEQRAL_GATE2_MEMORY_FACT"] ?? "Tachibana-7-"
        XCTAssertTrue(content.waitForText(containing: [expectedFact], timeout: 45), "Hermes project memory did not show the #0 fact.")
    }

    private func verifyHermesHistory() {
        openSection(.history)
        XCTAssertTrue(app.descendants(matching: .any)["gate2.screen.history"].waitForExistence(timeout: 15), "History screen was not visible.")

        let toolPicker = app.segmentedControls["gate2.history.tool"]
        XCTAssertTrue(toolPicker.waitForExistence(timeout: 10), "History tool filter was not visible.")
        let hermes = toolPicker.buttons["Hermes"]
        XCTAssertTrue(hermes.waitForExistence(timeout: 5), "Hermes history filter was not visible.")
        hermes.tap()

        let refresh = app.buttons["gate2.history.refresh"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 10), "History refresh button was not visible.")
        refresh.tap()

        let hermesSession = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "gate2.history.session.hermes.")).firstMatch
        XCTAssertTrue(hermesSession.waitForExistenceWithScrolling(in: app, timeout: 45), "No Hermes history session was rendered.")
        scrollTo(hermesSession)
        waitUntilHittable(hermesSession, timeout: 10)
        hermesSession.tap()

        XCTAssertTrue(app.descendants(matching: .any)["gate2.history.detail"].waitForExistence(timeout: 15), "Hermes history detail did not open.")
        let turn = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "gate2.history.turn.")).firstMatch
        let historyScroll = app.scrollViews["gate2.screen.history"]
        XCTAssertTrue(historyScroll.waitForExistence(timeout: 10), "History scroll view was not visible.")
        XCTAssertTrue(turn.waitForExistenceWithScrolling(in: historyScroll, timeout: 45), "Hermes history turns were not rendered.")
    }

    private func verifyVoiceTranscriptApprovalGate() {
        openSection(.command)
        let voice = app.buttons["gate2.voice.open"]
        XCTAssertTrue(voice.waitForExistenceWithScrolling(in: app, timeout: 20), "Voice button was not visible.")
        scrollTo(voice)
        voice.tap()
        handlePendingSystemPrompts()

        let raw = app.staticTexts["gate2.voice.raw"]
        XCTAssertTrue(raw.waitForText(containing: ["deploy", ".env", "token"], timeout: 15), "Injected voice transcript did not appear as raw dictation.")

        let stop = app.buttons["gate2.voice.stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 10), "Voice stop button was not visible.")
        waitUntilEnabled(stop, timeout: 10)
        stop.tap()

        let send = app.buttons["gate2.voice.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 90), "Voice send button was not visible after cleanup.")
        waitUntilEnabled(send, timeout: 90)
        send.tap()

        let pendingCount = app.staticTexts["gate2.approval.pendingCount"]
        XCTAssertTrue(pendingCount.waitForCount(atLeast: 1, timeout: 45), "High severity voice command did not land in the approval gate.")
    }

    private func openSection(_ section: Gate2Section) {
        if section != .command {
            dismissKeyboardIfPresent()
        }

        if section == .command {
            if app.buttons["gate2.sidebar.home"].exists {
                app.buttons["gate2.sidebar.home"].tap()
                return
            }
            tapTab(labels: ["指令", "Command"])
            return
        }

        if section == .memory {
            openMemorySection()
            return
        }

        if section == .history {
            openHistorySection()
            return
        }

        if let sidebarIdentifier = section.sidebarIdentifier,
           app.buttons[sidebarIdentifier].isHittable {
            app.buttons[sidebarIdentifier].tap()
            return
        }

        switch section {
        case .devices:
            tapTab(labels: ["デバイス", "Devices"])
        case .approvals:
            tapTab(labels: ["承認", "Approvals"])
        case .memory:
            break
        case .history:
            break
        case .command:
            break
        }
    }

    private func openMemorySection() {
        if app.buttons["gate2.sidebar.memory"].isHittable {
            app.buttons["gate2.sidebar.memory"].tap()
            return
        }

        openMoreRoot()
        tapMemoryLinkFromMore()
    }

    private func openHistorySection() {
        if app.buttons["gate2.sidebar.history"].isHittable {
            app.buttons["gate2.sidebar.history"].tap()
            return
        }
        openMoreRoot()
        let history = app.buttons["gate2.more.history"]
        XCTAssertTrue(history.waitForExistenceWithScrolling(in: app, timeout: 15), "History link was not visible inside More.")
        scrollTo(history)
        history.tap()
    }

    private func openMoreRoot() {
        let moreScreen = app.descendants(matching: .any)["gate2.screen.more"]
        XCTAssertTrue(
            app.tabBars.buttons["その他"].exists || app.tabBars.buttons["More"].exists,
            "More tab was not available."
        )
        tapTab(labels: ["その他", "More"])
        if moreScreen.waitForExistence(timeout: 3) {
            return
        }

        for _ in 0..<3 {
            let back = app.navigationBars.buttons.firstMatch
            guard back.waitForExistence(timeout: 2), back.isHittable else { break }
            back.tap()
            if moreScreen.waitForExistence(timeout: 3) {
                return
            }
        }
        XCTFail("More screen was not visible.")
    }

    private func tapMemoryLinkFromMore() {
        let memoryLink = app.buttons["gate2.more.memory"]
        if memoryLink.waitForExistence(timeout: 10) {
            memoryLink.tap()
        } else if app.cells.containing(.staticText, identifier: "記憶").firstMatch.exists {
            app.cells.containing(.staticText, identifier: "記憶").firstMatch.tap()
        } else if app.cells.containing(.staticText, identifier: "Memory").firstMatch.exists {
            app.cells.containing(.staticText, identifier: "Memory").firstMatch.tap()
        } else {
            XCTFail("Memory link was not visible inside More.")
        }
    }

    private func handlePendingSystemPrompts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<3 {
            let alert = springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 2) else { return }
            // UI interruption monitors are evaluated when an interaction targets the app.
            app.tap()
        }
    }

    private func addSystemPromptHandler() {
        addUIInterruptionMonitor(withDescription: "Gate2 system prompts") { alert -> Bool in
            let preferredButtons = [
                "音声入力を有効にする",
                "有効にする",
                "許可",
                "OK",
                "Allow",
                "Enable Dictation",
                "Continue"
            ]
            for label in preferredButtons {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
    }

    private func tapTab(labels: [String]) {
        for label in labels {
            let button = app.tabBars.buttons[label]
            if button.waitForExistence(timeout: 2) {
                button.tap()
                return
            }
        }
        XCTFail("Could not find tab for labels: \(labels.joined(separator: ", "))")
    }

    private func dismissKeyboardIfPresent() {
        guard app.keyboards.firstMatch.exists else { return }
        let sidebarHome = app.buttons["gate2.sidebar.home"]
        if sidebarHome.isHittable {
            sidebarHome.tap()
        } else {
            let commandNavigator = app.buttons["gate2.nav.command"]
            if commandNavigator.isHittable {
                commandNavigator.tap()
            }
        }
        if app.keyboards.firstMatch.exists {
            app.swipeDown()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    }

    private func commandField(timeout: TimeInterval = 0) -> XCUIElement {
        let textField = app.textFields["gate2.command.input"]
        if timeout > 0, textField.waitForExistence(timeout: timeout) {
            return textField
        }
        if textField.exists { return textField }
        let textView = app.textViews["gate2.command.input"]
        if timeout > 0 {
            _ = textView.waitForExistence(timeout: timeout)
        }
        return textView
    }

    private func scrollTo(_ element: XCUIElement, limit: Int = 8) {
        guard !element.isHittable else { return }
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.exists else { return }
        for _ in 0..<limit where !element.isHittable {
            scrollView.swipeUp()
        }
    }

    private func scrollToTop(limit: Int = 6) {
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.exists else { return }
        for _ in 0..<limit {
            scrollView.swipeDown()
        }
    }

    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval) {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: timeout)
    }

    private func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval) {
        let predicate = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: timeout)
    }
}

private enum Gate2Section {
    case command
    case devices
    case approvals
    case memory
    case history

    var sidebarIdentifier: String? {
        switch self {
        case .command: "gate2.sidebar.home"
        case .devices: "gate2.sidebar.devices"
        case .approvals: "gate2.sidebar.approvals"
        case .memory: "gate2.sidebar.memory"
        case .history: "gate2.sidebar.history"
        }
    }
}

@MainActor
private extension XCUIElement {
    func waitForText(containing fragments: [String], timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { element, _ in
            guard let element = element as? XCUIElement, element.exists else { return false }
            let label = element.label
            let value = (element.value as? String) ?? ""
            return fragments.allSatisfy { label.contains($0) || value.contains($0) }
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    func waitForValue(containing text: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { element, _ in
            guard let element = element as? XCUIElement, element.exists else { return false }
            return ((element.value as? String) ?? element.label).contains(text)
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    func waitForCount(atLeast minimum: Int, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { element, _ in
            guard let element = element as? XCUIElement, element.exists else { return false }
            let text = "\(element.label) \((element.value as? String) ?? "")"
            let numbers = text.matches(of: /\d+/).compactMap { Int($0.output) }
            return numbers.contains { $0 >= minimum }
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    func waitForExistenceWithScrolling(in scrollView: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if exists { return true }
            if scrollView.exists {
                scrollView.swipeUp()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        return exists
    }

    func waitForExistenceWithScrolling(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if exists { return true }
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                scrollView.swipeUp()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        return exists
    }

    func clearAndTypeText(_ text: String) {
        tap()
        clearText()
        typeText(text)
    }

    func clearText() {
        tap()
        let current = (value as? String) ?? ""
        guard !current.isEmpty else { return }
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: min(current.count, 240)))
    }
}
