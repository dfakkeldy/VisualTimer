# Turn Timer

Visual sequence timer for turns, routines, and countdowns on iOS 18 and
watchOS, with a React web version in `web/`. Pie-chart countdowns, guarded
timer and sequence state machines, starter templates, local history, and
generated WAV sounds. `CONTRIBUTING.md` has the architecture rules and product
language; `Architecture.md` has the design.

## Commands

- iOS scheme `Visual Timer`, watch scheme `Visual Timer Watch Watch App`, in
  `Visual Timer.xcodeproj` (Swift 5 language mode).
- Web: `make web-test` (tests plus type check), `make web-build`.

## Rules

- MVVM with dumb views: view models own logic and state machines. Leaf views
  take `let` data and `() -> Void` closures, with no business logic.
- Timer state transitions (not started, running, paused, finished) are
  guarded; round-to-round, pause, and completion transitions must respect
  them.
- Colors, symbols, labels, and spacing go in `Theme.swift`, not inline.
- New sounds go through `SoundManager` / `TimerSound`.
- Saved templates are `.turntimer` JSON in `Documents/Templates/<id>.turntimer`.
  Legacy `.vtgame` files still load. Malformed files must fail gracefully.
- Pro is a one-time unlock (`turntimer.pro.unlock`; `TurnTimer.storekit`
  for local testing). Show StoreKit's localized price; never hardcode a
  fallback amount. Never gate the quick timer, built-in templates, or basic
  playback. Pro covers extra saved templates, full history and export, iCloud
  sync, sharing, widgets, and advanced customization.
- Template sync uses CloudKit container `iCloud.Dan.Visual-Timer`, zone
  `TurnTimerTemplates`, record type `Template`. Live sync needs a signed build
  and a deployed CloudKit schema.
- The Watch companion (`Dan.Visual-Timer.watchkitapp`) is embedded in the iOS
  app. Saved templates reach it through `WatchTemplateConnectivity`
  (WatchConnectivity full snapshots); App Group files alone do not cross
  devices.
- Commit messages are short and imperative: "Add template picker".

## Branches and releases

`feature/*` → `nightly` → `weekly` → `main`. Feature PRs target `nightly`;
hotfixes branch from `main` and are merged back down. `nightly` ships to
internal TestFlight, `weekly` to external TestFlight, and app changes merged
to `main` can trigger an App Store Connect upload. Submission and automatic
release are separate opt-in controls, false by default. Preparation is not
authorization to promote, upload or submit. Consult
`docs/app-store/readiness.md` for current evidence and release blockers. Signing and distribution config lives
only in the default branch's `fastlane/`; release automation uses that copy
for every train.
