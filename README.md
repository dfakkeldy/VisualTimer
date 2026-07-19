# Turn Timer

Turn Timer is a visual sequence timer for turns, routines, and real-world countdowns.
It keeps the one-tap visual countdown from the original app and adds editable
starter templates for common timed sessions.

## Current Scope

- **Quick timer** - Start a standalone visual countdown with the existing timer
  controls.
- **Starter templates** - Begin from Game Night, Recipe Steps, Plant Watering,
  Classroom Stations, Meeting Agenda, or a 40-minute Morning Routine.
- **Template editor** - Rename a template, edit rounds, set colors, choose
  sounds, add emoji, and decide whether a round counts as a turn.
- **Sequence playback** - Run rounds in order, repeat the sequence, skip,
  restart, or do over a turn.
- **History** - Review completed timer sessions, with recent sessions free and
  full local history, export, and iCloud sync available with Pro.
- **Turn Timer Pro** - Unlock unlimited saved templates, full history/export,
  iCloud sync, sharing, widgets, and advanced customization with a one-time
  $4.99 StoreKit purchase.
- **Shared template files** - Import and export portable `.turntimer` template
  files without overwriting existing local work.
- **Pro iCloud template sync** - Pro users can sync saved templates across their
  own devices through the private CloudKit database.
- **Pro iCloud history sync** - Pro users can sync completed session history
  across their own devices while keeping local history usable offline.
- **Template widgets** - Home Screen and Lock Screen widgets read compact App
  Group snapshots and launch starter or saved templates through `turntimer://`
  deep links.
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
- **StoreKit Pro unlock** - `turntimer.pro.unlock` is configured in
  `TurnTimer.storekit` for local testing. Free users keep starter templates and
  one custom saved template; Pro unlocks additional saved templates, full
  history/export, and template sync.
- **Portable template documents** - Saved templates live in
  `Documents/Templates/<templateID>.turntimer` as JSON. Legacy `.vtgame` files
  still load for migration, but new saves use the `.turntimer` document format.
- **iCloud sync** - `CKSyncEngine` syncs Pro template and history records in the
  private CloudKit database under container `iCloud.Dan.Visual-Timer`. Selected
  sound syncs through `NSUbiquitousKeyValueStore`.
- **Widget snapshots** - The app writes small Codable template snapshots to the
  shared App Group container `group.Dan.Visual-Timer`; widgets never read the
  app's Documents directory directly.

## Product Roadmap

Turn Timer is planned as a free timer with a $4.99 one-time Pro unlock. The
core timer, built-in starter templates, and one custom saved template remain
free. Pro value is built around reuse and portability:

- Additional saved templates.
- Full local history and history export.
- iCloud sync for saved templates.
- iCloud sync for history.
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
| Templates | `GameEditorViewModel`, `StarterTemplateLibrary`, `TemplateLibraryStore`, `TemplateDocumentCodec`, `GameFileParser` | Template editing, starter data, local save/load, import/export |
| Sync | `TemplateCloudSyncEngine`, `HistoryCloudSyncEngine`, CloudKit mappers, `UbiquitousSettingsStore` | Pro iCloud template/history sync and lightweight settings sync |
| Widgets | `WidgetSnapshotStore`, `TurnTimerDeepLink`, `TurnTimerWidgets` | App Group snapshots, widget timelines, and template launch URLs |
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

## Release Engineering - Promotion Ladder

Release flow is one-way: `feature/*` -> `nightly` -> `weekly` -> `main`.
`main` remains the GitHub default branch so scheduled workflows run from the
default-branch copy. Feature work branches from `nightly`; pull requests target
`nightly`.

| Branch | Purpose | Distribution | Merge gate | Required reviews | Promotion source |
|---|---|---|---|---:|---|
| `nightly` | Fast integration | Daily 03:00 Halifax TestFlight build to the internal `nightly` group | `Build gate + tests` | 0 | `feature/*` |
| `weekly` | Weekly beta train | Monday 09:00 Halifax TestFlight build to the external `weekly` group | `Build gate + tests` | 0 | `nightly` |
| `main` | Stable App Store release branch | App Store Connect upload and review submission on app-affecting pushes | `Build gate + tests` | 0 | `weekly` |

Hotfixes branch from `main`, merge back to `main` by pull request, then flow
back down into `weekly` and `nightly`.

Release automation runs from the default-branch workflow, then checks out the
selected train branch before building. The workflow restores the default-branch
`fastlane` configuration after checkout so signing and distribution policy stay
centralized while the app code comes from the selected train.

Distribution requires the `APP_STORE_CONNECT_API_KEY_JSON`, `MATCH_PASSWORD`,
and `MATCH_GIT_SSH_KEY` repository secrets; without them, release-train runs
compile only. App Store review submission is enabled by default for `main`; set
the `APP_STORE_SUBMIT_FOR_REVIEW` repository variable to `false` to upload
without submitting. Set `APP_STORE_AUTOMATIC_RELEASE` to `true` only when
approved builds should release automatically after App Review.

## Getting Started

1. Clone the repository.
2. Open `Visual Timer.xcodeproj` in Xcode.
3. Select an iOS simulator or connected device.
4. Build and run with Command-R.

No additional dependencies are required. The project uses only system
frameworks, including SwiftUI, Combine, AVFoundation, StoreKit, and WatchKit
support.

## CloudKit and Widget Setup

Template sync uses CloudKit container `iCloud.Dan.Visual-Timer`, custom zone
`TurnTimerTemplates`, and record type `Template`. History sync uses the same
container, custom zone `TurnTimerHistory`, and record type `HistoryRecord`.
Both sync engines are Pro-only and local-first: local templates and history must
remain usable while offline, signed out, restricted, or before CloudKit schema
deployment.

The app and widget extension share `group.Dan.Visual-Timer`. The app writes
compact `WidgetTemplateSnapshot` payloads into that App Group after starter or
saved templates change. Widgets read only those snapshots, and taps launch
`turntimer://starter/<id>` or `turntimer://template/<uuid>` deep links back into
the app.

Before shipping sync to TestFlight or the App Store, confirm the container is
enabled for the app identifier, run the app with a signed build and an iCloud
account, create or sync at least one template and one history record, then deploy
the CloudKit development schema to production in CloudKit Dashboard. Local
simulator builds verify compilation and record mapping, but they do not prove
live iCloud account, container, subscription, schema, or production-environment
behavior.

Local validation commands:

```bash
python3 -m json.tool TurnTimer.storekit >/dev/null
xcodebuild build-for-testing \
  -project 'Visual Timer.xcodeproj' \
  -scheme 'Visual Timer' \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO
xcodebuild test-without-building \
  -project 'Visual Timer.xcodeproj' \
  -scheme 'Visual Timer' \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build/DerivedData \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build \
  -project 'Visual Timer.xcodeproj' \
  -scheme 'Visual Timer' \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build \
  -project 'Visual Timer.xcodeproj' \
  -scheme 'Visual Timer Watch Watch App' \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  CODE_SIGNING_ALLOWED=NO
```

Signed-device validation checklist:

1. Unlock Pro with local StoreKit or a sandbox purchase.
2. Create one saved template and one completed history record.
3. Run `CloudKitValidationRunner.run()` from a temporary debug hook or LLDB
   expression.
4. Confirm the template probe save/fetch/delete passes.
5. Confirm template and history records appear in `TurnTimerTemplates` and
   `TurnTimerHistory`.
6. On a second signed device or simulator using the same iCloud account, confirm
   template and history records appear locally after sync.
7. Add Home Screen and Lock Screen widgets, confirm starter and saved templates
   render with the expected durations, and tap each widget to confirm the app
   opens the matching template.
