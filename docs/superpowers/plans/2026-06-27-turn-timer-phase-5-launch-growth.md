# Turn Timer Phase 5: Launch and Growth

Date: 2026-06-27
Branch: codex/turn-timer-phase5
Base: codex/turn-timer-phase4
Status: Implementation plan

## Goal

Turn the current Turn Timer product into a launch-ready App Store package. This
phase creates the App Store copy, screenshot direction, support/legal pages,
featuring nomination draft, release checklist, and a respectful in-app review
prompt triggered after successful repeated use.

## Context

- Product positioning is Turn Timer: a visual sequence timer for turns,
  routines, and reusable countdowns.
- Monetization is a free app with a $4.99 one-time Pro unlock.
- Pro currently unlocks unlimited saved templates, full history/export, iCloud
  template sync, sharing/import/export, and favorite-template widgets.
- The app uses only Apple frameworks. Current privacy posture is intentionally
  simple: no third-party analytics SDK, ads SDK, tracking SDK, accounts,
  location, contacts, camera, photos, or health data access.
- Data stored by the app includes local timer/template/history data, optional
  iCloud private database template sync for Pro users, StoreKit purchase state
  handled by Apple, and App Group widget snapshots.

## Non-Goals

- Do not add analytics, advertising, attribution, push notifications, or a
  backend in this phase.
- Do not build Product Page Optimization tests yet. PPO needs enough traffic to
  measure.
- Do not build Custom Product Pages yet. Those should wait for campaigns,
  paid traffic, or audience-specific landing pages.
- Do not add In-App Events yet. Reconsider for a major template-pack release or
  larger Pro update.
- Do not change deployment targets, Swift language version, or the current
  free/Pro feature split.

## Deliverables

### 1. App Store Copy

Create `docs/app-store/app-store-copy.md` with:

- Final product naming guidance.
- Recommended subtitle: `Visual rounds & routines`.
- Promotional text.
- Full description.
- What is new copy for the Turn Timer launch update.
- Keyword field candidates and notes.
- App Store category recommendation.

Acceptance criteria:

- Copy leads with game night and turn fairness, then expands to routines.
- Copy does not mention competitor names or unstable price text in fields where
  Apple discourages it.
- Copy describes Pro as convenience and reuse, not as a blocked timer.

### 2. Screenshot Plan

Create `docs/app-store/screenshot-plan.md` with:

- Default five-screenshot sequence:
  1. Game night fairness.
  2. Visual round sequence.
  3. Reusable templates.
  4. Pro reuse, sharing, sync, and widgets.
  5. Watch/widget support.
- Captions under eight words.
- Capture notes for iPhone and optional watch/widget composites.
- Secondary campaign sets for cooking, classrooms, meetings, and plant watering
  when traffic justifies Custom Product Pages.

Acceptance criteria:

- The first two screenshots communicate the product's wedge without relying on
  generic timer language.
- Captions match the planned visuals exactly.
- Secondary sets are planned but clearly marked as later campaign material.

### 3. Legal and Support Pages

Create:

- `docs/app-store/privacy-policy.md`
- `docs/app-store/support.md`
- `docs/app-store/release-checklist.md`

Acceptance criteria:

- Privacy policy is a tailored starter document with placeholders for the
  developer name, support email, and public URL.
- Privacy policy states no third-party tracking, ads, or analytics SDKs are used.
- Privacy policy maps App Store Connect privacy label answers for the current
  implementation.
- Support page covers Pro purchase/restore, iCloud template sync, widgets, watch
  behavior, sharing/import/export, and common troubleshooting.
- Release checklist includes App Groups, CloudKit production schema, StoreKit
  product review, privacy URLs, screenshot capture, and TestFlight smoke tests.

### 4. Featuring Nomination

Create `docs/app-store/featuring-nomination.md` with:

- Major update nomination framing.
- Apple technology table covering SwiftUI, StoreKit 2, CloudKit, WidgetKit,
  AppIntents, App Groups, and watchOS.
- Editorial angle centered on accessible, Apple-native visual time management.
- Media kit and submission readiness checklist.

Acceptance criteria:

- Pitch answers why Turn Timer is worth featuring now.
- Pitch focuses on user benefit first and Apple technology second.
- Placeholder fields are obvious and easy to replace before submission.

### 5. Review Prompt

Add a small testable review prompt controller and trigger it from the app only
after a successful repeated-use moment.

Implementation outline:

- Add `ReviewPromptController` in the iOS app target.
- Persist prompt state in `UserDefaults`.
- Record a completed session when the sequence enters `gameOver`.
- Request review only after at least two completed sessions and only once per
  install/state lifetime.
- Use SwiftUI's `requestReview` environment action from `MainTabView`.

Acceptance criteria:

- The app never requests a review on first launch or first completed session.
- The app attempts a review only after a completed sequence, not during active
  timing, editing, purchase, sync, or error flows.
- Unit tests cover first completion, second completion, and once-only behavior.

## Verification

Run:

```sh
git diff --check
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer Watch Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
xcodebuild build -project 'Visual Timer.xcodeproj' -target 'Visual TimerTests' -configuration Debug -sdk iphonesimulator
```

Known limitation:

- The current app scheme does not include `Visual_TimerTests`, so direct
  `xcodebuild test -scheme 'Visual Timer' -only-testing:Visual_TimerTests` is
  expected to fail until the scheme/test plan is updated.

## Release Readiness Notes

- Host privacy and support pages at public URLs before App Review submission.
- Confirm App Store product name availability before setting the final listing.
- Test Pro purchase and restore through App Store Connect/TestFlight, not only
  the local StoreKit file.
- Verify CloudKit template sync with a signed build and deploy the CloudKit
  development schema to production before release.
