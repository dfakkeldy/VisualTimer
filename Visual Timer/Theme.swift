import SwiftUI

/// Centralizes all visual and layout constants so no magic numbers
/// appear in view code.
enum Theme {

    // MARK: - Colors

    enum ColorValue {
        static let appBackground = Color.black
        static let circleBackground = Color(white: 0.12)
        static let timerFill = Color.red
        static let buttonFill = Color(white: 0.18)
        static let pillBackground = Color.white.opacity(0.1)
        static let textPrimary = Color.white
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
        static let increment = "plus.circle.fill"
        static let decrement = "minus.circle.fill"
        static let checkmark = "checkmark"
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
    }
}
