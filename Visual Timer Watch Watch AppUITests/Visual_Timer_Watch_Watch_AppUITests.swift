//
//  Visual_Timer_Watch_Watch_AppUITests.swift
//  Visual Timer Watch Watch AppUITests
//
//  Created by Dan Fakkeldy on 2026-05-17.
//

import XCTest

final class Visual_Timer_Watch_Watch_AppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDown() async throws {
        await MainActor.run {
            XCUIApplication().terminate()
        }
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testQuickTimerControlsAreLabelledThroughStartPauseResumeReset() throws {
        for cycle in 1...5 {
            let app = XCUIApplication()
            // A long duration (argument domain) keeps the countdown from finishing mid-test.
            app.launchArguments += ["-savedTimerDuration", "300"]
            app.launch()

            let quickTimer = app.buttons["watch.root.quickTimer"]
            XCTAssertTrue(quickTimer.waitForExistence(timeout: 10))
            quickTimer.tap()

            let primary = app.buttons["watch.quick.primary"]
            XCTAssertTrue(primary.waitForExistence(timeout: 5))
            XCTAssertEqual(primary.label, "Start")
            XCTAssertTrue(element("watch.quick.minutes", in: app).exists)
            XCTAssertTrue(element("watch.quick.seconds", in: app).exists)
            XCTAssertFalse(app.buttons["watch.quick.reset"].exists)

            primary.tap()
            XCTAssertTrue(waitForLabel("Pause", on: primary, cycle: cycle))
            XCTAssertTrue(element("watch.quick.time", in: app).waitForExistence(timeout: 2))
            XCTAssertFalse(element("watch.quick.minutes", in: app).exists, "Duration editing is idle-only.")
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Watch Quick Timer — cycle \(cycle)"
            screenshot.lifetime = .keepAlways
            add(screenshot)

            primary.tap()
            XCTAssertTrue(waitForLabel("Resume", on: primary, cycle: cycle))
            let reset = app.buttons["watch.quick.reset"]
            XCTAssertTrue(reset.waitForExistence(timeout: 2))
            XCTAssertEqual(reset.label, "Reset")

            primary.tap()
            XCTAssertTrue(waitForLabel("Pause", on: primary, cycle: cycle), "Resume must restart the countdown.")
            XCTAssertFalse(reset.exists)
            primary.tap()
            XCTAssertTrue(waitForLabel("Resume", on: primary, cycle: cycle))
            XCTAssertTrue(reset.waitForExistence(timeout: 2))

            reset.tap()
            XCTAssertTrue(waitForLabel("Start", on: primary, cycle: cycle))
            XCTAssertFalse(app.buttons["watch.quick.reset"].exists)
            app.terminate()
        }
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func waitForLabel(_ label: String, on element: XCUIElement, cycle: Int) -> Bool {
        let matched = PredicateWait.matches(
            NSPredicate(format: "label == %@", label),
            object: element,
            timeout: 3
        )
        if !matched {
            let app = XCUIApplication()
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Watch control failure — cycle \(cycle), expected \(label)"
            screenshot.lifetime = .keepAlways
            add(screenshot)

            let identifiers = ["watch.quick.primary", "watch.quick.reset", "watch.root.quickTimer"]
            let controls = identifiers.map { identifier in
                let matches = app.buttons.matching(identifier: identifier).allElementsBoundByIndex
                let descriptions = matches.map {
                    "label=\($0.label), frame=\($0.frame), hittable=\($0.isHittable)"
                }
                return "\(identifier): \(descriptions)"
            }.joined(separator: "\n")
            let hierarchy = XCTAttachment(string: "state=\(app.state)\n\(controls)\n\(app.debugDescription)")
            hierarchy.name = "Watch control failure hierarchy — cycle \(cycle), expected \(label)"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        return matched
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
