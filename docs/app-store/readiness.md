# App Store Readiness

Last updated: 2026-07-01

This document turns the App Store pre-flight checklist into Turn Timer-specific
work. It is not proof that the app is ready; it is the current checklist for
getting there.

## Current Evidence

- Project targets: iOS 18.0 and watchOS 11.0.
- Local Xcode: 26.6.
- Xcode project Swift setting: `SWIFT_VERSION = 5.0`.
- Bundle ID: `Dan.Visual-Timer`.
- StoreKit product ID: `turntimer.pro.unlock`.
- Release policy: `nightly` internal TestFlight, `weekly` external TestFlight,
  `main` App Store Connect upload/submission.
- GitHub Pages source: `main` `/docs`.
- Latest live audit found no open PRs, but `nightly` is ahead of `main`.

## Next Ten Steps

1. Promote or backport the desired `nightly` app work so `main` represents the
   actual submission candidate.
2. Run hosted CI on the candidate branch and confirm the `Build gate + tests`
   check is green.
3. Refresh signing profiles from the release workflow if iCloud, widget, watch,
   or App Group entitlements changed.
4. Produce a processed internal TestFlight build for the `nightly` group.
5. Run signed-device smoke tests for timer playback, templates, Pro purchase,
   restore, import/export, CloudKit, widgets, watch, and failure states.
6. Deploy required CloudKit schemas to production after signed validation.
7. Publish public support and privacy-policy URLs and add the privacy policy
   link in-app.
8. Complete App Store Connect metadata, IAP metadata, age rating, export
   compliance, and privacy labels.
9. Capture final screenshots from the promoted build, validate dimensions, and
   upload assets.
10. Promote through `weekly` to `main`, run the `appstore` lane, verify build
    processing, attach the build and IAP to review, then submit.

## Pre-Flight Checklist

### Build and Signing

- [ ] Built with Xcode 26 / iOS 26 SDK or newer required by App Store policy.
- [ ] Release build tested, not only Debug simulator builds.
- [ ] `ITSAppUsesNonExemptEncryption` set in the shipping Info.plist.
- [ ] App Store provisioning profiles include iCloud and App Group entitlements
  for every shipped target.
- [ ] IPv6-only network behavior is acceptable.
- [ ] No private or undocumented API usage.

### Privacy

- [ ] `PrivacyInfo.xcprivacy` is in the app target.
- [ ] Required Reason APIs are declared with approved reason codes.
- [ ] Privacy policy URL is public and set in App Store Connect.
- [ ] Privacy policy is reachable inside the app.
- [ ] App Privacy labels match the final binary and CloudKit behavior.
- [ ] No tracking, ads, or analytics SDKs are introduced without updating docs,
  consent, and labels.

### Metadata

- [ ] App name is available and within 30 characters.
- [ ] Subtitle is within 30 characters.
- [ ] Description is accurate and under 4000 characters.
- [ ] Keywords fit the 100-byte field and avoid trademark/pricing terms.
- [ ] Category selection matches the app.
- [ ] Copyright is current.
- [ ] Support and privacy URLs work over HTTPS.
- [ ] Review notes explain Pro, iCloud, widgets, and watch behavior.

### StoreKit

- [ ] `turntimer.pro.unlock` exists in App Store Connect as a non-consumable.
- [ ] Price matches the $4.99 one-time strategy.
- [ ] Purchase, cancel, interrupted purchase, and restore flows are tested in
  StoreKit local testing and TestFlight/sandbox.
- [ ] Pro gates only reuse and portability features.

### Screenshots

- [ ] Screenshots show the actual promoted app UI.
- [ ] Required iPhone sizes are captured.
- [ ] iPad screenshots are prepared if the app is submitted as universal.
- [ ] No login screens, splash-only images, placeholder data, competitor marks,
  or price claims.
- [ ] Widget and watch visuals are used only if the promoted build proves them.

### CloudKit, Widgets, and Watch

- [ ] CloudKit container `iCloud.Dan.Visual-Timer` is enabled for the app ID.
- [ ] Development schema is deployed to production for shipping record types.
- [ ] Signed iCloud validation covers create, fetch, delete, and cross-device
  propagation.
- [ ] App Group `group.Dan.Visual-Timer` is on all relevant identifiers if
  widgets ship.
- [ ] Watch target builds and launches from the release candidate.

## Review Notes Draft

```text
Turn Timer is a visual sequence timer for turns, routines, and reusable
countdowns. The quick timer, starter templates, basic playback, recent history,
and one custom saved template are free.

Turn Timer Pro is a one-time non-consumable purchase with product ID
turntimer.pro.unlock. Pro unlocks reuse and portability features such as
additional saved templates, full history/export, iCloud sync, sharing, and
widget/watch convenience where enabled in the submitted build.

iCloud sync uses the user's private CloudKit database under container
iCloud.Dan.Visual-Timer. If widgets are included in the submitted build, they
use App Group group.Dan.Visual-Timer for compact template snapshots and open
the app for active timer playback.
```
