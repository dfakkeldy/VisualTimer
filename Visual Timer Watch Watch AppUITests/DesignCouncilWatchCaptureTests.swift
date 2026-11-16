import XCTest

/// Captures the Watch screens for design-council reviews, one PNG per screen.
/// Runs only when `TEST_RUNNER_DESIGN_COUNCIL_OUT` names an output folder, so
/// ordinary test runs and CI skip it.
final class DesignCouncilWatchCaptureTests: XCTestCase {

    private var outputDirectory: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let path = ProcessInfo.processInfo.environment["DESIGN_COUNCIL_OUT"], !path.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_DESIGN_COUNCIL_OUT to capture design-council screens.")
        }
        outputDirectory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIApplication().terminate() }
    }

    @MainActor
    func test13WatchHome() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["watch.root.quickTimer"].waitForExistence(timeout: 10))
        sleep(1)
        capture("13-watch-home", app: app)
    }

    @MainActor
    func test14WatchQuickTimer() throws {
        let app = launch()
        let quickTimer = app.buttons["watch.root.quickTimer"]
        XCTAssertTrue(quickTimer.waitForExistence(timeout: 10))
        quickTimer.tap()
        if !app.buttons["watch.quick.primary"].waitForExistence(timeout: 4), quickTimer.exists {
            quickTimer.tap()
        }
        XCTAssertTrue(app.buttons["watch.quick.primary"].waitForExistence(timeout: 6))
        sleep(1)
        capture("14-watch-quick-timer", app: app)
    }

    @MainActor
    func test15WatchSession() throws {
        let app = launch()
        let row = app.buttons["watch.root.starter.game-night"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        // The live dial animates every frame, which makes Watch accessibility
        // snapshots time out; wait instead of querying, then capture.
        sleep(8)
        capture("15-watch-session", app: app)
    }

    /// The fullest quick timer state: the dial, the digits and Reset together.
    @MainActor
    func test16WatchQuickTimerPaused() throws {
        let app = launch()
        let quickTimer = app.buttons["watch.root.quickTimer"]
        XCTAssertTrue(quickTimer.waitForExistence(timeout: 10))
        quickTimer.tap()
        let primary = app.buttons["watch.quick.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 6))
        primary.tap()
        XCTAssertTrue(primary.waitForExistence(timeout: 6))
        primary.tap()
        XCTAssertTrue(app.buttons["watch.quick.reset"].waitForExistence(timeout: 6))
        sleep(1)
        capture("16-watch-quick-timer-paused", app: app)
    }

    // MARK: - Helpers

    @MainActor
    private func launch(_ extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-savedTimerDuration", "300", "-AppleLanguages", "(en)"] + extraArguments
        app.launch()
        return app
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
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
