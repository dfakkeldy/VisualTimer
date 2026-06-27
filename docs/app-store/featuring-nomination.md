# App Store Featuring Nomination

Status: Draft nomination
Nomination Type: Major update / launch positioning

## Submission Links and Placeholders

Submit through Apple's app promotion contact flow:

```text
https://developer.apple.com/contact/app-store/promote/
```

Replace before submission:

| Field | Value |
|---|---|
| Contact first name | `[FIRST_NAME]` |
| Contact last name | `[LAST_NAME]` |
| Contact email | `[APPLE_DEVELOPER_EMAIL]` |
| Apple Developer Team ID | `[TEAM_ID]` |
| App Store URL or TestFlight link | `[APP_STORE_OR_TESTFLIGHT_URL]` |
| Support/press URL | `[PRESS_KIT_URL]` |

## App Information

| Field | Value |
|---|---|
| App Name | Turn Timer |
| Developer | `[DEVELOPER_NAME]` |
| Category | Productivity |
| Platforms | iOS and watchOS |
| Price Model | Free with one-time Pro unlock |

## Desired Featuring Window

Recommended timing:

```text
6 to 8 weeks after the App Store build is submitted or approved, aligned with the Turn Timer launch update.
```

Seasonal alternates:

- Back-to-school: classroom stations and timed presentations.
- Holiday/family season: game night fairness and family routines.
- Spring: plant watering and household routines.
- WWDC/new OS season: Apple-native widgets, AppIntents, watchOS, and SwiftUI.

## App Overview

Turn Timer makes time visible for real-world sequences: game turns, recipe
steps, classroom stations, meeting speakers, plant watering zones, and household
routines. Instead of starting from a generic countdown every time, users build
colorful reusable rounds and run them again with one tap.

The app is intentionally Apple-native and privacy-conscious: SwiftUI interface,
StoreKit 2 Pro unlock, private iCloud template sync, WidgetKit quick starts,
AppIntents, App Groups, and a lightweight watchOS companion.

## Why Now

Turn Timer has evolved from a simple visual timer into a reusable visual time
management tool. The launch update adds the product identity, starter templates,
Pro unlock, shared template files, iCloud template sync, favorite-template
widgets, and watch alignment needed for a broader App Store release.

## What Makes This App Special

- It solves a specific, familiar problem first: fair, visible turns for game
  night.
- It expands naturally into routines without becoming a generic alarm app.
- Templates make repeated real-world countdowns faster to start.
- Widgets and watchOS make favorite timers available from Apple surfaces.
- The current implementation avoids third-party tracking, advertising, and
  analytics SDKs.
- The visual timer is accessible at a glance for groups, classrooms, families,
  and meetings.

## Apple Technology Integration

| Technology | How Turn Timer Uses It |
|---|---|
| SwiftUI | Main iOS and watchOS interface, declarative timer/editor/history flows, Dynamic Type-aware system components |
| StoreKit 2 | One-time non-consumable Turn Timer Pro unlock and restore flow |
| CloudKit | Pro template sync through the user's private iCloud database |
| WidgetKit | Home Screen and Lock Screen favorite-template quick starts |
| AppIntents | Widget actions write pending start/open-template requests and launch the app |
| App Groups | Shared compact favorite-template snapshots between the iOS app and widget extension |
| watchOS | Watch-local starter templates and a crown-adjustable countdown |
| AVFoundation | Programmatic timer completion sounds generated in-app |

## Editorial Angle

Turn Timer is about accessible, shared time management. Many timers are built
for one person staring at a number. Turn Timer makes the sequence itself visible:
who is up, what comes next, how much time remains, and what routine can be
reused tomorrow.

That makes it useful for families around a table, teachers running stations,
workshops with timed speakers, cooks managing repeated recipe steps, and anyone
who benefits from seeing time as a colorful sequence rather than a bare alarm.

## Developer Story

`[DEVELOPER_STORY]`

Suggested angle:

Turn Timer began as a small visual timer and grew into a more deliberate product
after identifying a practical gap: popular visual timers are polished, but they
often make repeated multi-step countdowns slower than they should be. This update
focuses on the everyday moment when someone needs to start the right countdown
again, quickly, without rebuilding it.

## Accessibility and Inclusion

Current accessibility points to verify before submission:

- Large, high-contrast visual countdown.
- Named rounds instead of color-only identification.
- System SwiftUI controls that can inherit Dynamic Type behavior.
- Button labels and accessibility labels for icon-only controls.
- Reduced reliance on audio alone because the visual countdown carries core
  state.

Before nomination, run an accessibility pass on the final screenshot build and
document VoiceOver labels, Dynamic Type behavior, and color contrast.

## Privacy Commitment

Turn Timer does not use third-party tracking, advertising, or analytics SDKs in
the current implementation. Templates and history stay on device unless a Pro
user uses private iCloud template sync through Apple's CloudKit service.

## Media Kit

Prepare:

- App Store screenshots from `docs/app-store/screenshot-plan.md`.
- 15 to 30 second App Preview video.
- App icon at required marketing sizes.
- Short developer story or launch blog post.
- Support and privacy policy URLs.
- TestFlight link if the app is pre-launch.

## Submission Pitch

```text
Turn Timer makes time visible for real-world sequences: game turns, recipe steps, classroom stations, meeting speakers, plant watering zones, and household routines. This launch update turns a simple visual timer into an Apple-native reusable countdown tool with starter templates, shared Turn Timer files, private iCloud template sync, favorite-template widgets, and a lightweight watchOS companion.

The app's strongest wedge is game night fairness: everyone can see whose turn is active, what comes next, and how much time remains. From there, the same colorful round model helps teachers rotate stations, cooks reuse recipe timers, teams keep agendas honest, and families run everyday routines without rebuilding timers from scratch.

Turn Timer is built with SwiftUI, StoreKit 2, WidgetKit, AppIntents, App Groups, CloudKit, and watchOS, and it avoids third-party tracking, ads, and analytics SDKs. We would love it to be considered for a feature around accessible, Apple-native visual time management for groups, routines, and everyday life.
```

## Pre-Submission Checklist

- [ ] Final App Store name and URL are available.
- [ ] Latest build is approved or ready for TestFlight.
- [ ] Screenshots and optional App Preview video are final.
- [ ] Privacy policy and support URLs are public.
- [ ] StoreKit product is configured in App Store Connect.
- [ ] CloudKit schema is deployed to production.
- [ ] Widget and watch builds have been smoke-tested.
- [ ] Accessibility audit is complete.
- [ ] Press kit URL is public.
