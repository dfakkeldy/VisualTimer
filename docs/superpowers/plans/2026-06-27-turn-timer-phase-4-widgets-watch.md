# Turn Timer Phase 4: Widgets and Watch Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make favorite Turn Timer templates faster to start from iPhone widgets and bring the watch app into the template-first product model.

**Architecture:** Keep the app local-first. The iOS app remains the source of truth for saved `.turntimer` templates; it writes small template snapshots into an App Group for widgets. Widgets display the favorite template, provide a quick-start intent that opens the app and starts the favorite template, and degrade to a setup prompt when no favorite exists. The watch app gets a watch-safe template picker and timer view rather than sharing iOS-only audio/idle-timer code.

**Tech Stack:** SwiftUI, WidgetKit, AppIntents, App Groups, Xcode file-system-synchronized groups, StoreKit test config, existing MVVM/state-machine code.

## Global Constraints

- Preserve app deployment target iOS 18.0.
- Preserve watch deployment target watchOS 11.0.
- Preserve Swift language version 5.0.
- Do not introduce third-party frameworks.
- Do not gate quick timer, starter templates, or basic playback behind Pro.
- Widgets must degrade gracefully when no favorite template exists.
- Watch behavior must remain simple and reliable.
- Live widget installation and watch device behavior still require simulator/device smoke testing outside unit tests.

---

## Task 1: Shared Favorite Template Snapshots

**Files:**
- Create: `TurnTimerShared/TurnTimerWidgetShared.swift`
- Create: `Visual Timer/TemplateWidgetUpdater.swift`
- Modify: `Visual Timer/TemplateLibraryStore.swift`
- Modify: `Visual Timer/Visual Timer.entitlements`
- Modify: `Visual TimerTests/Visual_TimerTests.swift`

**Interfaces:**
- Produces: `TurnTimerSharedConstants.appGroupIdentifier: String`
- Produces: `TemplateWidgetSnapshot: Codable, Equatable, Identifiable`
- Produces: `TemplateWidgetPayload: Codable, Equatable`
- Produces: `TemplateWidgetStore.readPayload() -> TemplateWidgetPayload`
- Produces: `TemplateWidgetStore.writePayload(_:)`
- Produces: `TemplateWidgetStore.writePendingStart(templateID:)`
- Produces: `TemplateWidgetStore.consumePendingStartTemplateID() -> String?`
- Produces: `TemplateLibraryStore.snapshot(for:) throws -> TemplateWidgetSnapshot`
- Produces: `FavoriteTemplateStore: ObservableObject`
- Produces: `TemplateWidgetUpdater.refresh(savedTemplates:favoriteTemplateID:)`

- [ ] Add the shared snapshot model and App Group-backed store.

```swift
import Foundation

enum TurnTimerSharedConstants {
    static let appGroupIdentifier = "group.Dan.Visual-Timer"
    static let widgetKind = "TurnTimerTemplateWidget"
}

struct TemplateWidgetSnapshot: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let roundCount: Int
    let repeatCount: Int
    let firstRoundName: String
    let firstRoundDurationSeconds: Int
    let totalDurationSeconds: Int
    let modifiedAt: Date
}

struct TemplateWidgetPayload: Codable, Equatable {
    var favoriteTemplateID: String?
    var templates: [TemplateWidgetSnapshot]
    var generatedAt: Date

    static let empty = TemplateWidgetPayload(
        favoriteTemplateID: nil,
        templates: [],
        generatedAt: Date(timeIntervalSince1970: 0)
    )

    var favoriteTemplate: TemplateWidgetSnapshot? {
        guard let favoriteTemplateID else { return templates.first }
        return templates.first { $0.id == favoriteTemplateID } ?? templates.first
    }
}

struct TemplateWidgetStore {
    private enum Key {
        static let payload = "turntimer.widget.payload"
        static let pendingStartTemplateID = "turntimer.widget.pendingStartTemplateID"
    }

    private let userDefaults: UserDefaults?

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: TurnTimerSharedConstants.appGroupIdentifier)) {
        self.userDefaults = userDefaults
    }

    func readPayload() -> TemplateWidgetPayload {
        guard let data = userDefaults?.data(forKey: Key.payload),
              let payload = try? JSONDecoder().decode(TemplateWidgetPayload.self, from: data)
        else {
            return .empty
        }
        return payload
    }

    func writePayload(_ payload: TemplateWidgetPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        userDefaults?.set(data, forKey: Key.payload)
    }

    func writePendingStart(templateID: String) {
        userDefaults?.set(templateID, forKey: Key.pendingStartTemplateID)
    }

    func consumePendingStartTemplateID() -> String? {
        let templateID = userDefaults?.string(forKey: Key.pendingStartTemplateID)
        userDefaults?.removeObject(forKey: Key.pendingStartTemplateID)
        return templateID
    }
}
```

- [ ] Add `TemplateLibraryStore.snapshot(for:)` that loads a document and returns a compact widget snapshot.

```swift
func snapshot(for template: SavedTemplate) throws -> TemplateWidgetSnapshot {
    let document = try loadDocument(id: template.id)
    let activeRounds = document.game.activeRounds
    let firstRound = activeRounds.first
    let totalSeconds = activeRounds.reduce(0) { $0 + $1.durationSeconds } * max(1, document.game.roundCount)
    return TemplateWidgetSnapshot(
        id: template.id.uuidString,
        title: template.title,
        subtitle: template.subtitle,
        roundCount: template.roundCount,
        repeatCount: template.repeatCount,
        firstRoundName: firstRound?.name ?? "Ready",
        firstRoundDurationSeconds: firstRound?.durationSeconds ?? 0,
        totalDurationSeconds: totalSeconds,
        modifiedAt: template.modifiedAt
    )
}
```

- [ ] Add `FavoriteTemplateStore` and `TemplateWidgetUpdater` in `Visual Timer/TemplateWidgetUpdater.swift`.

```swift
import Combine
import Foundation
import WidgetKit

@MainActor
final class FavoriteTemplateStore: ObservableObject {
    @Published private(set) var favoriteTemplateID: String?

    private enum Key {
        static let favoriteTemplateID = "turntimer.favoriteTemplateID"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        favoriteTemplateID = userDefaults.string(forKey: Key.favoriteTemplateID)
    }

    func isFavorite(_ template: SavedTemplate) -> Bool {
        favoriteTemplateID == template.id.uuidString
    }

    func toggleFavorite(_ template: SavedTemplate) {
        if isFavorite(template) {
            favoriteTemplateID = nil
            userDefaults.removeObject(forKey: Key.favoriteTemplateID)
        } else {
            favoriteTemplateID = template.id.uuidString
            userDefaults.set(template.id.uuidString, forKey: Key.favoriteTemplateID)
        }
    }

    func removeMissingFavorite(from templates: [SavedTemplate]) {
        guard let favoriteTemplateID,
              !templates.contains(where: { $0.id.uuidString == favoriteTemplateID })
        else { return }
        self.favoriteTemplateID = nil
        userDefaults.removeObject(forKey: Key.favoriteTemplateID)
    }
}

struct TemplateWidgetUpdater {
    let templateLibrary: TemplateLibraryStore
    let widgetStore: TemplateWidgetStore

    init(
        templateLibrary: TemplateLibraryStore,
        widgetStore: TemplateWidgetStore = TemplateWidgetStore()
    ) {
        self.templateLibrary = templateLibrary
        self.widgetStore = widgetStore
    }

    func refresh(savedTemplates: [SavedTemplate], favoriteTemplateID: String?) {
        let snapshots = savedTemplates.compactMap { try? templateLibrary.snapshot(for: $0) }
        let payload = TemplateWidgetPayload(
            favoriteTemplateID: favoriteTemplateID,
            templates: snapshots,
            generatedAt: Date()
        )
        widgetStore.writePayload(payload)
        WidgetCenter.shared.reloadTimelines(ofKind: TurnTimerSharedConstants.widgetKind)
    }
}
```

- [ ] Add the App Group entitlement to `Visual Timer/Visual Timer.entitlements`.

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.Dan.Visual-Timer</string>
</array>
```

- [ ] Add tests for `snapshot(for:)` and `TemplateWidgetStore` pending-start consumption.

Run:

```bash
xcodebuild build-for-testing -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** TEST BUILD SUCCEEDED **`.

- [ ] Commit.

```bash
git add TurnTimerShared "Visual Timer/TemplateWidgetUpdater.swift" "Visual Timer/TemplateLibraryStore.swift" "Visual Timer/Visual Timer.entitlements" "Visual TimerTests/Visual_TimerTests.swift"
git commit -m "Add favorite template widget snapshots"
```

## Task 2: Favorite Selection and Widget Deep Links

**Files:**
- Modify: `Visual Timer/GameEditorView.swift`
- Modify: `Visual Timer/GameEditorViewModel.swift`
- Modify: `Visual Timer/MainTabView.swift`
- Modify: `Visual Timer/Theme.swift`
- Modify: `Visual TimerTests/Visual_TimerTests.swift`

**Interfaces:**
- Consumes: `FavoriteTemplateStore`
- Consumes: `TemplateWidgetUpdater`
- Consumes: `TemplateWidgetStore.consumePendingStartTemplateID()`
- Produces: `GameEditorViewModel.applySavedTemplate(id:) -> Bool`
- Produces: `MainTabView.handleWidgetURL(_:)`
- Produces: `MainTabView.startTemplateFromWidget(id:)`

- [ ] Add `GameEditorViewModel.applySavedTemplate(id:)`.

```swift
func applySavedTemplate(id: UUID) -> Bool {
    refreshSavedTemplates()
    guard let template = savedTemplates.first(where: { $0.id == id }) else { return false }
    return applySavedTemplate(template).0
}
```

- [ ] Pass `FavoriteTemplateStore` into `GameEditorView` and show a star button on saved template cards only.

```swift
@ObservedObject var favoriteTemplates: FavoriteTemplateStore
```

Use `Button("Favorite", systemImage: favoriteTemplates.isFavorite(template) ? "star.fill" : "star")` inside each saved-template card with `.accessibilityLabel("Favorite template")`.

- [ ] Update `MainTabView` to own `FavoriteTemplateStore`, create `TemplateWidgetUpdater`, refresh widget snapshots when templates or the favorite changes, and handle `turntimer://templates` plus `turntimer://start/<uuid>`.

```swift
.onOpenURL { url in
    handleWidgetURL(url)
}
.onChange(of: favoriteTemplates.favoriteTemplateID) { _, _ in
    refreshWidgetSnapshots()
}
.task {
    consumePendingWidgetStart()
}
```

`startTemplateFromWidget(id:)` should load the template into the editor, load the resulting sequence into `GameViewModel`, start playback, and switch to the Timer tab.

- [ ] Add theme constants for favorite symbols and widget deep-link labels.
- [ ] Add tests for `applySavedTemplate(id:)`.

Run:

```bash
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] Commit.

```bash
git add "Visual Timer/GameEditorView.swift" "Visual Timer/GameEditorViewModel.swift" "Visual Timer/MainTabView.swift" "Visual Timer/Theme.swift" "Visual TimerTests/Visual_TimerTests.swift"
git commit -m "Add favorite template deep links"
```

## Task 3: WidgetKit Extension

**Files:**
- Create: `TurnTimerWidget/Info.plist`
- Create: `TurnTimerWidget/TurnTimerWidget.entitlements`
- Create: `TurnTimerWidget/TurnTimerWidgetBundle.swift`
- Create: `TurnTimerWidget/TurnTimerTemplateWidget.swift`
- Create: `TurnTimerWidget/StartFavoriteTemplateIntent.swift`
- Modify: `Visual Timer.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `TemplateWidgetStore`
- Consumes: `TemplateWidgetPayload.favoriteTemplate`
- Consumes: `TurnTimerSharedConstants.widgetKind`
- Produces: `TurnTimerTemplateWidget`
- Produces: `StartFavoriteTemplateIntent`

- [ ] Create the widget extension files.

`TurnTimerWidget/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
```

`TurnTimerWidget/TurnTimerWidget.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.Dan.Visual-Timer</string>
    </array>
</dict>
</plist>
```

`StartFavoriteTemplateIntent` should write the selected template ID to `TemplateWidgetStore.writePendingStart(templateID:)` and set `static var openAppWhenRun = true`.

- [ ] Add a WidgetKit target named `TurnTimerWidgetExtension`.

Project requirements:

- Product type: `com.apple.product-type.app-extension`
- Product: `TurnTimerWidgetExtension.appex`
- Bundle identifier: `Dan.Visual-Timer.TurnTimerWidgetExtension`
- SDKROOT: `iphoneos`
- IPHONEOS_DEPLOYMENT_TARGET: `18.0`
- CODE_SIGN_ENTITLEMENTS: `TurnTimerWidget/TurnTimerWidget.entitlements`
- INFOPLIST_FILE: `TurnTimerWidget/Info.plist`
- TARGETED_DEVICE_FAMILY: `1,2`
- File-system-synchronized roots: `TurnTimerWidget` and `TurnTimerShared`
- Add the extension product to the app target's `Embed Foundation Extensions` copy phase.

- [ ] The widget should support:

```swift
.supportedFamilies([
    .systemSmall,
    .systemMedium,
    .accessoryCircular,
    .accessoryRectangular,
    .accessoryInline
])
```

- [ ] Empty state: show "Pick a favorite" and link to `turntimer://templates`.
- [ ] Favorite state: show title, first round, round count, and an interactive Start button for system medium where space allows.

Run:

```bash
xcodebuild -list -project 'Visual Timer.xcodeproj'
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected:
- `xcodebuild -list` includes target `TurnTimerWidgetExtension`.
- iOS app build ends with `** BUILD SUCCEEDED **`.

- [ ] Commit.

```bash
git add TurnTimerWidget "Visual Timer.xcodeproj/project.pbxproj"
git commit -m "Add favorite template widgets"
```

## Task 4: Watch Template Alignment

**Files:**
- Create: `WatchApp/WatchTimerViewModel.swift`
- Create: `WatchApp/WatchTemplateLibrary.swift`
- Modify: `WatchApp/WatchTimerView.swift`
- Modify: `Visual Timer.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `WatchTemplate: Identifiable, Equatable`
- Produces: `WatchTemplateLibrary.templates`
- Produces: `WatchTimerViewModel`

- [ ] Add watch-local starter template summaries.

```swift
struct WatchTemplate: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let firstDurationSeconds: Int
}

enum WatchTemplateLibrary {
    static let templates = [
        WatchTemplate(id: "quick", title: "Quick Timer", subtitle: "Set with the crown", firstDurationSeconds: 25),
        WatchTemplate(id: "game-night", title: "Game Night", subtitle: "One-minute turns", firstDurationSeconds: 60),
        WatchTemplate(id: "recipe-steps", title: "Recipe Steps", subtitle: "Start with prep", firstDurationSeconds: 60),
        WatchTemplate(id: "plant-watering", title: "Plant Watering", subtitle: "Start with herbs", firstDurationSeconds: 45)
    ]
}
```

- [ ] Add a watch-safe timer view model that does not import UIKit, AVFoundation, CloudKit, or app-only storage.
- [ ] Replace `WatchTimerView` with a `NavigationStack` containing a compact template picker and the existing crown-adjustable timer UI.
- [ ] Add the `WatchApp` file-system-synchronized root to the watch app target so the watch Swift files are compiled.

Run:

```bash
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer Watch Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] Commit.

```bash
git add WatchApp "Visual Timer.xcodeproj/project.pbxproj"
git commit -m "Align watch app with templates"
```

## Task 5: Docs, Verification, and PR

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `CONTRIBUTING.md`

**Steps:**
- [ ] Document favorite templates, widget behavior, App Group, and watch scope.
- [ ] Document that widgets open the app to start a favorite template; they are not a background live timer.
- [ ] Document simulator/device smoke-test expectations for widget installation and watch UI.
- [ ] Run stale copy scan:

```bash
rg -n "future sync|Visual Timer|Game Editor|generic timer|Ready for sync" README.md CLAUDE.md CONTRIBUTING.md "Visual Timer" WatchApp TurnTimerWidget
```

- [ ] Final verification:

```bash
python3 -m json.tool TurnTimer.storekit >/dev/null
xcodebuild build-for-testing -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer Watch Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

Expected:
- StoreKit JSON exits 0.
- iOS build-for-testing succeeds.
- iOS app build succeeds.
- watch app build succeeds.

- [ ] Push and open PR against `codex/turn-timer-phase3`.

```bash
git push -u origin codex/turn-timer-phase4
gh pr create --base codex/turn-timer-phase3 --head codex/turn-timer-phase4 --title "Add favorite widgets and watch template starts"
```
