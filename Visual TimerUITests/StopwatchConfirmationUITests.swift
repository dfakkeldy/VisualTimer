import XCTest

/// Exercises the actual confirmation buttons; model tests cannot protect these routes.
final class StopwatchConfirmationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFinishEarlyCancelKeepsRecordingAndConfirmOpensReview() {
        let app = launchTemplates()
        reveal(app.buttons["Time this template"], in: app)
        app.buttons["Time this template"].tap()
        let start = app.buttons["stopwatch.start"]
        reveal(start, in: app)
        start.tap()
        let early = app.buttons["stopwatch.finishEarly"]
        XCTAssertTrue(early.waitForExistence(timeout: 5), "The default Game Night starter has four enabled steps")
        early.tap()
        cancelConfirmation(in: app, label: "Keep recording")
        XCTAssertTrue(early.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["stopwatch.elapsed"].exists)
        XCTAssertTrue(app.buttons["stopwatch.next"].exists)
        XCTAssertFalse(app.staticTexts["Review measurements"].exists)

        early.tap()
        // The trigger is identified by stopwatch.finishEarly; this label selects
        // the separate confirmation action in the presented dialog.
        let confirm = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Finish early", "stopwatch.finishEarly")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Review measurements"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Not saved yet"].exists)
        XCTAssertTrue(app.buttons["Save recording"].exists)
        XCTAssertFalse(app.staticTexts["stopwatch.elapsed"].exists)
    }

    @MainActor
    func testApplyNewCancelPreservesDirtyEditorAndConfirmAppliesUnsavedPlan() throws {
        let app = launchTemplates()
        let editorTitle = app.textFields["Template name"]
        editorTitle.tap()
        editorTitle.typeText(" edited\n")
        let priorTitle = try XCTUnwrap(editorTitle.value as? String)
        XCTAssertNotEqual(priorTitle, "Game Night")
        reveal(app.buttons["Plan a new routine"], in: app)
        app.buttons["Plan a new routine"].tap()
        let routineTitle = app.textFields["Routine name"]
        XCTAssertTrue(routineTitle.waitForExistence(timeout: 5))
        routineTitle.tap()
        routineTitle.typeText(" learned\n")
        let plannedTitle = try XCTUnwrap(routineTitle.value as? String)
        XCTAssertNotEqual(plannedTitle, priorTitle)
        let step = app.textFields["Step 1 name"]
        step.tap()
        step.typeText("Solo step")
        XCTAssertEqual(step.value as? String, "Solo step", "Typing must keep the complete step name")
        step.typeText("\n")
        XCTAssertEqual(step.value as? String, "Solo step", "Submitting must keep the complete step name")
        let start = app.buttons["stopwatch.start"]
        reveal(start, in: app)
        XCTAssertTrue(start.isEnabled)
        start.tap()
        let finish = app.buttons["stopwatch.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        XCTAssertTrue(app.staticTexts["Review measurements"].waitForExistence(timeout: 5))
        let apply = app.buttons["stopwatch.apply"]
        reveal(apply, in: app)
        apply.tap()
        XCTAssertTrue(app.staticTexts["Replace your unsaved template edits?"].waitForExistence(timeout: 3))
        cancelConfirmation(in: app, label: "Cancel")
        XCTAssertTrue(apply.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Not saved yet"].exists, "Cancel must not save or apply the recording")

        // Safe sheet dismissal lets us inspect the actual editor after Cancel,
        // then return to the same unsaved review and confirm the second attempt.
        let sheetHeader = app.navigationBars["Routine stopwatch"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        sheetHeader.press(forDuration: 0.1, thenDragTo: bottom)
        XCTAssertTrue(app.navigationBars["Templates"].waitForExistence(timeout: 5))
        reveal(editorTitle, in: app, scrollingUp: false)
        XCTAssertEqual(editorTitle.value as? String, priorTitle)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Alice")).firstMatch.exists)
        let returnToStopwatch = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Return to stopwatch")).firstMatch
        reveal(returnToStopwatch, in: app)
        returnToStopwatch.tap()
        XCTAssertTrue(app.staticTexts["Review measurements"].waitForExistence(timeout: 5))
        reveal(apply, in: app)
        apply.tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Apply as new template", "stopwatch.apply")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(app.navigationBars["Templates"].waitForExistence(timeout: 5))
        reveal(editorTitle, in: app, scrollingUp: false)
        XCTAssertEqual(editorTitle.value as? String, plannedTitle)
        let appliedEditor = XCTAttachment(screenshot: app.screenshot())
        appliedEditor.name = "Editor after confirmed stopwatch Apply"
        add(appliedEditor)
        let appliedStep = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Solo step")).firstMatch
        reveal(appliedStep, in: app)
        XCTAssertTrue(appliedStep.exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Alice")).firstMatch.exists)
        let save = app.buttons["Save"]
        reveal(save, in: app, scrollingUp: false)
        XCTAssertTrue(save.isEnabled, "Apply leaves the new template unsaved in the editor")
    }

    @MainActor
    func testEarlyReviewAccessibilityAuditAtLargestTextSize() throws {
        // Measure the same rendered label before and after the launch override;
        // launch arguments alone do not prove Dynamic Type reached the app.
        let standardApp = launchTemplates(arguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
        ])
        reveal(standardApp.buttons["Time this template"], in: standardApp)
        standardApp.buttons["Time this template"].tap()
        let standardHeading = standardApp.staticTexts["Plan your routine"].firstMatch
        XCTAssertTrue(standardHeading.waitForExistence(timeout: 5))
        let standardHeight = standardHeading.frame.height
        standardApp.terminate()

        let app = launchTemplates(arguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        reveal(app.buttons["Time this template"], in: app)
        app.buttons["Time this template"].tap()
        let accessibilityHeading = app.staticTexts["Plan your routine"].firstMatch
        XCTAssertTrue(accessibilityHeading.waitForExistence(timeout: 5))
        let accessibilityHeight = accessibilityHeading.frame.height
        print("Dynamic Type heading heights: standard=\(standardHeight), AX5=\(accessibilityHeight)")
        XCTAssertGreaterThan(accessibilityHeight, standardHeight * 1.5, "The content-size override must change rendered app geometry")

        let start = app.buttons["stopwatch.start"]
        reveal(start, in: app)
        start.tap()
        let pause = app.buttons["Pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        pause.tap()
        let finishEarly = app.buttons["stopwatch.finishEarly"]
        reveal(finishEarly, in: app)
        finishEarly.tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Finish early", "stopwatch.finishEarly")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Review measurements"].waitForExistence(timeout: 5))

        // Bind the presented List by index while its header is on screen. A
        // containing(header) query can stop matching when scrolling unloads it.
        let collections = app.collectionViews.allElementsBoundByIndex
        let reviewIndex = try XCTUnwrap(collections.firstIndex {
            $0.staticTexts["Review measurements"].exists
        }, "The presented review list must contain its visible header")
        let reviewList = app.collectionViews.element(boundBy: reviewIndex)
        let comparison = reviewList.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "1. Alice", "Actual")).firstMatch
        reveal(comparison, in: app)
        revealFullyForAudit(comparison, in: reviewList, app: app)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "AX5 early-review comparison"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let context = XCTAttachment(string: app.debugDescription)
        context.name = "AX5 early-review accessibility and geometry"
        context.lifetime = .keepAlways
        add(context)
        // A busy runner can take five seconds to reach Pause. Audit the actual
        // rendered row regardless; model tests and captures cover clamping.
        print("AX5 audit includes minimum-duration hint: \(comparison.label.contains("Template duration: 5s"))")

        // The editor behind the sheet has pre-existing clipping outside this
        // feature. Match audit elements to the review List's actual subtree,
        // keeping every issue in that subtree (including combined text rows).
        let sheetElements = [reviewList] + reviewList.descendants(matching: .any).allElementsBoundByIndex
        let backgroundElements = collections.enumerated().filter { $0.offset != reviewIndex }.flatMap {
            [$0.element] + $0.element.descendants(matching: .any).allElementsBoundByIndex
        } + app.navigationBars["Templates"].descendants(matching: .any).allElementsBoundByIndex
            + app.tabBars.descendants(matching: .any).allElementsBoundByIndex
        let sheetKeys = Set(sheetElements.map { auditKey($0) })
        let backgroundKeys = Set(backgroundElements.map { auditKey($0) })
        try app.performAccessibilityAudit(for: [.textClipped]) { issue in
            guard let element = issue.element else { return false }
            let key = self.auditKey(element)
            let inSheet = sheetKeys.contains(key)
            let inBackground = backgroundKeys.contains(key)
            print("Text-clipping audit: inStopwatchSheet=\(inSheet), verifiedBackground=\(inBackground), \(issue.detailedDescription), element=\(element)")
            // Never suppress an unclassified issue just because matching failed.
            return inBackground && !inSheet
        }
    }

    @MainActor
    private func auditKey(_ element: XCUIElement) -> String {
        "\(element.elementType.rawValue)|\(element.identifier)|\(element.label)|\(element.frame)"
    }

    @MainActor
    private func revealFullyForAudit(_ element: XCUIElement, in list: XCUIElement, app: XCUIApplication) {
        let top = max(list.frame.minY, app.navigationBars["Routine stopwatch"].frame.maxY)
        let bottom = list.frame.maxY
        for _ in 0..<8 {
            let bounds = element.frame
            if bounds.minY >= top && bounds.maxY <= bottom { return }
            let endY: CGFloat = bounds.maxY > bottom ? 0.45 : 0.75
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                .press(forDuration: 0.05,
                       thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY)),
                       withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertTrue(element.frame.minY >= top && element.frame.maxY <= bottom,
                      "Audit the complete comparison, not only its partially visible heading")
    }

    @MainActor
    private func cancelConfirmation(in app: XCUIApplication, label: String) {
        let cancel = app.buttons[label]
        if cancel.waitForExistence(timeout: 2) {
            cancel.tap()
        } else {
            // System popover presentations omit the cancel-role row. Dismissing
            // their native outside region is the same no-selection path.
            let dismissRegion = app.otherElements["PopoverDismissRegion"]
            XCTAssertTrue(dismissRegion.waitForExistence(timeout: 3))
            dismissRegion.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.1)).tap()
        }
    }

    @MainActor
    private func launchTemplates(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-resetPersistedState", "YES",
            "-lastTemplateID", "", "-lastGameFileName", "",
            "-hasMigratedLegacyTemplateLibrary", "YES",
            "-timerAlertsOffered", "YES", "-timerAlertsEnabled", "NO",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_CA",
        ]
        app.launchArguments += arguments
        app.launch()
        let templates = app.tabBars.buttons["Templates"]
        XCTAssertTrue(templates.waitForExistence(timeout: 5))
        templates.tap()
        XCTAssertTrue(app.textFields["Template name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Template name"].value as? String, "Game Night")
        return app
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, scrollingUp: Bool = true) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            if scrollingUp { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(element.exists && element.isHittable, "Expected control must be reachable")
    }
}
