# Visual Timer

A minimalist visual countdown timer for iOS built with SwiftUI.
A red circular dial depletes clockwise as time runs out, accompanied
by a three-beep finish sound and automatic screen-wake while the timer
is active.

## Features

- **Visual pie-chart countdown** — The timer circle starts fully red
  and depletes clockwise from the 12 o'clock position. Uses SwiftUI's
  `.trim` modifier for smooth, hardware-accelerated animation.
- **Custom sounds** — Three built-in tones (Chime, Bright, Deep) are
  generated programmatically as 16-bit PCM WAV files. The chosen sound
  plays three times in sequence when the timer reaches zero.
- **Sleep prevention** — The screen stays awake while the timer is
  running and automatically sleeps when paused or reset, balancing
  visibility with battery life.
- **Silent-switch override** — The audio session is configured with
  the `.playback` category so the finish sound plays at full volume
  even when the hardware silent switch is engaged.
- **Single-timer state machine** — Four discrete states (Not Started,
  Running, Paused, Finished) with guarded transitions ensure the timer
  behaves predictably in every scenario.

## Architecture

The app follows **Clean Code** principles with an **MVVM** architecture:

| Layer | Files | Responsibility |
|---|---|---|
| **Model / ViewModel** | `TimerViewModel`, `SoundManager`, `TimerState`, `TimerSound` | State machine, countdown engine, audio session, WAV generation |
| **View** | `ContentView`, `TimerVisualView`, `TimeDisplayView`, `ControlRingView`, `SettingsView` | SwiftUI layout, animation, accessibility labels |
| **Theme** | `Theme` | Single source of truth for colors, dimensions, symbols, and animation durations |

- **`TimerViewModel`** — Owns the timer state machine and a
  Combine-powered countdown. Exposes `@Published` properties that the
  view layer observes. The `onFinish` callback decouples audio
  playback from timer logic.
- **`SoundManager`** — Configures `AVAudioSession` for silent-switch
  bypass, generates WAV tones from sine waves, and sequences three
  beeps via recursive `DispatchQueue` scheduling.
- **Views are "dumb"** — They receive data and callbacks through
  initializer parameters and render accordingly. No business logic
  lives in the view layer.

## Requirements

- iOS 26.0+
- Xcode 26.0+
- Swift 5.0+

## Getting Started

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd Visual\ Timer
   ```
2. Open `Visual Timer.xcodeproj` in Xcode.
3. Select an iOS simulator or connected device.
4. Build and run (⌘R).

No additional dependencies — the project uses only system frameworks
(SwiftUI, Combine, AVFoundation).

## Project Structure

```
Visual Timer/
├── Visual_TimerApp.swift       # App entry point
├── ContentView.swift            # Root view composer
├── TimerVisualView.swift        # Circular countdown dial
├── TimeDisplayView.swift        # MM:SS pill label
├── ControlRingView.swift        # Duration stepper + action buttons
├── SettingsView.swift           # Sound picker sheet
├── TimerViewModel.swift         # State machine + countdown engine
├── SoundManager.swift           # Audio session + WAV generation
├── Theme.swift                  # Visual and layout constants
└── Assets.xcassets/             # App icon and accent color
```
