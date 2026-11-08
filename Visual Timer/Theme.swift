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
            static let dialLabelledDiscRatio: CGFloat = 0.56
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
