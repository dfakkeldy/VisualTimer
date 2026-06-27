# Turn Timer Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebrand the existing app as Turn Timer and make the core template experience ship-ready with starter templates and first-run Game Night behavior.

**Architecture:** Keep the current MVVM architecture and internal `GameSequence` model for this phase. Add a small starter-template domain unit that produces reusable `GameSequence` values, then update view models and SwiftUI views to present the feature as templates, rounds, turns, and routines. This phase intentionally avoids StoreKit, sync, widgets, and broad type renames.

**Tech Stack:** Swift 5.0 project settings, SwiftUI, Combine, AVFoundation, XCTest, Xcode 26.6. App target deployment target is iOS 18.0. Watch target deployment target is watchOS 11.0.

## Global Constraints

- Preserve iOS deployment target 18.0.
- Preserve watchOS deployment target 11.0.
- Preserve Swift language version 5.0.
- Preserve MVVM: view models own logic and state machines; views remain declarative.
- Do not introduce third-party dependencies.
- Keep quick timer behavior intact.
- Do not add StoreKit, iCloud sync, shared template import/export, widgets, or App Store asset work in Phase 1.
- Keep internal `GameSequence` naming unless a local edit makes a public-facing string user-visible.
- User-facing copy should prefer Turn Timer, template, sequence, round, turn, routine, and session.

---

## Baseline Notes

- Branch/worktree: `/Users/dfakkeldy/Developer/VisualTimer-turn-timer-phase1` on `codex/turn-timer-phase1`.
- Watch build baseline passed:

```bash
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer Watch Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

- Full iOS test baseline reached UI tests, then simulator launch/cleanup became stuck and was interrupted. Unit-test-only execution also stalled at simulator launch. Use iOS app build and watch build as Phase 1 verification, and record the pre-existing simulator test-runner issue in the PR.

## File Structure

- Create `Visual Timer/StarterTemplateLibrary.swift`: defines starter template metadata and factory data.
- Modify `Visual Timer/GameEditorViewModel.swift`: add starter-template application and first-run loading behavior.
- Modify `Visual Timer/GameEditorView.swift`: rename the editor surface to Templates, add starter template buttons, update fields and section copy.
- Modify `Visual Timer/GamePlaybackView.swift`: update visible game/session copy to Turn Timer language.
- Modify `Visual Timer/Theme.swift`: centralize new labels/symbols/dimensions and change tab title to Templates.
- Modify `Visual Timer.xcodeproj/project.pbxproj`: set app display names to Turn Timer.
- Modify `README.md`, `CLAUDE.md`, and `CONTRIBUTING.md`: align documentation with Turn Timer and the sequence/template direction.
- Modify `Visual TimerTests/Visual_TimerTests.swift`: add tests for starter templates and editor application.

## Task 1: Starter Template Library

**Files:**
- Create: `Visual Timer/StarterTemplateLibrary.swift`
- Modify: `Visual Timer/GameEditorViewModel.swift`
- Modify: `Visual TimerTests/Visual_TimerTests.swift`

**Interfaces:**
- Produces: `struct StarterTemplate: Identifiable, Equatable`
- Produces: `enum StarterTemplateLibrary`
- Produces: `StarterTemplateLibrary.templates: [StarterTemplate]`
- Produces: `StarterTemplateLibrary.defaultTemplate: StarterTemplate`
- Produces: `GameEditorViewModel.applyStarterTemplate(_ template: StarterTemplate)`
- Produces: `GameEditorViewModel.loadInitialTemplateIfNeeded()`
- Consumes: existing `GameSequence`, `Round`, `RoundColor`, and `TimerSound`

- [ ] **Step 1: Write failing tests for starter templates**

Add these tests to `Visual TimerTests/Visual_TimerTests.swift`:

```swift
    // MARK: - StarterTemplateLibrary

    func testStarterTemplateLibrary_containsPhaseOneTemplates() {
        let titles = StarterTemplateLibrary.templates.map(\.title)

        XCTAssertEqual(titles, [
            "Game Night",
            "Recipe Steps",
            "Plant Watering",
            "Classroom Stations",
            "Meeting Agenda",
        ])
    }

    func testStarterTemplateLibrary_gameNightHasPlayerTurnsAndTimeout() {
        let template = StarterTemplateLibrary.defaultTemplate
        let rounds = template.game.rounds

        XCTAssertEqual(template.title, "Game Night")
        XCTAssertEqual(template.game.roundCount, 1)
        XCTAssertEqual(rounds.map(\.name), ["Alice", "Bob", "Charlie", "Timeout"])
        XCTAssertEqual(rounds.map(\.countsAsPlayer), [true, true, true, false])
    }

    func testGameEditorViewModel_applyStarterTemplateReplacesCurrentDraft() {
        let editor = GameEditorViewModel()

        editor.addRound()
        editor.applyStarterTemplate(StarterTemplateLibrary.templates[1])

        XCTAssertEqual(editor.gameTitle, "Recipe Steps")
        XCTAssertEqual(editor.rounds.map(\.name), ["Prep", "Simmer", "Flip or Stir", "Rest"])
        XCTAssertEqual(editor.roundCount, 1)
        XCTAssertNil(editor.expandedRoundId)
    }
```

- [ ] **Step 2: Run tests and verify they fail because symbols do not exist**

Run:

```bash
xcodebuild build-for-testing -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: compile fails with missing `StarterTemplateLibrary` and `applyStarterTemplate` symbols. If the command instead fails due to simulator state, continue and verify with the build command in Step 5 after implementation.

- [ ] **Step 3: Add starter template domain unit**

Create `Visual Timer/StarterTemplateLibrary.swift`:

```swift
import Foundation

struct StarterTemplate: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let game: GameSequence
}

enum StarterTemplateLibrary {
    static let templates: [StarterTemplate] = [
        gameNight,
        recipeSteps,
        plantWatering,
        classroomStations,
        meetingAgenda,
    ]

    static var defaultTemplate: StarterTemplate { gameNight }

    static func template(id: String) -> StarterTemplate? {
        templates.first { $0.id == id }
    }

    private static let gameNight = StarterTemplate(
        id: "game-night",
        title: "Game Night",
        subtitle: "Player turns plus a table timeout.",
        game: makeGame(
            title: "Game Night",
            rounds: [
                round("Alice", emoji: "🎲", color: 0, seconds: 60),
                round("Bob", emoji: "🎯", color: 1, seconds: 60),
                round("Charlie", emoji: "♟️", color: 2, seconds: 60),
                round("Timeout", emoji: "⏳", color: 4, seconds: 120, countsAsPlayer: false),
            ]
        )
    )

    private static let recipeSteps = StarterTemplate(
        id: "recipe-steps",
        title: "Recipe Steps",
        subtitle: "Prep, simmer, stir, and rest.",
        game: makeGame(
            title: "Recipe Steps",
            rounds: [
                round("Prep", emoji: "🔪", color: 6, seconds: 60, countsAsPlayer: false),
                round("Simmer", emoji: "🥘", color: 1, seconds: 300, countsAsPlayer: false),
                round("Flip or Stir", emoji: "🥄", color: 2, seconds: 120, countsAsPlayer: false),
                round("Rest", emoji: "⏲️", color: 5, seconds: 180, countsAsPlayer: false),
            ]
        )
    )

    private static let plantWatering = StarterTemplate(
        id: "plant-watering",
        title: "Plant Watering",
        subtitle: "Water zones with a soak pause.",
        game: makeGame(
            title: "Plant Watering",
            rounds: [
                round("Herbs", emoji: "🌿", color: 3, seconds: 45, countsAsPlayer: false),
                round("Houseplants", emoji: "🪴", color: 4, seconds: 90, countsAsPlayer: false),
                round("Soak Pause", emoji: "💧", color: 6, seconds: 120, countsAsPlayer: false),
                round("Balcony Pots", emoji: "🌱", color: 5, seconds: 90, countsAsPlayer: false),
            ]
        )
    )

    private static let classroomStations = StarterTemplate(
        id: "classroom-stations",
        title: "Classroom Stations",
        subtitle: "Rotate groups through timed stations.",
        game: makeGame(
            title: "Classroom Stations",
            rounds: [
                round("Station 1", emoji: "📚", color: 7, seconds: 300),
                round("Station 2", emoji: "✏️", color: 8, seconds: 300),
                round("Station 3", emoji: "🧪", color: 9, seconds: 300),
                round("Clean Up", emoji: "🧹", color: 10, seconds: 120, countsAsPlayer: false),
            ]
        )
    )

    private static let meetingAgenda = StarterTemplate(
        id: "meeting-agenda",
        title: "Meeting Agenda",
        subtitle: "Keep speakers and agenda items moving.",
        game: makeGame(
            title: "Meeting Agenda",
            rounds: [
                round("Opening", emoji: "👋", color: 11, seconds: 120, countsAsPlayer: false),
                round("Updates", emoji: "📣", color: 12, seconds: 300),
                round("Discussion", emoji: "💬", color: 13, seconds: 600),
                round("Decisions", emoji: "✅", color: 14, seconds: 180, countsAsPlayer: false),
            ]
        )
    )

    private static func makeGame(title: String, rounds: [Round]) -> GameSequence {
        var game = GameSequence(title: title, rounds: rounds, roundCount: 1)
        game.reindexRounds()
        return game
    }

    private static func round(
        _ name: String,
        emoji: String,
        color: Int,
        seconds: Int,
        countsAsPlayer: Bool = true
    ) -> Round {
        Round(
            name: name,
            color: .palette(index: color),
            sound: .chime,
            emoji: emoji,
            durationSeconds: seconds,
            orderIndex: 0,
            countsAsPlayer: countsAsPlayer
        )
    }
}
```

- [ ] **Step 4: Add editor view model support**

In `Visual Timer/GameEditorViewModel.swift`, replace `populateSampleData()` with:

```swift
    func applyStarterTemplate(_ template: StarterTemplate) {
        var game = template.game
        game.reindexRounds()
        gameTitle = game.title
        rounds = game.rounds
        roundCount = game.roundCount
        expandedRoundId = nil
    }

    func loadInitialTemplateIfNeeded() {
        guard rounds.isEmpty else { return }
        if loadLastGame() { return }
        applyStarterTemplate(StarterTemplateLibrary.defaultTemplate)
    }
```

Keep the rest of the file behavior unchanged.

- [ ] **Step 5: Verify build or tests**

Run:

```bash
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** BUILD SUCCEEDED **`.

Run tests if the simulator test runner is healthy:

```bash
xcodebuild test -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'Visual TimerTests'
```

Expected: the new starter-template tests pass. If this repeats the baseline simulator launch hang, record the failure as pre-existing and continue with build verification.

- [ ] **Step 6: Commit**

```bash
git add 'Visual Timer/StarterTemplateLibrary.swift' 'Visual Timer/GameEditorViewModel.swift' 'Visual TimerTests/Visual_TimerTests.swift'
git commit -m "Add starter templates"
```

## Task 2: Templates UI and Turn Timer Copy

**Files:**
- Modify: `Visual Timer/GameEditorView.swift`
- Modify: `Visual Timer/GamePlaybackView.swift`
- Modify: `Visual Timer/Theme.swift`
- Modify: `Visual Timer/MainTabView.swift`

**Interfaces:**
- Consumes: `StarterTemplateLibrary.templates`
- Consumes: `GameEditorViewModel.applyStarterTemplate(_:)`
- Consumes: `GameEditorViewModel.loadInitialTemplateIfNeeded()`
- Produces: user-facing Templates tab and starter-template picker

- [ ] **Step 1: Update tab and shared labels**

In `Theme.Tab`, change `editorTabTitle` from `"Editor"` to `"Templates"`.

In `Theme.Symbol`, add:

```swift
        static let templates = "rectangle.stack.badge.play"
```

In `Theme.Label`, update these values:

```swift
        static let addPlayer = "Add round"
        static let endGame = "End session"
        static let gameOver = "Session complete"
        static let gameDuration = "Session time"
```

Keep `nextPlayer = "Next"` because it is concise in the playback header.

- [ ] **Step 2: Add template picker UI**

In `Visual Timer/GameEditorView.swift`, update the main `VStack` body so it renders `starterTemplates` between `titleField` and `roundCountStepper`:

```swift
            VStack(spacing: 0) {
                titleField
                starterTemplates
                roundCountStepper
                roundsList
            }
```

Add this computed view under `// MARK: - Title Field`:

```swift
    private var starterTemplates: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(StarterTemplateLibrary.templates) { template in
                    Button {
                        editor.applyStarterTemplate(template)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ColorValue.textPrimary)
                            Text(template.subtitle)
                                .font(.caption)
                                .foregroundStyle(Theme.ColorValue.textSecondary)
                                .lineLimit(2)
                        }
                        .frame(width: 150, alignment: .leading)
                        .padding(12)
                        .background(Theme.ColorValue.circleBackground)
                        .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Dimension.screenHorizontalPadding)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }
```

- [ ] **Step 3: Replace editor screen copy**

In `GameEditorView`, make these string changes:

```swift
.navigationTitle("Templates")
Button("Start") { ... }
TextField("Template Name", text: $editor.gameTitle)
Button("Save") { ... }
Text("Repeat Sequence")
Text("Rounds (\(editor.rounds.count))")
Label(Theme.Label.addPlayer, systemImage: Theme.Symbol.addPlayer)
saveAlertMessage = "Template saved to Documents."
```

In `.onAppear`, replace the old load behavior with:

```swift
            .onAppear {
                editor.loadInitialTemplateIfNeeded()
            }
```

- [ ] **Step 4: Replace player-only copy in the edit sheet**

In `PlayerEditSheet`, make these string changes:

```swift
TextField("Round name", text: $nameText)
Label("Counts as turn", systemImage: "person.fill")
```

Keep the field label `Name`, the `Time` label, and the `Start paused` label.

- [ ] **Step 5: Replace playback copy**

In `GamePlaybackView`, make these string changes:

```swift
Text("Turn \(gameViewModel.countingPlayerIndex) of \(gameViewModel.countingPlayerCount)")
Text("Sequence \(gameViewModel.currentOverallRound) of \(gameViewModel.totalRoundCount)")
Text("Session Complete")
name: "Extra Round"
Label("Add Round", systemImage: Theme.Symbol.increment)
```

Keep `Extra Round` and `Add Round` because they match the phase-one public language.

- [ ] **Step 6: Verify build**

Run:

```bash
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add 'Visual Timer/GameEditorView.swift' 'Visual Timer/GamePlaybackView.swift' 'Visual Timer/Theme.swift' 'Visual Timer/MainTabView.swift'
git commit -m "Rebrand editor as templates"
```

## Task 3: Product Display Name and Documentation

**Files:**
- Modify: `Visual Timer.xcodeproj/project.pbxproj`
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `CONTRIBUTING.md`

**Interfaces:**
- Produces: app display name `Turn Timer`
- Produces: documentation aligned with Phase 1 scope

- [ ] **Step 1: Update app display names**

In `Visual Timer.xcodeproj/project.pbxproj`, replace the two iOS app display-name settings:

```text
INFOPLIST_KEY_CFBundleDisplayName = "Turn Timer";
```

Replace the watch display-name settings with:

```text
INFOPLIST_KEY_CFBundleDisplayName = "Turn Timer";
```

Do not change target names, bundle identifiers, product names, deployment targets, or marketing version.

- [ ] **Step 2: Update README**

Rewrite `README.md` so it describes Turn Timer as:

- A visual sequence timer for turns, routines, and real-world countdowns.
- Includes starter templates: Game Night, Recipe Steps, Plant Watering, Classroom Stations, Meeting Agenda.
- Keeps quick timer, visual pie countdown, sounds, sleep prevention, silent-switch override, state machine, template editor, history, and watch app.
- Requirements: iOS 18.0+, watchOS 11.0+, Xcode 26.0+, Swift 5.0 project settings.
- Architecture: MVVM with `TimerViewModel`, `GameViewModel`, `GameEditorViewModel`, `StarterTemplateLibrary`, parser/history/storage, SwiftUI views, and `Theme`.

- [ ] **Step 3: Update agent/contributor docs**

In `CLAUDE.md`, update project context from Visual Timer / Round-Based Game Timer to Turn Timer / visual sequence timer. Keep MVVM, parser, state-machine, theming, and audio rules.

In `CONTRIBUTING.md`, add a short section:

```markdown
## Product Language

Use Turn Timer, templates, sequences, rounds, turns, routines, and sessions in user-facing copy. Internal `GameSequence` naming can remain until a dedicated model migration. Avoid describing the app as only a generic timer or only a board-game timer.
```

- [ ] **Step 4: Verify build**

Run:

```bash
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer Watch Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

Expected: both commands end with `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add 'Visual Timer.xcodeproj/project.pbxproj' README.md CLAUDE.md CONTRIBUTING.md
git commit -m "Update Turn Timer product identity"
```

## Task 4: Phase 1 Final Verification and PR

**Files:**
- Modify: no source files unless verification exposes a Phase 1 regression.

**Interfaces:**
- Consumes: completed Phase 1 branch.
- Produces: pushed `codex/turn-timer-phase1` branch and a GitHub PR.

- [ ] **Step 1: Search for user-facing stale copy**

Run:

```bash
rg -n '"Game Editor"|"Visual Game Timer"|"Visual Timer"|Game Over|Number of Rounds|Player name|Counts as player|Players \\(' 'Visual Timer' README.md CLAUDE.md CONTRIBUTING.md 'Visual Timer.xcodeproj/project.pbxproj'
```

Expected: no matches for changed user-facing copy, except internal type names, target names, and project/product names in `project.pbxproj`.

- [ ] **Step 2: Build app and watch app**

Run:

```bash
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer Watch Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

Expected: both commands end with `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Try unit tests and record result**

Run:

```bash
xcodebuild test -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:'Visual TimerTests'
```

Expected if simulator is healthy: starter-template and existing unit tests pass. If the command stalls/fails with the same baseline simulator launch issue, do not block the PR; record the exact failure in the PR verification section.

- [ ] **Step 4: Inspect diff**

Run:

```bash
git diff --stat origin/main...HEAD
git diff --check
git status --short
```

Expected: no whitespace errors, clean status except intentional commits.

- [ ] **Step 5: Push branch**

Run:

```bash
git push -u origin codex/turn-timer-phase1
```

Expected: branch pushed to origin.

- [ ] **Step 6: Open PR**

Run:

```bash
gh pr create \
  --base main \
  --head codex/turn-timer-phase1 \
  --title "Phase 1: Rebrand as Turn Timer" \
  --body-file /tmp/turn-timer-phase1-pr.md
```

The PR body file should include:

```markdown
## Summary
- Rebrands the app around Turn Timer in user-facing copy and display names.
- Adds starter templates for Game Night, Recipe Steps, Plant Watering, Classroom Stations, and Meeting Agenda.
- Makes the Templates tab load Game Night on first use when no saved template exists.
- Updates README and contributor docs for the Turn Timer roadmap direction.

## Verification
- [ ] iOS app build
- [ ] watch app build
- [ ] unit tests or recorded simulator-test baseline issue

## Notes
- Internal `GameSequence` naming remains intentionally unchanged for Phase 1.
- StoreKit, sync, sharing, and widgets are planned for later phases.
```

- [ ] **Step 7: Report**

Report the PR URL, verification results, and any known baseline issue.
