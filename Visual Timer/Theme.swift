import SwiftUI

/// Centralizes all visual and layout constants so no magic numbers
/// appear in view code.
enum Theme {

    // MARK: - Colors

    enum ColorValue {
        /// One canvas for every tab and sheet: the timer's ink.
        static let appBackground = TimerStyle.ink
        /// Rows, cards and wells sitting on the ink canvas.
        static let surface = Color(red: 0.085, green: 0.095, blue: 0.13)
        static let surfaceStroke = Color.white.opacity(0.08)
        static let circleBackground = surface
        static let buttonFill = Color(white: 0.18)
        static let pillBackground = Color.white.opacity(0.1)
        static let textPrimary = Color.white

        /// 16-color palette cycled through each time the timer finishes.
        static let timerPalette: [Color] = [
            .red, .orange, .yellow, .green,
            .mint, .teal, .cyan, .blue,
            .indigo, .purple, .pink, .brown,
            Color(red: 1.0, green: 0.3, blue: 0.0),       // deep orange
            Color(red: 0.72, green: 0.9, blue: 0.2),      // lime green, yellower than green
            Color(red: 1.0, green: 0.45, blue: 0.72),     // hot pink, lighter than pink
            Color(red: 0.4, green: 0.4, blue: 1.0),       // royal blue
        ]
        static let textSecondary = Color(white: 0.64)
        static let textTertiary = Color(white: 0.46)
        static let selectionAccent = Color.blue
    }

    // MARK: - Dimensions

    enum Dimension {
        static let circleHorizontalPadding: CGFloat = 8
        static let controlButtonSize: CGFloat = 72
        static let timePillHorizontalPadding: CGFloat = 28
        static let timePillVerticalPadding: CGFloat = 12
        static let timeFontSize: CGFloat = 40
        static let sectionSpacingSmall: CGFloat = 20
        static let sectionSpacingLarge: CGFloat = 32
        static let screenHorizontalPadding: CGFloat = 32
        static let gearTopPadding: CGFloat = 8
        static let controlButtonSpacing: CGFloat = 24
        static let durationStepperSpacing: CGFloat = 20
        static let compactContentVerticalPadding: CGFloat = 16
        static let compactTimerCircleMaxSize: CGFloat = 280
        static let landscapeTimerCircleMaxSize: CGFloat = 240
        static let landscapeControlColumnWidth: CGFloat = 240
    }

    // MARK: - Timer finish and glass styling

    enum TimerStyle {
        static let ink = Color(red: 0.025, green: 0.035, blue: 0.065)
        /// Backing disc that keeps the centre glyph whole over the pie edge.
        static let glyphDiscSize: CGFloat = 92
        static let glyphDiscOpacity = 0.55
        static let digitsSize: CGFloat = 56
        static let captionSpacing: CGFloat = 6
        static let capsuleHeight: CGFloat = 44
        static let capsuleHorizontalPadding: CGFloat = 16
        static let well = Color(red: 0.055, green: 0.065, blue: 0.085)
        static let controlSize: CGFloat = 44
        static let controlSpacing: CGFloat = 8
        static let surfaceBorder: CGFloat = 1
        static let rimWidth: CGFloat = 1.5
        static let glowRadius: CGFloat = 24
        static let glowOpacity = 0.2
        static let backdropOpacity = 0.12
        static let highlightOpacity = 0.32
        static let shadeOpacity = 0.24
        static let restingIconSize: CGFloat = 52
        static let runningIconSize: CGFloat = 36
        static let iconOpacity = 0.92
        static let iconShadowRadius: CGFloat = 6
        static let pressedScale: CGFloat = 0.975
        static let disabledOpacity = 0.45
        static let pressDuration = 0.18
        static let colourDuration = 0.45
        static let rippleScale: CGFloat = 1.12
        static let rippleOpacity = 0.35
        static let rippleDuration = 0.7
        static let rippleAttack = 0.08
    }

    // MARK: - Animation

    enum AnimationValue {
        static let stateTransitionDuration: Double = 0.2
        static let timerTickDuration: Double = 1.0
    }

    // MARK: - History timeline

    /// A past session drawn as one vertical spine, each round as tall as its
    /// share of the session.
    enum HistoryTimeline {
        static let spineWidth: CGFloat = 12
        static let spineColumnWidth: CGFloat = 32
        static let spineRadius: CGFloat = 6
        /// The break between two turns, and between two passes ("Round 2").
        /// Each turn's start time sits centred in the break above it.
        static let turnGap: CGFloat = 16
        static let passGap: CGFloat = 20
        /// The break under a round heading, which also holds the first clock.
        static let clockBreak: CGFloat = 20
        /// Space between the spine column and a round's label.
        static let labelInset: CGFloat = 10
        /// Rounds share this height, at least this much per round.
        static let heightPerRound: Double = 72
        static let minimumTotalHeight: Double = 480
        /// Room a round's label needs; extra height beyond its colour is hairline.
        static let minimumRowHeight: Double = 52
        static let rowTopPadding: CGFloat = 2
        static let pauseLabelHalfHeight: CGFloat = 8
        /// Pause labels never sit higher than this, clear of the name and start line.
        static let pauseLabelMinimumY: CGFloat = 46
        static let pauseLabelMinimumYNoNote: CGFloat = 30
        /// The least room between two pause labels in one turn.
        static let pauseLabelSpacing: CGFloat = 18
        static let eventLineWidth: CGFloat = 2
        static let finishDiscSize: CGFloat = 20
        static let finishMarkSize: CGFloat = 16
        static let endedMarkSize: CGFloat = 12
        /// Extra room at the foot of a turn that ends in "went back".
        static let wentBackLabelHeight: CGFloat = 26
        /// Room under the went-back line, so it reads as the end of its own turn.
        static let wentBackBottomSpace: CGFloat = 8
        static let legendSwatchHeight: CGFloat = 22
        static let deleteTopPadding: CGFloat = 32
        static let dimmedOpacity = 0.45
        static let pauseShade = TimerStyle.ink.opacity(0.4)
        static let hatchLine = Color.white.opacity(0.22)
        static let hatchLineWidth: CGFloat = 1
        static let hatchSpacing: CGFloat = 5
        static let revealDuration = 0.7
        static let eventLine = ColorValue.surfaceStroke
        static let wentBackSymbol = "arrow.uturn.backward"
    }

    /// A session's totals per name: pie, ranked bars, or turn blocks.
    enum HistoryTotals {
        static let pieSize: CGFloat = 104
        static let ringWidth: CGFloat = 12
        static let seamWidth: CGFloat = 1.5
        static let pieSpacing: CGFloat = 20
        static let rowSpacing: CGFloat = 12
        static let labelWidth: CGFloat = 96
        static let barHeight: CGFloat = 12
        static let barRadius: CGFloat = 6
        static let barMinWidth: CGFloat = 3
        /// Turn blocks meet at a seam; a new pass gets a wider break.
        static let turnGap: CGFloat = 4
        static let passGap: CGFloat = 8
        static let averageValueWidth: CGFloat = 112
        static let percentWidth: CGFloat = 36
        /// One row of the tallest view (Turns: a block and its length beneath).
        static let rowHeight: CGFloat = 30
        /// Room for a key of up to two lines, so a longer key never crowds what follows.
        static let keyHeight: CGFloat = 34
        static let keySpacing: CGFloat = 10
        /// The short colour mark that ties a Pie legend row to its arc.
        static let legendMarkWidth: CGFloat = 4
        /// The faint full-length track behind each bar.
        static let track = ColorValue.surfaceStroke

        /// The same height for Pie, Bars and Turns, so the switch never moves
        /// anything below it.
        static func contentHeight(names: Int) -> CGFloat {
            let rows = CGFloat(names) * rowHeight + CGFloat(max(names - 1, 0)) * rowSpacing
            return max(pieSize, rows) + keySpacing + keyHeight
        }
    }

    // MARK: - Timer Mechanics

    enum TimerMechanic {
        static let durationStep: Int = 5
        static let minimumDuration: Int = 5
        static let defaultDuration: Int = 25
        static let timerTickInterval: TimeInterval = 1.0
    }

    // MARK: - Rotation

    enum Rotation {
        /// Rotates the trim origin from 3 o'clock to 12 o'clock.
        static let trimOriginOffset: Double = -90
    }

    // MARK: - SF Symbols

    enum Symbol {
        static let settings = "gearshape.fill"
        static let play = "play.fill"
        static let pause = "pause.fill"
        static let reset = "arrow.counterclockwise"
        static let increase = "plus"
        static let decrease = "minus"
        static let increment = "plus.circle.fill"
        static let decrement = "minus.circle.fill"
        static let checkmark = "checkmark"
        static let edit = "pencil"
        static let delete = "trash"
        static let addPlayer = "plus"
        static let activeToggle = "circle.fill"
        static let inactiveToggle = "circle"
        static let startPaused = "hand.raised.fill"
        static let endGame = "flag.checkered"
        static let dragHandle = "line.horizontal.3"
        static let doOver = "backward.end"
        static let skip = "forward.end"
        static let restart = "arrow.counterclockwise"
        static let stopSession = "stop"
        static let more = "ellipsis"
        static let soundPreview = "speaker.wave.2"
        static let history = "clock.arrow.circlepath"
        static let nextPlayer = "arrow.right"
        static let templates = "rectangle.stack.badge.play"
        static let savedTemplates = "tray.full"
        static let importTemplate = "square.and.arrow.down"
        static let exportTemplate = "square.and.arrow.up"
        static let proUnlock = "lock.open"
        static let proTemplates = "rectangle.stack.badge.plus"
        static let proHistoryExport = "square.and.arrow.up"
        static let proFutureFeatures = "icloud"
    }

    // MARK: - Starter Template Emoji

    enum Emoji {
        static let wakeUp = "⏰"
        static let washUp = "🚿"
        static let getDressed = "👕"
        static let breakfast = "🥣"
        static let brushTeeth = "🪥"
        static let packEssentials = "🎒"
        static let shoesAndCoat = "🧥"
        static let startCommute = "🚗"
    }

    // MARK: - Accessibility Labels

    enum Label {
        static let play = "Play"
        static let start = "Start"
        static let pause = "Pause"
        static let unpause = "Unpause"
        static let resume = "Resume"
        static let reset = "Reset"
        static let settings = "Settings"
        static let decrementDuration = "Decrease duration"
        static let incrementDuration = "Increase duration"
        static let addPlayer = "Add round"
        static let endGame = "End session"
        static let endShort = "End"
        static let done = "Done"
        static let goAgain = "Go again"
        static let tapToStart = "Tap the dial to start"
        static let paused = "Paused"
        static let startPaused = "Start paused"
        static let roundActive = "Round active"
        static let gameOver = "Session complete"
        static let doOver = "Back"
        static let skip = "Skip"
        static let restart = "Restart"
        static let nextPlayer = "Next"
        static let gameDuration = "Session time"
        static let export = "Export"
        static let importTemplate = "Import template"
        static let exportTemplate = "Export template"
        static let delete = "Delete"
    }

    // MARK: - Tab Bar

    enum Tab {
        static let timerTabSymbol = "timer"
        static let timerTabTitle = "Timer"
        static let editorTabSymbol = Symbol.templates
        static let editorTabTitle = "Templates"
        static let historyTabSymbol = "clock.arrow.circlepath"
        static let historyTabTitle = "History"
    }

    // MARK: - Editor

    enum Editor {
        static let rowHeight: CGFloat = 56
        static let expandedRowHeight: CGFloat = 200
        static let colorSwatchSize: CGFloat = 32
        static let colorSwatchSpacing: CGFloat = 8
        static let emojiFieldWidth: CGFloat = 48
        static let sectionHeaderFontSize: CGFloat = 13
    }

    // MARK: - Game Playback

    enum GamePlayback {
        static let headerEmojiSize: CGFloat = 34
        static let headerNameSize: CGFloat = 28
        static let progressDotSize: CGFloat = 7
        static let progressDotCurrentSize: CGFloat = 11
        static let progressDotSpacing: CGFloat = 6
        static let dialMaxSize: CGFloat = 330
        static let roundBannerFontSize: CGFloat = 16
        static let roundProgressFontSize: CGFloat = 13
        static let gameOverFontSize: CGFloat = 28
        static let playbackSpacing: CGFloat = 12
        static let nextPlayerMaxWidth: CGFloat = 140
    }

    // MARK: - Watch

    enum Watch {

        enum Dimension {
            static let contentSpacing: CGFloat = 6
            static let controlSpacing: CGFloat = 6
            /// watchOS asks for touch targets of at least 38 pt.
            static let controlMinHeight: CGFloat = 44
            static let digitMinTarget: CGFloat = 38
            static let controlIconSpacing: CGFloat = 2
            static let quickDialMaxSize: CGFloat = 120
            static let quickPieSize: CGFloat = 104
            static let quickPieMinSize: CGFloat = 68
            /// The gap, the 44 pt readout row and the crown cue beneath the dial.
            static let quickBelowDialHeight: CGFloat = 66
            static let dialLabelledDiscRatio: CGFloat = 0.62
            static let pausedDialOpacity: Double = 0.55
            static let sessionDialSize: CGFloat = 76
            static let dialLineWidth: CGFloat = 8
            static let selectionCornerRadius: CGFloat = 6
            static let digitMinimumScale: CGFloat = 0.5
            static let captionMinimumScale: CGFloat = 0.7
        }

        enum ColorValue {
            static let ringTrack = Color.white.opacity(0.15)
            static let selection = Color.white.opacity(0.25)
            /// Idle digits sit on a faint well so they read as editable.
            static let editable = Color.white.opacity(0.08)
            static let sessionComplete = Color.green
        }

        enum Symbol {
            static let quickTimer = "timer"
            static let resumeSession = "play.circle"
            static let allowAlerts = "bell.badge"
            static let alertsOff = "bell.slash"
            static let sessionComplete = "checkmark.circle.fill"
            static let previous = "backward.end.fill"
        }

        enum Label {
            static let quickTimer = "Quick Timer"
            static let starterTemplates = "Starter Templates"
            static let savedTemplates = "Saved Templates"
            static let resumeSession = "Resume Session"
            static let sessionComplete = "All done"
            static let done = "Done"
            static let running = "Running"
            static let paused = "Paused"
            static let minutes = "Minutes"
            static let seconds = "Seconds"
            static let timeRemaining = "Time remaining"
            static let timeSeparator = ":"
            static let crownHint = "Select, then turn the Digital Crown to change."
            static let crownCue = "Tap a number, turn the Crown"
            static let previous = "Back"
            static let allowAlerts = "Allow Alerts"
            static let allowAlertsDetail = "Get a notification when a timer ends while Turn Timer is not on screen."
            static let allowAlertsShort = "When a timer ends off screen"
            static let alertsOff = "Alerts Off"
            static let alertsOffDetail = "Turn Timer can alert you only while it is on screen. You can allow notifications for Turn Timer in Settings."
        }

        enum Notification {
            static let quickTitle = "Quick Timer done"
            static let quickBody = "Your countdown has finished."
            static let roundFallbackTitle = "Round finished"

            static func roundFinishedTitle(_ roundName: String) -> String {
                "\(roundName) finished"
            }
        }

        /// Stable accessibility identifiers for UI tests and assistive tools.
        enum Identifier {
            static let rootQuickTimer = "watch.root.quickTimer"
            static let rootResumeSession = "watch.root.resumeSession"
            static let rootAllowAlerts = "watch.root.allowAlerts"
            static let rootAlertsOff = "watch.root.alertsOff"
            static func rootStarter(_ id: String) -> String { "watch.root.starter.\(id)" }
            static let quickPrimary = "watch.quick.primary"
            static let quickReset = "watch.quick.reset"
            static let quickTime = "watch.quick.time"
            static let quickMinutes = "watch.quick.minutes"
            static let quickSeconds = "watch.quick.seconds"
            static let sessionPrimary = "watch.session.primary"
            static let sessionRestart = "watch.session.restart"
            static let sessionPrevious = "watch.session.previous"
            static let sessionSkip = "watch.session.skip"
            static let sessionEnd = "watch.session.end"
            static let sessionTime = "watch.session.time"
            static let sessionDone = "watch.session.done"
        }
    }
}

// MARK: - Stopwatch routines (kept separate from countdown/history styling)
extension Theme {
    enum Stopwatch {
        static let spacing: CGFloat = 16
        static let smallSpacing: CGFloat = 8
        static let minimumTarget: CGFloat = 44
        static let chartHeight: CGFloat = 220
        static let chartRowHeight: CGFloat = 52
        static let chartMinimumHeight: CGFloat = 140
        static let chartLineWidth: CGFloat = 2
        static let targetDash: [CGFloat] = [5, 4]
        static let actualColor = Color.cyan
        static let prominentTint = Color(red: 0, green: 0.40, blue: 0.85)
        static let targetColor = ColorValue.textSecondary
        static let symbol = "stopwatch"
        static let planSymbol = "list.bullet.rectangle"
        static let completedSymbol = "checkmark.circle.fill"
        static let currentSymbol = "record.circle"
        static let upcomingSymbol = "circle"
        static let closeSymbol = "xmark"
        static let optionsSymbol = "ellipsis"
        static let moveUpSymbol = "arrow.up"
        static let moveDownSymbol = "arrow.down"
        static let deleteSymbol = "trash"
        static let nextSymbol = "forward.end.fill"
        static let pauseSymbol = "pause.fill"
        static let resumeSymbol = "play.fill"
        static let emptySymbol = "chart.xyaxis.line"
        static let addSymbol = "plus"
        static let localSymbol = "iphone"
        static let title = "Learn a routine"
        static let timeTemplate = "Time this template"
        static let planRoutine = "Plan a new routine"
        static let editorHint = "Name your steps first, then learn their durations with a stopwatch."
        static let newRoutine = "New routine"
        static let completed = "Completed"
        static let currentStep = "Current step"
        static let upcoming = "Upcoming"
        static let retryLoading = "Check again"
        static let allRecordings = "All local recordings"
        static func progress(position: Int, count: Int, isPaused: Bool) -> String {
            "Step \(position) of \(count) · \(isPaused ? paused : recording)"
        }
        static func elapsed(_ formatted: String) -> String {
            "Elapsed, \(formatted)"
        }
        static func recordingSummary(measured: Int, total: Int, duration: String) -> String {
            "\(measured)/\(total) steps · \(duration)"
        }
        static func unreadableFiles(_ count: Int) -> String {
            "\(count) local recording file(s) couldn't be read. The files were kept for recovery."
        }
        static let recordingsEntry = "Local stopwatch recordings"
        static func openSourceHint(_ title: String) -> String {
            "Open “\(title)” in Templates to apply this recording's measurements."
        }
        static let navigationTitle = "Routine stopwatch"
        static let planTitle = "Plan your routine"
        static let routineName = "Routine name"
        static let stepName = "Step name"
        static let addStep = "Add step"
        static let planHint = "Give each step a name. You don't need durations yet. Use a step's options to move or delete it. You can also drag to reorder or swipe to delete."
        static let existingHint = "One pass through enabled steps. Repeat count and start-paused settings don't apply here."
        static let newHint = "Your first recording has no targets. Apply a complete recording to create an editable template."
        static let localHint = "Recordings stay on this device. They don't sync to iCloud or Apple Watch."
        static let sourceHint = "Save the template to return to this routine's recordings from the template picker."
        static let start = "Start recording"
        static let recording = "Recording"
        static let paused = "Paused"
        static let pausedHint = "Paused time is excluded. Next starts the next step immediately."
        static let backgroundHint = "Time keeps counting while the app is in the background. Save or apply before closing; unfinished recordings won't survive an app restart."
        static let limitHint = "24-hour step limit reached. Choose Next or Finish to review."
        static let next = "Next step"
        static let finish = "Finish & review"
        static let finishEarly = "Finish early"
        static let finishEarlyTitle = "Finish before all steps are measured?"
        static func finishEarlyHint(current: String?, count: Int, isNewRoutine: Bool) -> String {
            let partial = current.map { "“\($0)” keeps its time so far. " } ?? ""
            let remaining = partial + (count == 1 ? "1 later step won't be measured." : "\(count) later steps won't be measured.")
            return isNewRoutine ? remaining + " " + partialNewHint : remaining
        }
        static let pause = "Pause"
        static let resume = "Resume"
        static let review = "Review measurements"
        static let actual = "Actual"
        static let target = "Target"
        static let seconds = "Seconds"
        static let saveRecording = "Save recording"
        static let apply = "Apply durations"
        static let applyNew = "Apply as new template"
        static let applyHint = "Applying saves this recording and edits the template. Save in the editor to keep the template changes. Starting the timer also saves a template that's already saved. Durations round to whole seconds, with a \(TimerMechanic.minimumDuration)-second minimum."
        static let partialNewHint = "This recording ended early. Record every step to create a template. You can still save these measurements."
        static let partialHint = "Only measured steps will change. Other template durations stay as they are."
        static let neutralHint = "More or less time is information, not a score."
        static let notSaved = "Not saved yet"
        static let saved = "Saved on this device"
        static let savedNewRoutineHint = "Find it later in \(recordingsEntry)."
        static let savedAction = "Saved"
        static let recordAgain = "Back to routine"
        static let history = "Local recordings"
        static let trend = "Step over time"
        static let chooseStep = "Step"
        static let emptyTitle = "No recordings yet"
        static let noRecentRecordings = "No recent recordings for this routine"
        static let emptyHint = "Finish and save a recording to compare this routine over time."
        static let trendEmpty = "No saved measurements for this step yet."
        static let onePointHint = "One recording so far. Record again to see how time changes."
        static let accessibilityTrendHint = "Each recording's date, actual time and original target are listed below."
        static let trendHint = "Circles show actual time. Squares and the dashed target line show each recording's original target. Dates and values are listed below."
        static let historyLimit = "Older recordings are kept. Unlock Pro to see full history."
        static let historyBlockedByPlan = "Save a recording of your edited plan, or undo the plan edits, before opening local recordings."
        static let undoPlanEdits = "Undo plan edits"
        static let undoPlanEditsTitle = "Undo plan edits?"
        static let unlockHistory = "See full history"
        static let close = "Close"
        static let returnToStopwatch = "Return to stopwatch"
        static let unsavedPlan = "Unsaved plan"
        static let unsavedReview = "Unsaved review"
        static let retainedWorkspaceHint = "Return to your stopwatch to keep or discard its work before opening another stopwatch."
        static let discardPlanTitle = "Discard this plan?"
        static let discardPlanAndRecordingHint = "Discard just the measurements to keep editing your plan, or discard both the recording and plan. Saved recordings stay on this device."
        static let discardRecordingKeepingPlanHint = "Discard just the measurements to record this routine again, or discard the recording and close. Saved recordings stay on this device."
        static let discardPlanHint = "Your unsaved routine name and step edits will be lost."
        static let discardPlan = "Discard plan"
        static let discardReviewTitle = "Discard these measurements?"
        static let discardReviewHint = "This review hasn't been saved. Its measurements will be lost."
        static let discardTitle = "Discard this recording?"
        static let discardHint = "Unkept measurements will be lost. Saved recordings stay on this device."
        static let discard = "Discard recording"
        static let discardMeasurementsKeepingPlan = "Discard measurements, keep plan"
        static let discardRecordingAndPlan = "Discard recording and plan"
        static let keepRecording = "Keep recording"
        static let errorTitle = "Stopwatch"
        static let ok = "OK"
        static let deleteTitle = "Delete this recording?"
        static let deleteHint = "This removes its local measurements. It doesn't change the template."
        static let deleteRecording = "Delete recording"
        static let recordingDeleted = "Recording deleted"
        static let cancel = "Cancel"
        static let replaceTitle = "Replace your unsaved template edits?"
        static let replaceHint = "Applying this new routine replaces the edits currently in the template editor. Your saved templates stay as they are."
        static let applyIdentifier = "stopwatch.apply"
        static let startIdentifier = "stopwatch.start"
        static let nextIdentifier = "stopwatch.next"
        static let finishEarlyIdentifier = "stopwatch.finishEarly"
        static let finishIdentifier = "stopwatch.finish"
        static let elapsedIdentifier = "stopwatch.elapsed"
        static let missingRoutineName = "Add a routine name"
        static let missingSteps = "Add at least one step"
        static let moveUp = "Move up"
        static let moveDown = "Move down"
        static let deleteStep = "Delete step"
        static func missingStepName(_ position: Int) -> String { "Step \(position) needs a name" }
        static func fixInTemplateEditor(_ problem: String) -> String {
            "\(problem.hasSuffix(".") ? problem : problem + ".") Change it in the template editor."
        }
        static func saveFirst(_ detail: String) -> String { "Save this recording first. \(detail)" }
        static func stepName(_ position: Int) -> String { "Step \(position) name" }
        static func stepOptions(_ position: Int) -> String { "Step \(position) options" }
        static func stepAnnouncement(position: Int, count: Int, name: String) -> String {
            "Step \(position) of \(count), \(name)"
        }
        static func earlierStep(_ name: String) -> String { "\(name) (not in current plan)" }
        static func setsDuration(_ seconds: Int) -> String { "Template duration: \(seconds)s" }
        static let invalidSource = "Add named steps before recording. Each target must be between 1 second and 24 hours."
        static let invalidRecording = "This stopwatch recording is invalid or uses an unsupported format."
        static func changedTemplate(_ title: String) -> String {
            "The template or its enabled steps have changed. Open “\(title)”, then \(recordingsEntry) to apply. Restore any removed or disabled measured steps first."
        }
        static func saveError(_ detail: String) -> String {
            "Recording could not be saved on this device: \(detail) Try again before closing."
        }
        static func deleteError(_ detail: String) -> String { "Recording could not be deleted: \(detail)" }
        static func loadError(_ detail: String) -> String { "Local recordings could not be loaded: \(detail)" }
        static func comparisonWithoutTarget(_ actual: String) -> String { "Actual \(actual) · No target" }
        static let matchesTarget = "matches target"
        static func overTarget(_ difference: String) -> String { "\(difference) over target" }
        static func underTarget(_ difference: String) -> String { "\(difference) under target" }
        static func comparison(target: String, actual: String, delta: String) -> String {
            "Target \(target) · Actual \(actual) · \(delta)"
        }
    }
}
