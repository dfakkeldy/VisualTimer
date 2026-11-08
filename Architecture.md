# Turn Timer architecture

Last audited: 2026-10-24. Session restore, template drafts, and iPhone
completion alerts (PR #138, merged 2026-11-08) are reflected below. The
public App Store 1.0 listing sentence was updated 2026-11-08; other
sections were not re-audited.

Turn Timer has SwiftUI apps for iOS 18+ and watchOS 11+, a WidgetKit extension,
and a local-first React web app. The Xcode project uses Swift 5 language mode
and Xcode 26 settings. Keep platform and language changes separate from
unrelated work.

## Branches and delivered code

Ordinary changes branch from and target `nightly`, then follow
`nightly` → `weekly` → `main`. `main` is the GitHub default branch and serves
GitHub Pages from `docs/`. The October 17 promotion included the web app,
history sync, widgets, and embedded Watch companion. These are implemented
architecture, rather than future work. Implementation, a signed upload, and
physical-device behavior remain separate evidence. Public App Store 1.0 listing
is recorded in the [readiness ledger](docs/app-store/readiness.md) as of
2026-11-08.

The [readiness ledger](docs/app-store/readiness.md) holds dated delivery
receipts and remaining release checks. [Website maintenance](docs/website.md)
explains the static site and committed web build.

## Product model

The quick timer, built-in starters, one custom saved template, and recent
history are free on Apple platforms. Turn Timer Pro is a one-time StoreKit
non-consumable, `turntimer.pro.unlock`, for unlimited saved templates, full
history/export, iCloud sync, sharing, widgets, and advanced customization.
The app displays StoreKit's localized price.

The browser app has no purchase gate or Apple entitlement emulation. Templates,
preferences, and history stay in browser storage. `.turntimer` files are its
portability boundary.

## Apple app layers

| Layer | Main types | Responsibility |
|---|---|---|
| Timer | `TimerViewModel`, `TimerState`, `TimerVisualProgress`, `QuickTimerStore`, `TimerAlertScheduler` | Guarded countdown transitions, timestamp-derived remaining time and pie progress, sleep prevention, quick-timer restore, opt-in iPhone completion alerts |
| Sound | `TimerSound`, `SoundManager` | Audio session and synthesized WAV tones |
| Sequence | `GameViewModel`, `GameSequence`, `Round`, `ActiveSessionStore` | Ordered rounds, repeats, skip, restart, do-over, turn progress, in-progress session restore |
| Templates | `GameEditorViewModel`, `StarterTemplateLibrary`, `TemplateLibraryStore`, `TemplateDocumentCodec`, `GameFileParser` | Editing, built-ins, persistence, import/export, legacy reads, unsaved editor draft |
| History | `HistoryViewModel`, `GameRecord`, `SessionEvent` | Local session storage, review, export; `GameRecord.roundColors` is optional |
| iCloud | `TemplateCloudSyncEngine`, `HistoryCloudSyncEngine`, record mappers, `UbiquitousSettingsStore` | Pro private-database sync and sound preferences |
| Pro | `ProAccessViewModel`, `ProFeature`, access policies | Verified StoreKit entitlement, purchase/restore, feature gates |
| Widgets | `WidgetSnapshotStore`, `TurnTimerDeepLink`, `TurnTimerWidgets` | App Group snapshots, timelines, template launch URLs |
| Watch | `WatchTemplateConnectivity`, `WatchTemplateStore`, `WatchTimerAlertCoordinator` | Paired-template delivery, local snapshots, completion alerts |
| Presentation | `MainTabView`, `GamePlaybackView`, `GameEditorView`, `TimerComponents`, `TimerVisualView`, leaf controls | Declarative UI, shared glass controls and time captions, observation, action callbacks |
| Theme | `Theme` | Shared labels, symbols, colors, spacing, animation values |

View models and storage/parser helpers own business logic. Leaf views receive
values and callbacks. Keep CloudKit, StoreKit, file parsing, and state-machine
rules out of leaf SwiftUI views. Feature containers may observe their owners.

Countdowns reconcile from elapsed dates on pause and activation. A sequence
starts its next round on return rather than catching up through several missed
rounds. The separate session elapsed counter has different behavior; do not
infer background-alarm delivery from countdown reconciliation. iPhone can
schedule one opt-in local notification for the running countdown's finish date
(`TimerAlertScheduler`); that is not a guaranteed background alarm.

The unused `ContentView` entry point is gone; `Visual_TimerApp` hosts
`MainTabView`. `TimerVisualView` remains the iPhone dial.

## Documents and sync

Apple templates are JSON at
`Documents/Templates/<templateID>.turntimer`. Legacy `.vtgame` files still load.
Imports assign a new local identity and conflict-safe title instead of
replacing an existing document. The web codec uses the same portable shape.

In-progress iPhone state uses small Codable JSON files in Application Support
(tests may inject another directory):

| File | Owner | Restored when |
|---|---|---|
| `ActiveSession.json` | `ActiveSessionStore` / `GameViewModel` | A playing session after an app close. Snapshots older than four hours come back paused at the saved round. Malformed files are discarded. |
| `QuickTimer.json` | `QuickTimerStore` | A running or paused quick timer. Snapshots older than four hours, or malformed files, are discarded. |
| `TemplateDraft.json` | `GameEditorViewModel` | Unsaved template edits. Malformed drafts are discarded. |

These files stay on the device. They are not CloudKit records and are not
widget snapshots. Watch playback still lives in `WatchAppModel` memory: leaving
a Watch screen does not stop a countdown, but terminating the Watch app does
not restore it.

The private CloudKit container is `iCloud.Dan.Visual-Timer`:

| Data | Zone | Record type |
|---|---|---|
| Saved templates | `TurnTimerTemplates` | `Template` |
| Completed history | `TurnTimerHistory` | `HistoryRecord` |

`MainTabView` enables both sync engines when Pro is unlocked. Local editing,
playback, and history remain usable offline or without iCloud. Sound
preferences use `NSUbiquitousKeyValueStore`. Source configuration does not
prove production schema or signed-account behavior.

## Widgets and Watch

Widgets read compact snapshots from App Group `group.Dan.Visual-Timer`, not
Documents. Their links use `turntimer://starter/<id>` and
`turntimer://template/<uuid>`; the main app routes them into existing owners.

The iPhone app embeds companion `Dan.Visual-Timer.watchkitapp`.
`WatchTemplateConnectivity` sends full saved-template snapshots using
WatchConnectivity application context and file transfers. App Group files alone
do not cross devices. Revision ordering and atomic writes reject stale data;
revoking Pro clears Watch templates without deleting the iPhone library.

Watch quick timer and starter playback are separate paths. Foreground
completion uses sound and haptics; permitted local notifications cover
completion off screen. No extended runtime or guaranteed background execution
is implemented. See the dated [Watch quality plan](docs/watch-quality-plan.md).

## Web and public website

`web/src/domain` owns pure transitions and template parsing.
`useTurnTimerController` orchestrates templates, history, and timer actions;
`usePersistentState` owns versioned local storage. React views receive state and
callbacks. The browser timer derives remaining time from timestamps.

Vite builds the installable client into `web/dist/`, or committed `docs/app/`
with `make web-pages`. `web/public/sw.js` caches the application shell. Apple
StoreKit, CloudKit, widgets, and Watch integrations remain native features.

The public homepage, support, privacy, 404, and devlog pages are plain HTML with
shared `docs/assets/site.css`. Weekly devlog automation replaces only marked
blocks in the HTML and Markdown pair. See [web documentation](web/README.md)
and [website maintenance](docs/website.md).

## Release engineering and verification

Release workflows execute from the default branch, check out the selected train,
and restore that workflow ref's Fastlane config. Signing reads bundle identifiers
from the train's Xcode project. Schedules compare effective app inputs with the
last successful delivery and skip unchanged binaries. Documentation changes do
not imply a new app upload. See [release delivery](.github/RELEASE_DELIVERY.md).

Native CI builds iOS and Watch targets, runs iOS tests and a focused Watch UI
test, and checks release controls. Web CI runs tests, TypeScript checks, and a
production build. Follow [contributor validation](CONTRIBUTING.md#testing) for
the affected area; use the Mac build-slot wrapper for local Apple commands.

The app has no developer-run accounts, advertising, or analytics SDKs. Each
Apple executable has a privacy manifest. Manifest presence, archive reports,
App Store questionnaire answers, and live service behavior need their own
evidence; the [privacy page](docs/privacy.html) describes the data paths.
