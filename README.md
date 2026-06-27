# Turn Timer

Turn Timer is a visual sequence timer for turns, routines, and real-world countdowns.
It keeps the one-tap visual countdown from the original app and adds editable
starter templates for common timed sessions.

## Phase 1 Scope

- **Quick timer** - Start a standalone visual countdown with the existing timer
  controls.
- **Starter templates** - Begin from Game Night, Recipe Steps, Plant Watering,
  Classroom Stations, or Meeting Agenda.
- **Template editor** - Rename a template, edit rounds, set colors, choose
  sounds, add emoji, and decide whether a round counts as a turn.
- **Sequence playback** - Run rounds in order, repeat the sequence, skip,
  restart, or do over a turn.
- **History** - Review completed timer sessions.
- **Watch app** - Keep companion watch target support.

## Core Features

- **Visual pie countdown** - A circular timer depletes clockwise from the
  12 o'clock position using SwiftUI drawing and animation.
- **Custom sounds** - Built-in tones are generated programmatically as 16-bit
  PCM WAV files. The chosen sound plays when a countdown reaches zero.
- **Sleep prevention** - The screen stays awake while a timer is running and
  returns to normal sleep behavior when paused or reset.
- **Silent-switch override** - The audio session uses playback behavior so the
  finish sound can play even when the hardware silent switch is engaged.
- **State machines** - Timer and sequence transitions are guarded so playback
  remains predictable across play, pause, skip, restart, and completion.

## Product Roadmap

Turn Timer is planned as a $4.99 paid app with Pro value built around:

- iCloud sync for templates and history.
- Shared templates for families, classrooms, kitchens, meetings, and game
  nights.
- Home Screen and Lock Screen widgets for one-tap template starts.

## Architecture

The app follows an MVVM architecture with small SwiftUI views and centralized
state owners.

| Layer | Files | Responsibility |
|---|---|---|
| Timer core | `TimerViewModel`, `TimerState`, `TimerSound`, `SoundManager` | Countdown state, audio, sleep prevention |
| Sequence core | `GameViewModel`, `GameSequence`, `Round` | Ordered playback, repeats, turn progress |
| Templates | `GameEditorViewModel`, `StarterTemplateLibrary`, `GameFileParser` | Template editing, starter data, local save/load |
| History | `HistoryViewModel`, session models and views | Completed session storage and review |
| Views | `MainTabView`, `GamePlaybackView`, `GameEditorView`, timer/editor components | SwiftUI layout and user interaction |
| Theme | `Theme` | Shared colors, symbols, labels, dimensions, and animation values |

Views should remain declarative. Business logic belongs in view models or
storage/parser helpers, with state flowing down and user actions flowing back up
through callbacks.

## Requirements

- iOS 18.0+
- watchOS 11.0+
- Xcode 26.0+
- Swift 5.0 project settings

## Getting Started

1. Clone the repository.
2. Open `Visual Timer.xcodeproj` in Xcode.
3. Select an iOS simulator or connected device.
4. Build and run with Command-R.

No additional dependencies are required. The project uses only system
frameworks, including SwiftUI, Combine, AVFoundation, and WatchKit support.
