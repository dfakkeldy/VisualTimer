import XCTest
@testable import Visual_Timer

@MainActor
final class WatchTemplateTransferTests: XCTestCase {
    func testSnapshotReachesSeparateWatchStorageAndSurvivesRelaunch() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let phone = WatchTemplateStore(containerURLProvider: { directory.appendingPathComponent("phone") })
        let watchDirectory = directory.appendingPathComponent("watch")
        let watch = WatchTemplateStore(containerURLProvider: { watchDirectory })
        let templates = [template()]
        try phone.write(templates: templates)
        XCTAssertTrue(try watch.read().isEmpty, "App Group files are local to each device.")

        let context = try WatchTemplateStore.applicationContext(for: phone.read())
        XCTAssertTrue(try watch.applyApplicationContext(context))

        let relaunchedWatch = WatchTemplateStore(containerURLProvider: { watchDirectory })
        XCTAssertEqual(try relaunchedWatch.read(), templates)
    }

    func testEmptySnapshotClearsPreviouslyPublishedProTemplates() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let watch = WatchTemplateStore(containerURLProvider: { directory })
        try watch.write(templates: [template()])
        XCTAssertTrue(try watch.applyApplicationContext(WatchTemplateStore.applicationContext(for: [])))
        XCTAssertTrue(try watch.read().isEmpty)
    }

    func testMalformedOrUnrelatedContextPreservesLastGoodSnapshot() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let watch = WatchTemplateStore(containerURLProvider: { directory })
        let templates = [template()]
        try watch.write(templates: templates)
        let context = try WatchTemplateStore.applicationContext(for: templates)
        let malformed = context.mapValues { _ in Data("invalid JSON".utf8) }
        XCTAssertThrowsError(try watch.applyApplicationContext(malformed))
        XCTAssertEqual(try watch.read(), templates)
        XCTAssertFalse(try watch.applyApplicationContext(["unrelated": true]))
        XCTAssertEqual(try watch.read(), templates)
    }

    func testFailedDeliveryRetriesLatestRevocationAndStopsAfterBoundedAttempts() throws {
        var delivery = WatchTemplateDeliveryState()
        XCTAssertNil(delivery.retryDelayAfterFailure())
        delivery.replace(with: try WatchTemplateStore.applicationContext(for: [template()], revision: 10))
        XCTAssertNotNil(delivery.retryDelayAfterFailure())
        delivery.replace(with: try WatchTemplateStore.applicationContext(for: [], revision: 11))
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let watch = WatchTemplateStore(containerURLProvider: { directory })
        for _ in 0..<3 {
            XCTAssertNotNil(delivery.retryDelayAfterFailure())
            _ = try watch.applyApplicationContext(XCTUnwrap(delivery.latestContext))
            XCTAssertTrue(try watch.read().isEmpty)
        }
        XCTAssertNil(delivery.retryDelayAfterFailure())
    }

    func testDelayedAndDuplicateSnapshotsCannotUndoNewerRevocation() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let watch = WatchTemplateStore(containerURLProvider: { directory })
        let owned = try WatchTemplateStore.applicationContext(for: [template()], revision: 10)
        let revoked = try WatchTemplateStore.applicationContext(for: [], revision: 11)
        XCTAssertTrue(try watch.applyApplicationContext(revoked))
        XCTAssertFalse(try watch.applyApplicationContext(owned))
        XCTAssertFalse(try watch.applyApplicationContext(revoked))
        XCTAssertTrue(try watch.read().isEmpty)
        let relaunched = WatchTemplateStore(containerURLProvider: { directory })
        XCTAssertFalse(try relaunched.applyApplicationContext(owned))
    }

    func testLargeTemplateSnapshotPreservesFullPayload() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let watch = WatchTemplateStore(containerURLProvider: { directory })
        var large = template()
        large.title = String(repeating: "Safe fixture ", count: 10_000)
        let context = try WatchTemplateStore.applicationContext(for: [large])
        let data = try XCTUnwrap(context[WatchTemplateStore.contextKey] as? Data)
        XCTAssertGreaterThan(data.count, 65_536)
        XCTAssertTrue(try watch.applyApplicationContext([WatchTemplateStore.contextKey: data]))
        XCTAssertEqual(try watch.read(), [large])
    }

    @MainActor
    func testPublishingTracksProUnlockAndRevocation() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = TemplateLibraryStore(documentsDirectory: directory)
        let saved = try library.save(game: template().game)
        var snapshots: [[WatchTemplate]] = []
        let editor = GameEditorViewModel(
            templateLibrary: library,
            widgetSnapshotStore: WidgetSnapshotStore(containerURLProvider: { directory }),
            watchTemplateStore: WatchTemplateStore(containerURLProvider: { directory }),
            watchTemplatePublisher: { snapshots.append($0) }
        )
        editor.refreshSavedTemplates()
        XCTAssertTrue(try XCTUnwrap(snapshots.last).isEmpty)
        editor.setWidgetPublishingEnabled(true)
        XCTAssertEqual(try XCTUnwrap(snapshots.last).map(\.templateID), [saved.id])
        editor.setWidgetPublishingEnabled(false)
        XCTAssertTrue(try XCTUnwrap(snapshots.last).isEmpty)
        XCTAssertEqual(library.listTemplates().count, 1, "Revocation must not delete the phone's saved template.")
    }

    @MainActor
    func testUnavailableProductDoesNotInventStorefrontPrice() {
        let access = ProAccessViewModel(automaticallyStartsStoreKitTasks: false)
        XCTAssertEqual(access.displayPrice, "")
        XCTAssertEqual(access.purchaseButtonTitle, "Unlock Pro")
        XCTAssertFalse(access.canPurchase)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func template() -> WatchTemplate {
        let game = GameSequence(title: "Safe fixture", rounds: [Round(name: "Step", durationSeconds: 15)], roundCount: 2)
        return WatchTemplate(templateID: UUID(), title: game.title, game: game, modifiedAt: Date(timeIntervalSince1970: 2_000))
    }
}
