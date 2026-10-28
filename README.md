# Turn Timer

Turn Timer is a visual sequence timer for turns, routines, and real-world countdowns.
It keeps the one-tap visual countdown from the original app and adds editable
starter templates for common timed sessions.

## Status

Documentation audited 2026-10-24. The [browser timer](https://dfakkeldy.github.io/VisualTimer/app/)
is live and installable. The Apple app includes the quick timer, sequences,
Pro, CloudKit sync, widgets, and embedded Watch companion in source promoted
through `weekly` to `main` on October 17. Main upload **1.0 (77)** succeeded;
current App Review and public App Store availability have not been rechecked.
See the [readiness ledger](docs/app-store/readiness.md) for dated receipts and
remaining verification, and [Roadmap](Roadmap.md) for the current priorities.

Useful docs:

- [Architecture](Architecture.md)
- [Roadmap](Roadmap.md)
- [App Store readiness](docs/app-store/readiness.md)
- [Fastlane release docs](fastlane/README.md)
- [Public devlog](docs/guides/devlog.md)
- [Website and documentation maintenance](docs/website.md)

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
  StoreKit purchase. The app shows StoreKit's localized price and has no
  hardcoded fallback amount; the local `TurnTimer.storekit` value is for
  simulation and does not verify the App Store Connect price.
- **Shared template files** - Import and export portable `.turntimer` template
  files without overwriting existing local work.
- **Pro iCloud template sync** - Pro users can sync saved templates across their
  own devices through the private CloudKit database.
- **Pro iCloud history sync** - Pro users can sync completed session history
  across their own devices while keeping local history usable offline.
- **Template widgets** - Home Screen and Lock Screen widgets read compact App
  Group snapshots and launch starter or saved templates through `turntimer://`
  deep links.
- **Watch app** - The iPhone app embeds its Watch companion
  (`Dan.Visual-Timer.watchkitapp`) with quick timer and starter playback. Pro
  saved templates are sent to the paired Watch as full snapshots through
  WatchConnectivity; revoking Pro clears Watch templates without deleting the
  iPhone library. Signed TestFlight now includes the Watch companion; physical
  paired-Watch acceptance is not yet verified. Watch timers show live remaining
  time and keep running while you move between screens. On screen, a finished
  timer plays the selected sound with a haptic.
  If you allow alerts, a local notification covers completion while the app
  is off screen ([plan](docs/watch-quality-plan.md)). None of this has been
  tested on a physical Watch.
- **Installable web app** - Run the same core timer, starter templates,
  `.turntimer` import/export, and local history in a responsive React PWA.

These scope bullets describe implemented source, not signed-device acceptance
or App Store live state. Production sync, saved Watch-template transfer and
timer lock/background behavior still need the focused checks in the readiness
ledger. No background-alarm guarantee is implied.

## Core Features

- **Visual pie countdown** - A circular timer depletes clockwise from the
  12 o'clock position using SwiftUI drawing and animation. The iOS dial adds
  glasslike lighting and a completion ripple while preserving the quick timer's
  colour cycle and each round's chosen colour. Controls use Liquid Glass on
  iOS 26+, with material fallbacks on iOS 18 and accessibility alternatives for
  reduced motion, reduced transparency, and increased contrast.
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

## Product direction

The quick timer, six starters, and one custom saved template are free on Apple
platforms. Pro is a one-time purchase for reuse and portability, including
unlimited saved templates, history/export, iCloud sync, sharing, widgets, and
advanced customization. The app displays StoreKit's localized price. The web
client stores its data in the browser and has no StoreKit purchase gate.

See [Roadmap](Roadmap.md) for implemented features and remaining work.

## Architecture

The app follows an MVVM architecture with small SwiftUI views and centralized
state owners.

See [Architecture](Architecture.md) for the full architecture map, branch
status, data formats, sync boundaries, and release-engineering notes.

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
| Web client | `web/src` | React UI, browser timer state machine, local persistence, and compatible template documents |

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
| `nightly` | Fast integration | Daily 03:00 Halifax check; TestFlight to the internal `nightly` group only when app inputs changed | `Build gate + tests` | 0 | `feature/*` |
| `weekly` | Weekly beta train | Monday 09:00 Halifax check; TestFlight to the external `weekly` group only when app inputs changed | `Build gate + tests` | 0 | `nightly` |
| `main` | Stable App Store release branch | App Store Connect upload on app-affecting pushes; review only when explicitly enabled | `Build gate + tests` | 0 | `weekly` |

Hotfixes branch from `main`, merge back to `main` by pull request, then flow
back down into `weekly` and `nightly`.

Release automation runs from the default-branch workflow, then checks out the
selected train branch before building. The workflow restores the default-branch
`fastlane` configuration after checkout so signing and distribution policy stay
centralized while the app code comes from the selected train.

Scheduled trains still check on that daily and Monday cadence. They compare
effective app build inputs with the last successful platform/channel delivery
and skip the macOS build and upload when those inputs are unchanged.
Documentation-only edits do not create a new binary. Dispatch the workflow with
`force=true` for an intentional rebuild through the same gates. The scheduler
runs the controller from the default branch, so this skip behavior takes effect
only after promotion to `main`. See
[change-aware release delivery](.github/RELEASE_DELIVERY.md).

Distribution requires the `APP_STORE_CONNECT_API_KEY_JSON`, `MATCH_PASSWORD`,
and `MATCH_GIT_SSH_KEY` repository secrets; without them, release-train runs
compile only. App Store runs upload without review submission by default. Set
the `APP_STORE_SUBMIT_FOR_REVIEW` repository variable to `true` only when the
build should be submitted, and set `APP_STORE_AUTOMATIC_RELEASE` to `true` only
when approved builds should release automatically after App Review.

Fastlane lane behavior and local validation are documented in
[fastlane/README.md](fastlane/README.md).

## GitHub Pages and Devlog

The public website is served from `main` at `docs/`. The site root is
`docs/index.html`, and the build-in-public devlog lives at
`docs/devlog.html`. Weekly devlog automation opens a PR against `main`; it does
not publish social posts automatically.

The installable [web app](https://dfakkeldy.github.io/VisualTimer/app/) is live
at `/VisualTimer/app/`. Its source is `web/`; `make web-pages` regenerates the
committed `docs/app/` package. Pages serves the copy on `main`. Ordinary docs
and website changes target `nightly` and reach the live site after the normal
promotion ladder. See [website maintenance](docs/website.md).

## Getting Started

### Apple apps

1. Clone the repository.
2. Open `Visual Timer.xcodeproj` in Xcode.
3. Select an iOS simulator or connected device.
4. Build and run with Command-R.

No additional dependencies are required. The project uses only system
frameworks, including SwiftUI, Combine, AVFoundation, StoreKit, and WatchKit
support.

### Web app

The web client requires Node.js 22 or newer:

```bash
cd web
npm ci
npm run dev
```

Run its complete local gate with:

```bash
cd web
npm test
npm run check
npm run build
```

The browser client is local-first. Templates, preferences, and history remain
in browser storage; `.turntimer` import/export is the portability boundary.
StoreKit, CloudKit, widgets, and watch features remain Apple-platform features.
See [`web/README.md`](web/README.md) for the web architecture and support
details.

`make web-pages` rebuilds only `docs/app/`; it leaves the homepage, devlog,
support, and privacy routes intact. Commit a regenerated package when changing
the web client so the source and deployed assets stay together.

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

## License

Turn Timer's source code is released under the [MIT License](LICENSE).
Dependencies keep their own licences.
