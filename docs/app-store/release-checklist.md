# Turn Timer App Store Release Checklist

Date: 2026-06-27
Status: Draft launch checklist

## App Store Connect Metadata

- [ ] Confirm final App Store name availability.
- [ ] Set subtitle to `Visual rounds & routines` unless final search work
  suggests a better option.
- [ ] Add promotional text from `docs/app-store/app-store-copy.md`.
- [ ] Add full description from `docs/app-store/app-store-copy.md`.
- [ ] Add What's New text for the Turn Timer launch update.
- [ ] Choose primary category, likely Productivity.
- [ ] Fill the keyword field after final name/subtitle are chosen.
- [ ] Add support URL.
- [ ] Add privacy policy URL.
- [ ] Add marketing URL if a public page exists.

## Pricing and Pro Unlock

- [ ] Confirm the app is free to download.
- [ ] Confirm the non-consumable product exists in App Store Connect:

```text
turntimer.pro.unlock
```

- [ ] Set the intended one-time Pro price tier to match the $4.99 strategy.
- [ ] Add localized display name and description for the product.
- [ ] Test purchase, restore, interrupted purchase, and cancelled purchase in
  StoreKit local testing.
- [ ] Test purchase and restore through TestFlight/App Store sandbox before
  release.

## Privacy

- [ ] Publish `docs/app-store/privacy-policy.md` at a public URL.
- [ ] Replace `[DEVELOPER_NAME]`, `[CONTACT_EMAIL]`, and `[WEBSITE_URL]`.
- [ ] Confirm the App Privacy questionnaire reflects the final build.
- [ ] Confirm there is no third-party analytics, ads, or tracking SDK in the
  shipping binary.
- [ ] Confirm `PrivacyInfo.xcprivacy` declares UserDefaults access and no
  collected data unless the final privacy label requires otherwise.
- [ ] Re-check privacy labels if analytics, crash reporting, accounts, push
  notifications, or a backend are added later.

## iCloud and App Groups

- [ ] Confirm CloudKit container is enabled:

```text
iCloud.Dan.Visual-Timer
```

- [ ] Confirm CloudKit custom zone and record type:

```text
Zone: TurnTimerTemplates
Record type: Template
```

- [ ] Run a signed build with an iCloud account and create or sync at least one
  template.
- [ ] Deploy the CloudKit development schema to production in CloudKit
  Dashboard before App Store release.
- [ ] Confirm the App Group exists on all relevant identifiers:

```text
group.Dan.Visual-Timer
```

- [ ] Confirm provisioning profiles include the iCloud and App Group
  entitlements.

## Screenshots and App Preview

- [ ] Capture iPhone 6.7 inch screenshots.
- [ ] Capture iPhone 6.5 inch screenshots.
- [ ] Capture iPhone 5.5 inch screenshots.
- [ ] Use the default five-screenshot sequence from
  `docs/app-store/screenshot-plan.md`.
- [ ] Verify screenshot captions are under eight words.
- [ ] Avoid price text in screenshots.
- [ ] Optional: create a 15 to 30 second App Preview after screenshots are final.

## TestFlight Smoke Test

- [ ] Fresh install starts at a useful timer/template flow.
- [ ] Quick timer starts, pauses, resumes, and resets.
- [ ] Game Night starter template starts without editing.
- [ ] A custom template can be created, saved, reopened, and run.
- [ ] Free user is blocked only when attempting a second custom saved template.
- [ ] Pro purchase unlocks unlimited saved templates.
- [ ] Restore Purchases restores Pro access.
- [ ] Template import duplicates without overwriting local work.
- [ ] Template export produces a `.turntimer` file.
- [ ] History appears after a completed session.
- [ ] Full history export is Pro-gated.
- [ ] Favorite template widget opens the app and starts the template.
- [ ] Empty widget state opens Templates.
- [ ] Watch app launches and runs a watch-local countdown.
- [ ] Review prompt does not appear on first launch or first completed session.

## Accessibility and Quality

- [ ] VoiceOver reads timer controls, template controls, and widget actions
  clearly.
- [ ] Dynamic Type does not clip critical controls.
- [ ] Color is not the only signal for round identity.
- [ ] Reduced Motion does not block comprehension of timer progress.
- [ ] App handles no network/iCloud signed-out conditions gracefully.
- [ ] No launch-blocking paywall.
- [ ] No crash when CloudKit is unavailable.

## Build Verification

Run before PR merge and before release candidate tagging:

```sh
git diff --check
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer Watch Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
xcodebuild build -project 'Visual Timer.xcodeproj' -target 'Visual TimerTests' -configuration Debug -sdk iphonesimulator
```

Known project issue:

- `Visual_TimerTests` is not currently included in the app scheme/test plan, so
  a direct scheme test command is expected to fail until the scheme is updated.

## App Review Notes

Use this as a starting point:

```text
Turn Timer is a visual sequence timer for turns, routines, and reusable countdowns. The quick timer, starter templates, basic playback, recent history, and one custom saved template are free.

Turn Timer Pro is a one-time non-consumable purchase with product ID turntimer.pro.unlock. Pro unlocks unlimited saved templates, full history export, iCloud template sync, sharing/import/export workflows, and favorite-template widgets.

iCloud template sync uses the user's private CloudKit database under container iCloud.Dan.Visual-Timer. Widgets use App Group group.Dan.Visual-Timer for compact favorite-template snapshots and pending start requests. Widgets do not run a background live timer; tapping Start opens the app and starts the selected template.
```

## Post-Launch

- [ ] Watch App Store conversion rate.
- [ ] Watch free-to-Pro conversion rate.
- [ ] Monitor review sentiment around setup, price, widgets, and sync.
- [ ] Defer Product Page Optimization until there is enough traffic to measure.
- [ ] Defer Custom Product Pages until there are audience-specific campaigns.
- [ ] Consider In-App Events for a future template-pack release or major Pro
  update.
