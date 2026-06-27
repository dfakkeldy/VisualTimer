# Turn Timer

Turn Timer is a visual sequence timer for turns, routines, and real-world countdowns.
It keeps the one-tap visual countdown from the original app and adds editable
starter templates for common timed sessions.

## Current Scope

- **Quick timer** - Start a standalone visual countdown with the existing timer
  controls.
- **Starter templates** - Begin from Game Night, Recipe Steps, Plant Watering,
  Classroom Stations, or Meeting Agenda.
- **Template editor** - Rename a template, edit rounds, set colors, choose
  sounds, add emoji, and decide whether a round counts as a turn.
- **Sequence playback** - Run rounds in order, repeat the sequence, skip,
  restart, or do over a turn.
- **History** - Review completed timer sessions, with recent sessions free and
  full local history available with Pro.
- **Turn Timer Pro** - Unlock unlimited saved templates and history export with
  a one-time $4.99 StoreKit purchase.
- **Shared template files** - Import and export portable `.turntimer` template
  files without overwriting existing local work.
- **Pro iCloud template sync** - Pro users can sync saved templates across their
  own devices through the private CloudKit database.
- **Favorite templates and widgets** - Mark one saved template as the favorite
  and start it from Home Screen or Lock Screen widgets.
- **Watch app** - Use watch-local starter templates with a crown-adjustable
  countdown.

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
- **StoreKit Pro unlock** - `turntimer.pro.unlock` is configured in
  `TurnTimer.storekit` for local testing. Free users keep starter templates and
  one custom saved template; Pro unlocks additional saved templates, full
  history/export, and template sync.
- **Portable template documents** - Saved templates live in
  `Documents/Templates/<templateID>.turntimer` as JSON. Legacy `.vtgame` files
  still load for migration, but new saves use the `.turntimer` document format.
- **iCloud sync** - `CKSyncEngine` syncs Pro template records in the private
  CloudKit database under container `iCloud.Dan.Visual-Timer`. Selected sound
  syncs through `NSUbiquitousKeyValueStore`.
- **Widget quick starts** - The app writes favorite-template snapshots into App
  Group `group.Dan.Visual-Timer`. Widget intents write a pending start request
  and open the app; the app consumes that request and starts the template.
- **Watch-native timer** - The watch app uses its own template list and timer
  view model so it does not depend on iOS-only audio, CloudKit, or idle-timer
  behavior.

## Product Roadmap

Turn Timer is planned as a free timer with a $4.99 one-time Pro unlock. The
core timer, built-in starter templates, and one custom saved template remain
free. Pro value is built around reuse and portability:

- Additional saved templates.
- Full local history and history export.
- iCloud sync for saved templates.
- Future iCloud sync for history.
- Shared templates for families, classrooms, kitchens, meetings, and game
  nights.
- Richer widget controls, live progress surfaces, and shared template workflows.

## Architecture

The app follows an MVVM architecture with small SwiftUI views and centralized
state owners.

| Layer | Files | Responsibility |
|---|---|---|
| Timer core | `TimerViewModel`, `TimerState`, `TimerSound`, `SoundManager` | Countdown state, audio, sleep prevention |
| Sequence core | `GameViewModel`, `GameSequence`, `Round` | Ordered playback, repeats, turn progress |
| Templates | `GameEditorViewModel`, `StarterTemplateLibrary`, `TemplateLibraryStore`, `TemplateDocumentCodec`, `GameFileParser` | Template editing, starter data, local save/load, import/export |
| Sync | `TemplateCloudSyncEngine`, `TemplateCloudRecordMapper`, `UbiquitousSettingsStore` | Pro iCloud template sync and lightweight settings sync |
| Widgets | `TurnTimerWidget`, `TurnTimerShared`, `TemplateWidgetUpdater` | Favorite-template snapshots, AppIntent starts, widget empty states |
| Watch | `WatchApp` | Watch-local templates and crown-adjustable countdown |
| History | `HistoryViewModel`, session models and views | Completed session storage and review |
| Monetization | `ProAccessViewModel`, `ProFeature`, access policies | StoreKit purchase state and Pro feature gates |
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
frameworks, including SwiftUI, Combine, AVFoundation, StoreKit, WidgetKit,
AppIntents, and WatchKit support.

## CloudKit Setup

Template sync uses CloudKit container `iCloud.Dan.Visual-Timer`, custom zone
`TurnTimerTemplates`, and record type `Template`. The record stores a `title`,
the encoded `.turntimer` JSON `payload`, and `createdAt`, `modifiedAt`, and
`exportedAt` dates.

Before shipping sync to TestFlight or the App Store, confirm the container is
enabled for the app identifier, run the app with a signed build and an iCloud
account, create or sync at least one template, then deploy the CloudKit
development schema to production in CloudKit Dashboard. Local simulator builds
verify compilation and record mapping, but they do not prove live iCloud account,
container, subscription, or production-schema behavior.

## Widgets and Watch

Widgets read only compact favorite-template snapshots from App Group
`group.Dan.Visual-Timer`. They are quick-start surfaces, not a background live
timer: tapping Start opens the app, which loads and starts the favorite template.
If no favorite exists, the widget opens the Templates tab so the user can choose
one.

The watch app intentionally stays local and lightweight. It ships with watch
starter templates and a crown-adjustable timer, but it does not sync saved
templates or play the iPhone app's generated sounds yet.

## App Store Launch Docs

Phase 5 launch planning lives in `docs/app-store/`:

- `app-store-copy.md` - App Store subtitle, description, What's New, keywords,
  and review notes.
- `screenshot-plan.md` - Default screenshot sequence and later campaign sets.
- `privacy-policy.md` - Draft public privacy policy and App Store privacy label
  mapping.
- `support.md` - Draft public support page.
- `featuring-nomination.md` - App Store editorial nomination draft.
- `release-checklist.md` - App Store Connect, StoreKit, CloudKit, screenshot,
  TestFlight, accessibility, and release verification checklist.
