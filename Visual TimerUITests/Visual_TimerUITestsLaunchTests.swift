//
//  Visual_TimerUITestsLaunchTests.swift
//  Visual TimerUITests
//
//  Created by Dan Fakkeldy on 2026-05-17.
//

import XCTest

final class Visual_TimerUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Timer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Templates"].exists)
        XCTAssertTrue(app.tabBars.buttons["History"].exists)
        XCTAssertTrue(app.buttons["Decrease duration"].exists)
        XCTAssertTrue(app.buttons["Increase duration"].exists)
        XCTAssertTrue(app.buttons["Settings"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
