import SwiftUI

/// Centralizes all visual and layout constants so no magic numbers
/// appear in view code.
enum Theme {

    // MARK: - Colors

    enum ColorValue {
        static let appBackground = Color.black
        static let circleBackground = Color(white: 0.12)
        static let buttonFill = Color(white: 0.18)
        static let pillBackground = Color.white.opacity(0.1)
        static let textPrimary = Color.white

        /// 16-color palette cycled through each time the timer finishes.
        static let timerPalette: [Color] = [
            .red, .orange, .yellow, .green,
            .mint, .teal, .cyan, .blue,
            .indigo, .purple, .pink, .brown,
            Color(red: 1.0, green: 0.3, blue: 0.0),       // deep orange
            Color(red: 0.3, green: 0.8, blue: 0.3),       // lime green
            Color(red: 0.9, green: 0.2, blue: 0.5),       // hot pink
            Color(red: 0.4, green: 0.4, blue: 1.0),       // royal blue
        ]
        static let textSecondary = Color.gray
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
        static let addPlayer = "person.badge.plus"
        static let activeToggle = "circle.fill"
        static let inactiveToggle = "circle"
        static let startPaused = "hand.raised.fill"
        static let endGame = "flag.checkered"
        static let dragHandle = "line.horizontal.3"
        static let doOver = "arrow.uturn.backward"
        static let skip = "forward.end.fill"
        static let restart = "arrow.counterclockwise.circle"
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
        static let pause = "Pause"
        static let unpause = "Unpause"
        static let reset = "Reset"
        static let settings = "Settings"
        static let decrementDuration = "Decrease duration"
        static let incrementDuration = "Increase duration"
        static let addPlayer = "Add round"
        static let endGame = "End session"
        static let startPaused = "Start paused"
        static let roundActive = "Round active"
        static let gameOver = "Session complete"
        static let doOver = "Do-over"
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
        static let roundBannerFontSize: CGFloat = 16
        static let roundProgressFontSize: CGFloat = 13
        static let gameOverFontSize: CGFloat = 28
        static let playbackSpacing: CGFloat = 12
        static let nextPlayerMaxWidth: CGFloat = 140
    }
}
