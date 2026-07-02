# Turn Timer Signed-Device Smoke Checklist

Date: 2026-07-02
Status: Ready for TestFlight handoff

Use this checklist after a signed TestFlight build is available. Leave every
result checkbox empty until Dan completes the step on real hardware.

## Prerequisites

- [ ] Install the latest TestFlight build on at least one iPhone signed in to
  Dan's Apple ID, iCloud account, and StoreKit sandbox tester account.
- [ ] Install the same TestFlight build on a second signed device using the
  same iCloud account before running cross-device sync checks.
- [ ] Pair and install the watch app on an Apple Watch before running watch
  playback checks.
- [ ] Deploy the CloudKit development schema to production in CloudKit
  Dashboard before running the live-container probe or cross-device sync checks.
  Container: `iCloud.Dan.Visual-Timer`. Zones: `TurnTimerTemplates` and
  `TurnTimerHistory`.

## TestFlight Install

- [ ] Open TestFlight and install the current Turn Timer build.
- [ ] Launch Turn Timer from the Home Screen, not from Xcode.
- [ ] Confirm the app opens to a usable timer or template flow after a fresh
  install.
- [ ] Confirm Settings shows the expected Pro state before any sandbox purchase
  is attempted.

## StoreKit Sandbox

Deferred until the IAP exists in App Store Connect (Week 2 ASC pack); re-run
then.

- [ ] Confirm App Store Connect contains the non-consumable IAP
  `turntimer.pro.unlock`.
- [ ] Sign in to the device with a StoreKit sandbox tester account.
- [ ] Start the purchase flow for `turntimer.pro.unlock` from the TestFlight
  build.
- [ ] Complete the sandbox purchase and confirm Pro access is unlocked.
- [ ] Delete or reinstall the app, then use Restore Purchases.
- [ ] Confirm restore re-enables Pro access without requiring a second purchase.

## CloudKit Live Container

- [ ] Confirm the CloudKit production schema has been deployed for
  `iCloud.Dan.Visual-Timer`.
- [ ] Run `CloudKitValidationRunner.run()` from a temporary debug hook or LLDB
  expression against the signed TestFlight installation.
- [ ] Confirm the probe can save, fetch, and delete a template test record in
  `TurnTimerTemplates`.
- [ ] Confirm the probe can access the history resources for
  `TurnTimerHistory`.
- [ ] Confirm no CloudKit permission, zone, entitlement, or production-schema
  errors are reported.

## Cross-Device Sync

- [ ] On device A, create a custom saved template.
- [ ] On device A, run the template long enough to create a completed history
  record.
- [ ] On device B, launch Turn Timer with the same iCloud account.
- [ ] Confirm the saved template created on device A appears on device B.
- [ ] Confirm the completed history record from device A appears on device B.
- [ ] On device B, make a small template edit and confirm the update returns to
  device A.

## Widget Deep Links

- [ ] Add a Home Screen widget for a starter template.
- [ ] Tap the widget and confirm Turn Timer opens the matching starter template
  through a `turntimer://starter/<id>` deep link.
- [ ] Add a Home Screen widget for a saved template.
- [ ] Tap the widget and confirm Turn Timer opens the matching saved template
  through a `turntimer://template/<uuid>` deep link.
- [ ] Add a Lock Screen widget for a template.
- [ ] Tap the Lock Screen widget and confirm it opens the same template in Turn
  Timer.

## Watch App

- [ ] Install and launch the Turn Timer watch app from the paired Apple Watch.
- [ ] Confirm the watch app opens without requiring the iPhone app to be
  foregrounded.
- [ ] Select a starter template and start playback on the watch.
- [ ] Select a saved template synced from the iPhone and start playback on the
  watch.
- [ ] Confirm pause, resume, and reset work during watch template playback.
