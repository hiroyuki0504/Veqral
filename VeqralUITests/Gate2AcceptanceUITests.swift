import XCTest

@MainActor
final class Gate2AcceptanceUITests: XCTestCase {
    private var app: XCUIApplication!
    private var systemPromptPlan: [SystemPromptChoice] = [.allow]

    func testGate2Acceptance() throws {
        continueAfterFailure = false
        launchApp()
        pairWithMacHost()
        verifyTelemetry()
        verifyDiscordWebhook2xx()
        relaunchPreservingState()
        verifySavedCommandDraft()
        verifyMemoryVisibility()
        relaunchPreservingState()
        verifyVoiceTranscriptApprovalGate()
    }

    func testVoicePermissionErrorsDoNotCrash() throws {
        continueAfterFailure = false
        launchApp(extraEnvironment: [
            "VEQRAL_UI_TEST_VOICE_TRANSCRIPT": "",
            "VEQRAL_UI_TEST_VOICE_FORCE_ERROR": "microphoneDenied"
        ])
        openSection(.command)
        let voice = app.buttons["gate2.voice.open"]
        XCTAssertTrue(voice.waitForExistenceWithScrolling(in: app, timeout: 20), "Voice button was not visible.")
        scrollTo(voice)
        voice.tap()
        tapVoiceStart()

        let status = app.staticTexts["gate2.voice.status"]
        XCTAssertTrue(status.waitForText(containing: ["マイク"], timeout: 10), "Voice permission error did not render.")
        XCTAssertEqual(app.state, .runningForeground, "App should stay alive after a voice permission error.")
    }

    func testVoicePermissionGrantDoesNotCrash() throws {
        continueAfterFailure = false
        systemPromptPlan = [.allow, .allow]
        launchApp(extraEnvironment: [
            "VEQRAL_UI_TEST_VOICE_TRANSCRIPT": ""
        ])
        openSection(.command)
        let voice = app.buttons["gate2.voice.open"]
        XCTAssertTrue(voice.waitForExistenceWithScrolling(in: app, timeout: 20), "Voice button was not visible.")
        scrollTo(voice)
        voice.tap()
        tapVoiceStart()
        app.tap()

        let stop = app.buttons["gate2.voice.stop"]
        let status = app.staticTexts["gate2.voice.status"]
        _ = status.waitForText(containing: ["準備"], timeout: 5)
        _ = stop.waitForExistence(timeout: 1)
        XCTAssertEqual(app.state, .runningForeground, "App should stay alive after microphone permission is granted.")
        if stop.exists {
            stop.tap()
        }
    }

    func testVoicePermissionDenyDoesNotCrash() throws {
        continueAfterFailure = false
        systemPromptPlan = [.deny]
        launchApp(extraEnvironment: [
            "VEQRAL_UI_TEST_VOICE_TRANSCRIPT": ""
        ])
        openSection(.command)
        let voice = app.buttons["gate2.voice.open"]
        XCTAssertTrue(voice.waitForExistenceWithScrolling(in: app, timeout: 20), "Voice button was not visible.")
        scrollTo(voice)
        voice.tap()
        tapVoiceStart()
        app.tap()

        let status = app.staticTexts["gate2.voice.status"]
        _ = status.waitForText(containing: ["拒否", "denied"], timeout: 10)
        XCTAssertEqual(app.state, .runningForeground, "App should stay alive after microphone permission is denied.")
    }

    func testVoiceRecordingIndicatorIsVisible() throws {
        continueAfterFailure = false
        launchApp(extraEnvironment: [
            "VEQRAL_UI_TEST_VOICE_TRANSCRIPT": "えっと 余白を詰めて"
        ])
        openSection(.command)
        let voice = app.buttons["gate2.voice.open"]
        XCTAssertTrue(voice.waitForExistenceWithScrolling(in: app, timeout: 20), "Voice button was not visible.")
        scrollTo(voice)
        voice.tap()
        tapVoiceStart()

        let indicator = app.otherElements["gate2.voice.recordingIndicator"]
        XCTAssertTrue(indicator.waitForExistence(timeout: 8), "Recording indicator was not visible while listening.")

        let stop = app.buttons["gate2.voice.stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5), "Stop button was not visible while listening.")
        stop.tap()
    }

    private func launchApp(extraEnvironment: [String: String] = [:]) {
        app = XCUIApplication()
        app.launchArguments = [
            "-veqral-ui-testing",
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP"
        ]
        let processEnvironment = ProcessInfo.processInfo.environment
        var launchEnvironment = [
            "VEQRAL_UI_TESTING": "1",
            "VEQRAL_UI_TEST_RESET": "1",
            "VEQRAL_UI_TEST_RUNTIME": "localShell",
            "VEQRAL_UI_TEST_WORKING_DIRECTORY": processEnvironment["VEQRAL_GATE2_WORKING_DIRECTORY"] ?? "/Users/hiroyuki/Documents/Veqral",
            "VEQRAL_UI_TEST_PROJECT_ID": processEnvironment["VEQRAL_GATE2_PROJECT_ID"] ?? "gate2-xcuitest",
            "VEQRAL_UI_TEST_PROJECT_NAME": "Gate2 XCUITest",
            "VEQRAL_UI_TEST_VOICE_TRANSCRIPT": processEnvironment["VEQRAL_GATE2_VOICE_TRANSCRIPT"] ?? "えっと 本番に deploy して .env の token を削除して"
        ]
        for (key, value) in extraEnvironment {
            launchEnvironment[key] = value
        }
        if let pairingURL = processEnvironment["VEQRAL_GATE2_PAIRING_URL"], !pairingURL.isEmpty {
            launchEnvironment["VEQRAL_UI_TEST_PAIRING_URL"] = pairingURL
        }
        app.launchEnvironment = launchEnvironment
        addSystemPromptHandler()
        app.launch()
    }

    private func relaunchPreservingState() {
        app.terminate()
        app.launchEnvironment["VEQRAL_UI_TEST_RESET"] = "0"
        app.launch()
    }

    private func pairWithMacHost() {
        openSection(.devices)
        let useLink = app.buttons["gate2.pairing.useLink"]
        XCTAssertTrue(useLink.waitForExistenceWithScrolling(in: app, timeout: 20), "Pairing link button was not visible.")
        scrollTo(useLink)
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

    private func verifyVoiceTranscriptApprovalGate() {
        openSection(.command)
        let voice = app.buttons["gate2.voice.open"]
        XCTAssertTrue(voice.waitForExistenceWithScrolling(in: app, timeout: 20), "Voice button was not visible.")
        scrollTo(voice)
        voice.tap()
        tapVoiceStart()

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

    private func tapVoiceStart() {
        let start = app.buttons["gate2.voice.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "Voice start button was not visible.")
        waitUntilEnabled(start, timeout: 10)
        start.tap()
    }

    private func openSection(_ section: Gate2Section) {
        if section != .command {
            dismissKeyboardIfPresent()
        }

        if section == .command {
            let testNavigator = app.buttons["gate2.nav.command"]
            if testNavigator.exists {
                testNavigator.tap()
                if commandField(timeout: 5).exists || app.buttons["gate2.voice.open"].waitForExistence(timeout: 2) {
                    return
                }
            }
            if app.buttons["gate2.sidebar.home"].exists {
                app.buttons["gate2.sidebar.home"].tap()
                return
            }
            tapTab(labels: ["指令", "Command"])
            return
        }

        if section == .devices {
            openDevicesSection()
            return
        }

        if section == .memory {
            openMemorySection()
            return
        }

        if let navIdentifier = section.navIdentifier,
           app.buttons[navIdentifier].exists {
            app.buttons[navIdentifier].tap()
            return
        }

        if let sidebarIdentifier = section.sidebarIdentifier,
           app.buttons[sidebarIdentifier].exists {
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
        case .command:
            break
        }
    }

    private func openMemorySection() {
        let screen = app.descendants(matching: .any)["gate2.screen.memory"]
        if screen.exists {
            return
        }

        let directMemory = app.buttons["gate2.nav.memory"]
        if directMemory.exists {
            directMemory.tap()
            if screen.waitForExistence(timeout: 4) {
                return
            }
        }

        if app.buttons["gate2.sidebar.memory"].exists {
            app.buttons["gate2.sidebar.memory"].tap()
            if screen.waitForExistence(timeout: 4) {
                return
            }
        }

        if openMobileDrawer() {
            let memoryLink = app.buttons["gate2.more.memory"]
            if memoryLink.waitForExistence(timeout: 8) {
                memoryLink.tap()
                return
            }
        }

        if app.buttons["gate2.nav.more"].exists {
            app.buttons["gate2.nav.more"].tap()
            XCTAssertTrue(app.descendants(matching: .any)["gate2.screen.more"].waitForExistence(timeout: 10), "More screen was not visible.")
            tapMemoryLinkFromMore()
        } else if app.tabBars.buttons["その他"].exists || app.tabBars.buttons["More"].exists {
            tapTab(labels: ["その他", "More"])
            XCTAssertTrue(app.descendants(matching: .any)["gate2.screen.more"].waitForExistence(timeout: 10), "More screen was not visible.")
            tapMemoryLinkFromMore()
        } else if app.buttons["gate2.command.memory"].exists {
            app.buttons["gate2.command.memory"].tap()
        } else {
            tapTab(labels: ["その他", "More"])
        }
    }

    private func openDevicesSection() {
        let screen = app.descendants(matching: .any)["gate2.screen.devices"]
        if screen.exists || app.buttons["gate2.pairing.useLink"].exists {
            return
        }

        let directDevices = app.buttons["gate2.nav.devices"]
        if directDevices.exists {
            directDevices.tap()
            if screen.waitForExistence(timeout: 4) || app.buttons["gate2.pairing.useLink"].exists {
                return
            }
        }

        if app.buttons["gate2.sidebar.devices"].exists {
            app.buttons["gate2.sidebar.devices"].tap()
            if screen.waitForExistence(timeout: 4) || app.buttons["gate2.pairing.useLink"].exists {
                return
            }
        }

        if openMobileDrawer() {
            let devicesLink = app.buttons["gate2.sidebar.devices"]
            if devicesLink.waitForExistence(timeout: 8) {
                devicesLink.tap()
                return
            }
        }

        tapTab(labels: ["デバイス", "Devices"])
    }

    @discardableResult
    private func openMobileDrawer() -> Bool {
        let drawer = app.descendants(matching: .any)["gate2.mobile.drawer"]
        if drawer.exists {
            return true
        }
        let explicitMenu = app.buttons["gate2.mobile.menu"]
        if explicitMenu.waitForExistence(timeout: 4) {
            explicitMenu.tap()
            return drawer.waitForExistence(timeout: 8)
        }
        for label in ["ナビゲーションを開く", "Open navigation"] {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 2) {
                button.tap()
                return drawer.waitForExistence(timeout: 8)
            }
        }
        return false
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

    private func addSystemPromptHandler() {
        addUIInterruptionMonitor(withDescription: "Gate2 system prompts") { alert -> Bool in
            let choice = self.systemPromptPlan.isEmpty ? .allow : self.systemPromptPlan.removeFirst()
            for label in choice.buttonLabels {
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
        if sidebarHome.exists {
            sidebarHome.tap()
        } else {
            let commandNavigator = app.buttons["gate2.nav.command"]
            if commandNavigator.exists {
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
            if element.exists {
                let frame = element.frame
                let appFrame = app.frame
                if frame.minY < appFrame.minY + 48 {
                    scrollView.swipeDown()
                } else if frame.maxY > appFrame.maxY - 48 {
                    scrollView.swipeUp()
                } else {
                    break
                }
            } else {
                scrollView.swipeUp()
            }
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

private enum SystemPromptChoice {
    case allow
    case deny

    var buttonLabels: [String] {
        switch self {
        case .allow:
            [
                "音声入力を有効にする",
                "有効にする",
                "許可",
                "OK",
                "Allow",
                "Enable Dictation",
                "Continue"
            ]
        case .deny:
            [
                "許可しない",
                "許可しないでください",
                "Don't Allow",
                "Do Not Allow",
                "Not Now"
            ]
        }
    }
}

private enum Gate2Section {
    case command
    case devices
    case approvals
    case memory

    var sidebarIdentifier: String? {
        switch self {
        case .command: "gate2.sidebar.home"
        case .devices: "gate2.sidebar.devices"
        case .approvals: "gate2.sidebar.approvals"
        case .memory: "gate2.sidebar.memory"
        }
    }

    var navIdentifier: String? {
        switch self {
        case .command: "gate2.nav.command"
        case .devices: "gate2.nav.devices"
        case .approvals: nil
        case .memory: "gate2.nav.memory"
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
