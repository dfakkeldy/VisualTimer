import XCTest

/// Captures each iPhone screen with the DEBUG design-council fixture, one PNG per
/// screen, for design reviews. Runs only when `TEST_RUNNER_DESIGN_COUNCIL_OUT`
/// names an output folder, so ordinary test runs and CI skip it.
final class DesignCouncilCaptureTests: XCTestCase {

    private var outputDirectory: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let path = ProcessInfo.processInfo.environment["DESIGN_COUNCIL_OUT"], !path.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_DESIGN_COUNCIL_OUT to capture design-council screens.")
        }
        outputDirectory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    @MainActor
    func test01TimerReady() throws {
        let app = launch("quickReady")
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5))
        capture("01-timer-ready")
    }

    @MainActor
    func test02TimerPaused() throws {
        let app = launch("quickPaused")
        XCTAssertTrue(app.buttons["Reset"].waitForExistence(timeout: 5))
        capture("02-timer-paused")
    }

    @MainActor
    func test03SessionTurns() throws {
        _ = launch("sessionTurns", showAlertOffer: true)
        capture("03-session-turns")
    }

    @MainActor
    func test04SessionRoutine() throws {
        _ = launch("sessionRoutine")
        capture("04-session-routine")
    }

    @MainActor
    func test05SessionComplete() throws {
        let app = launch("sessionComplete")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'All done'")).firstMatch.waitForExistence(timeout: 5))
        capture("05-session-complete")
    }

    @MainActor
    func test06Templates() throws {
        let app = launch("templates")
        XCTAssertTrue(roundRow("Maya", in: app).waitForExistence(timeout: 5))
        capture("06-templates")
    }

    @MainActor
    func test07RoundEditor() throws {
        let app = launch("templates")
        let row = roundRow("Maya", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        sleep(1)
        capture("07-round-editor")
    }

    @MainActor
    func test08History() throws {
        let app = launch("history")
        XCTAssertTrue(historyRow(in: app).waitForExistence(timeout: 5))
        capture("08-history")
    }

    @MainActor
    func test09HistoryEmpty() throws {
        _ = launch("historyEmpty")
        capture("09-history-empty")
    }

    @MainActor
    func test10SessionDetail() throws {
        let app = launch("history")
        let row = historyRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        sleep(2)
        capture("10-session-detail")
    }

    @MainActor
    func test11Settings() throws {
        let app = launch("quickReady")
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture("11-settings")
    }

    @MainActor
    func test12ProSheet() throws {
        let app = launch("history")
        let unlock = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'full history'")).firstMatch
        XCTAssertTrue(unlock.waitForExistence(timeout: 5))
        unlock.tap()
        sleep(2)
        capture("12-pro-sheet")
    }

    // MARK: - Helpers

    @MainActor
    private func roundRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    @MainActor
    private func historyRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Family Game Night'")).firstMatch
    }

    @MainActor
    private func launch(_ scene: String, showAlertOffer: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-designCouncilFixture", scene,
            "-timerAlertsOffered", showAlertOffer ? "NO" : "YES",
            "-timerAlertsEnabled", "NO",
            "-savedTimerDuration", "300",
            "-lastTemplateID", "",
            "-lastGameFileName", "",
            "-hasMigratedLegacyTemplateLibrary", "YES",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_CA",
        ]
        app.launch()
        sleep(2)
        return app
    }

    @MainActor
    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let url = outputDirectory.appendingPathComponent("\(name).png")
        do {
            try screenshot.pngRepresentation.write(to: url)
        } catch {
            XCTFail("Could not write \(url.path): \(error)")
        }
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
