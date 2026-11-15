# Turn Timer v1.1 screenshots

The candidate is nightly `3febb3a`, captured with the existing
`Visual TimerUITests/DesignCouncilCaptureTests.swift`. There is no Fastlane
snapshot lane, Snapfile or device matrix in this repository. No release lane
is used for capture. Screenshots are drafts until matched to Dan's selected
1.1 submission binary.

## Capture matrix

- iPhone 17, iOS 27.2, portrait, English/Canada, 1206 × 2622.
- iPad Pro 13-inch (M5), iOS 27.2, portrait, English/Canada, 2064 × 2752.
- Watch: no watchOS simulator runtime on this mini. Capture and inspect a
  consistent Watch size on a machine with a runtime or paired device before
  submission. The Watch app is embedded; the old empty-embed-phase note is
  obsolete.

The test fixture seeds generic family-game and routine data in a temporary
folder. It renders actual native views; it does not add debug labels or draw
fake UI. Keep only visually inspected screens without clipping, overlays or
misleading sample data. The Pro sheet uses local StoreKit prices and is not
part of the customer screenshot set.

## Reproduce with project commands

Build once with the README's simulator `build-for-testing` command, then run
`test-without-building` sequentially for each device above. Set
`TEST_RUNNER_DESIGN_COUNCIL_OUT` to an absolute output directory. Select the
existing capture tests with `-only-testing:Visual\ TimerUITests/DesignCouncilCaptureTests`.
For a focused set select `test01TimerReady`, `test02TimerPaused`,
`test04SessionRoutine`, `test06Templates`, `test08History`,
`test10SessionDetail`, and `test13RoutineStopwatch` individually. Keep the
result bundle for failure evidence.

Use `CODE_SIGNING_ALLOWED=NO`, `-parallel-testing-enabled NO`, and
`-maximum-concurrent-test-simulator-destinations 1`. On the rented mini, check
the dispatcher capacity report and active xcodebuild process count before each
run. This session uses one Apple build/test at a time. Do not run archive,
deliver, pilot or any upload lane.

## Capture receipt

See [v1.1 preparation](../app-store/v1.1-preparation.md) for actual results,
remaining acceptance work and the committed image manifest. Version settings
remain 1.0 (1), as release configuration changes were excluded from this task.
No images have been uploaded to Apple.

Device categories and alpha requirements were checked against
[Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
on 2026-11-15. Confirm acceptance in the selected App Store Connect version;
this preparation does not access that account.
