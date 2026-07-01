# Turn Timer Architecture

Last updated: 2026-07-01

Turn Timer is an Apple-platform Swift app for visual sequence timers. The
project currently targets iOS 18.0 and watchOS 11.0, uses Xcode 26 project
settings, and keeps `SWIFT_VERSION = 5.0` in the Xcode project. Do not raise
platform support or change the Swift language mode as part of unrelated work.

## Branch Truth

`main` is the deployable GitHub Pages and App Store release branch. `nightly`
is ahead of `main` with staged app work, including widget, watch, history-sync,
and release-validation changes. Docs on `main` should say when a feature is
staged instead of implying it is already in the App Store branch.

## Product Model

The app keeps the original visual countdown and extends it into reusable
sequences:

- Quick timer remains free.
- Starter templates remain free.
- One custom saved template remains free.
- Turn Timer Pro is a one-time non-consumable unlock with product ID
  `turntimer.pro.unlock`.
- Pro gates reuse and portability: additional saved templates, full
  history/export, iCloud sync, sharing, widgets, and advanced customization.

## App Layers

| Layer | Main files | Responsibility |
|---|---|---|
| Timer core | `TimerViewModel`, `TimerState`, `TimerSound`, `SoundManager` | Countdown state, audio session behavior, generated WAV tones, sleep prevention |
| Sequence core | `GameViewModel`, `GameSequence`, `Round` | Ordered rounds, repeats, skip/restart/do-over, turn progress |
| Templates | `GameEditorViewModel`, `StarterTemplateLibrary`, `TemplateLibraryStore`, `TemplateDocumentCodec`, `GameFileParser` | Starter data, editing, save/load, import/export, legacy migration |
| History | `HistoryViewModel`, `GameRecord`, `SessionEvent`, `SessionDetailView` | Completed session storage, review, and Pro-gated export |
| Sync | `TemplateCloudSyncEngine`, `TemplateCloudRecordMapper`, `UbiquitousSettingsStore` | Pro template sync and lightweight iCloud setting sync |
| Monetization | `ProAccessViewModel`, `ProProduct`, `ProFeature`, `HistoryAccessPolicy`, `TemplateSavePolicy` | StoreKit state and Pro feature boundaries |
| Views | `MainTabView`, `ContentView`, `GamePlaybackView`, `GameEditorView`, `HistoryView`, leaf components | SwiftUI presentation and user interactions |
| Theme | `Theme` | Shared labels, symbols, colors, dimensions, and animation constants |

Staged on `nightly`: `HistoryCloudSyncEngine`, widget snapshot/deep-link types,
the WidgetKit extension, and fuller watch template playback. Promote those
branches before treating them as `main` architecture.

## View Model Boundary

The codebase is MVVM with deliberately small SwiftUI views:

- View models own timer, sequence, template, history, StoreKit, and sync logic.
- Leaf views receive values through `let` properties and send actions through
  closures.
- Views should not parse files, talk to CloudKit, run StoreKit purchase logic,
  own timers, or enforce Pro access rules directly.

This keeps timer and sequence state testable and prevents UI edits from
accidentally weakening guarded state transitions.

## Data Formats

Saved templates use `.turntimer` JSON documents in:

```text
Documents/Templates/<templateID>.turntimer
```

Legacy `.vtgame` files may still load for migration. New saves should use
`TemplateLibraryStore` and `TemplateDocumentCodec`. Imports duplicate templates
with a new local ID and conflict-safe title instead of editing a shared file in
place.

## iCloud

Current `main` supports Pro template sync:

- Container: `iCloud.Dan.Visual-Timer`
- Zone: `TurnTimerTemplates`
- Record type: `Template`

The app must stay local-first. Template editing and recent history should remain
usable while offline, signed out, restricted, or before the CloudKit production
schema is deployed.

Staged on `nightly`: history sync using zone `TurnTimerHistory` and record type
`HistoryRecord`.

## Widgets and Watch

Widget and watch expansion is staged on `nightly`:

- App Group: `group.Dan.Visual-Timer`
- Widgets read compact snapshots, not the app's Documents directory.
- Widget taps route through `turntimer://starter/<id>` or
  `turntimer://template/<uuid>`.
- Watch playback is being aligned around starter/saved template sources.

Promote and smoke-test the widget/watch branch before moving these features into
App Store screenshots or production metadata.

## Privacy and Compliance

Current code has `PrivacyInfo.xcprivacy` and no third-party analytics, ads, or
tracking SDKs. App Store readiness still needs:

- A public privacy policy URL.
- An in-app privacy policy link.
- App Privacy labels matching the final shipping binary.
- `ITSAppUsesNonExemptEncryption = NO` in the shipping Info.plist if the app
  only uses Apple-provided HTTPS/iCloud/StoreKit encryption.

See `docs/app-store/readiness.md` for the submission checklist.

## Release Engineering

Promotion is one-way:

```text
feature/* -> nightly -> weekly -> main
```

`main` remains the default branch because scheduled workflows run from the
default-branch workflow file. Release automation checks out the selected train
branch, then restores default-branch Fastlane files so signing and distribution
policy stay centralized.

Distribution policy:

- `nightly`: internal TestFlight group named `nightly`.
- `weekly`: external TestFlight group named `weekly`.
- `main`: App Store Connect upload and review submission unless disabled by
  repository variables.

## Validation

Use these checks for doc or release readiness changes:

```bash
make doc-automation-test
python3 -m json.tool TurnTimer.storekit >/dev/null
```

Use the README's Xcode build commands for app, watch, sync, or widget changes.
Local simulator builds do not prove live iCloud account state, production
CloudKit schema, TestFlight distribution, or App Store review readiness.
