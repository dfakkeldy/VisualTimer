# App Store Readiness

Re-checked: 2026-10-06 UTC. Status: **preparation in progress; submission on hold**.
Account details and tester identities belong in the private release ledger, not
this public repository.

## Current evidence

| Surface | Verified state |
|---|---|
| `nightly` | `9fac13280843ad9d9add26f87c047570c144e098` (27 Sep) |
| `weekly` | `d1896f2f4a29fb8c75a986837b7d7c65dc1eb59a` (13 Aug) |
| `main` | `0956da6e5b9b8e7c2a1b19ed0b29c694029cf866` (7 Aug) |
| Native branch CI | [36335355019](https://github.com/dfakkeldy/VisualTimer/actions/runs/36335355019): exact nightly SHA; iOS build, watchOS build and iOS tests ran successfully. Web job also passed. |
| Internal delivery | [37313869043](https://github.com/dfakkeldy/VisualTimer/actions/runs/37313869043), 5 Oct: exact nightly SHA, 75 unit tests passed; receipts confirm **1.0 (73)** uploaded, processed and distributed internally. |
| External delivery | [36469910199](https://github.com/dfakkeldy/VisualTimer/actions/runs/36469910199), 28 Sep: exact weekly SHA, 73 unit tests passed; receipts confirm **1.0 (66)** uploaded, processed and distributed externally. This is an older source payload. |
| Later runs | [37333265437](https://github.com/dfakkeldy/VisualTimer/actions/runs/37333265437) was green with ship skipped. [37367467449](https://github.com/dfakkeldy/VisualTimer/actions/runs/37367467449) and [37373007733](https://github.com/dfakkeldy/VisualTimer/actions/runs/37373007733) failed with resolver cancelled and ship skipped. These are not new uploads. |
| App Store review / live | Current App Store version, selected build, review approval, release setting and territory availability remain unverified. Beta distribution does not establish store approval. |
| Public URLs | [Support](https://dfakkeldy.github.io/VisualTimer/support.html) and [Privacy](https://dfakkeldy.github.io/VisualTimer/privacy.html) returned HTTPS 200 on 6 Oct. |
| Assets | iOS default/dark/tinted and watch icon PNGs exist. No native store screenshot set is committed; `web/docs/design/` images describe the web app. |

The project supports iPhone/iPad (iOS 18+) and embeds its widget extension.
It also has a separate watchOS 11+ target: iOS has no Watch target dependency,
its Watch embed phase is empty, and the release scheme archives only iOS.
The Watch target sets `WKWatchOnly=YES`. A separate successful Watch build does
not establish inclusion in the uploaded iOS artifact or a Watch store release. Marketing version is `1.0`; source build `1` is replaced by
Fastlane's next TestFlight number. CI pins Xcode 26.6. The project build setting
is not the uploaded build number.

Documentation head `54a806bc1c24bc6d2f63357d303a035f4db173e7` passed
[CI 37398433584](https://github.com/dfakkeldy/VisualTimer/actions/runs/37398433584)
on 6 Oct: web job and native gate passed; native logs show 75 unit tests plus
6 UI tests, zero failures. This is documentation CI, not a new upload.

## Release gates and permissions

Keep `nightly` internal testers → `weekly` external testers → `main` App Store.
All three branches currently require strict/up-to-date **Build gate + tests**,
with admin enforcement and zero required review approvals; no rulesets were
listed. Current nightly branch CI includes unit and UI test targets and fails
without a runnable iOS simulator. The default-main release workflow limits
testing to `Visual TimerTests` and can skip those tests without a simulator;
nightly workflow files differ. Inspect the actually executed workflow ref and
steps rather than assuming identical gate strength.

Release workflows execute from `main`, check out the channel's source, and
replace `.ruby-version`, `Gemfile` and `fastlane/` from the workflow-ref copy.
Record both source and automation SHA. A `main` app-path push can trigger an
upload. The `app_store` lane skips metadata/screenshots. Review submission and
automatic release are separate controls, default false; both repository
variables were false on 6 Oct. See [Fastlane](../../fastlane/README.md).

This preparation includes scoped source repairs, documentation and draft assets. Do not backport
features directly to weekly/main, promote, dispatch a release, upload, submit,
refresh signing, change protections/pipelines, set prices, or accept legal
answers/agreements without exact authorization. Documentation PRs stay drafts.

## Blockers before choosing a candidate

1. **In-app privacy link:** Settings now exposes the existing HTTPS policy URL
   (`settings.privacy-policy`). The URL returned HTTP 200 on 6 Oct. Verify the
   visible route on the selected candidate; archive/ASC privacy answers remain
   separate from link availability.
2. **Core timer reliability:** A bounded forced-suspension simulator probe
   reproduced callback-count/countdown versus Date/pie divergence. The narrow
   repair uses existing elapsed Date state for both, reconciles on pause and
   iOS activation, and completes once. It preserves one next round starting on
   return, with no catch-up loop or new background alarm behavior. A new
   deterministic pause regression failed before the repair (60 vs 20); all 80
   unit tests passed afterward. Physical manual lock/background/audio and
   current candidate UI remain acceptance checks. The separate session-history
   elapsed counter still counts callbacks; no session-time correction is claimed.
3. **Watch packaging and saved templates:** `WatchTemplateStore` writes/reads App Group
   JSON; no WatchConnectivity transfer or watch CloudKit template path was
   found. First resolve intended Watch distribution/companion configuration;
   the iOS release scheme does not currently embed that target. Local storage does not demonstrate iPhone-to-Watch delivery. Verify
   transport and paired-device behavior before promising saved-template sync.
   Quick timer/starter templates are separate paths.
   [Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity)
   describes cross-device transfers.
4. **Paid/production sync:** source implements purchase, cancellation, pending
   purchase, transaction verification and restore. The StoreKit config is
   connected to the launch scheme. ASC IAP status, Paid Apps Agreement,
   TestFlight sandbox purchase/restore, signed entitlements and production
   CloudKit schema are not proved by source or unit tests.
5. **Candidate/screenshots:** nightly has newer timer UI/tests than weekly;
   weekly has substantial app changes absent from main. Select one payload,
   clear blockers, pass native CI and internal/external acceptance, then
   capture that build. Do not describe nightly features using old main images.

The roughly 50 open RW issues are an audit backlog, not 50 verified current
blockers. Current source already normalizes imported durations/repeat counts/
palette indices; cancels final-round timers; includes timestamp reasons; maps
widget signing; and configures StoreKit testing. Reproduce critical reports on
the selected SHA. Prioritize crashes, timing, purchase/restore, data loss and
unusable layout over cosmetic work.

## Privacy and capabilities

- iOS `PrivacyInfo.xcprivacy`: tracking false, empty collected-data list,
  UserDefaults `CA92.1`, FileTimestamp `C617.1`. Synchronized target membership
  includes it in source. Verify approved reasons and the archive privacy
  report. Watch compiles shared timer/sound UserDefaults code and
  `GameRecord.swift` with FileTimestamp access; no watch-specific manifest is
  committed. Check each shipped executable's required-reason
  coverage, including Watch if it ships, rather than assuming the iOS manifest
  covers a separately built target.
- No third-party app SDK package, ads/tracking/analytics SDK or developer-run
  account flow was found in Apple source. Local templates/history and purchase
  entitlement state are stored on-device. Pro uses private CloudKit container
  `iCloud.Dan.Visual-Timer`, zones `TurnTimerTemplates` / `TurnTimerHistory`,
  types `Template` / `HistoryRecord`. Paid entitlement enables sync
  automatically; policy and privacy answers must describe actual behavior.
- iOS declares CloudKit and `group.Dan.Visual-Timer`; widget/Watch declare the
  App Group. Sound preferences use `NSUbiquitousKeyValueStore`, but its
  key-value-store entitlement is absent from the checked-in iOS file. Existing
  Oct 5 and this PR CI simulator logs explicitly warn about the missing store
  identifier. That does not establish signed-production failure. Verify
  archive/profile capability coverage; do not refresh profiles in this pass.
- No app account is created, so account deletion is not applicable to the
  current design. Local deletion/private iCloud retention still need truthful
  policy/support wording.
- Proposed privacy answers: no tracking and no developer-collected app data.
  Validate private CloudKit/support-email flows against Apple's definition
  before the owner confirms **Data Not Collected**. An empty manifest list
  does not complete the ASC questionnaire.
  [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- `ITSAppUsesNonExemptEncryption=false` is source configuration, not a legal
  determination. Apple system CloudKit/StoreKit services are used. Owner
  confirmation remains for export/territories, content rights, updated
  age/social-media questionnaire and DSA status. No declaration was submitted.

## Prepared packet and pending ASC read

[Submission packet](submission-packet.md) contains copy-ready metadata and
IAP/review notes. [Screenshot plan](../marketing/screenshot-plan.md) gives
current sizes and fixtures. [Acceptance](signed-device-smoke.md) keeps focused
release checks; no result is pre-filled.

When the owner next signs in, read current app/version/selected build, locales,
name, screenshots, IAP state/price, review contact, privacy/age/content-rights/
export answers, agreements/DSA and release settings. Resolve only consequential
choices with the owner. Helper project dates/prices are planning data, not store
configuration or authorization.

Apple currently requires Xcode 26+ / corresponding SDK 26+ for these platforms;
iOS 18 meets the current iOS 13 minimum. Inspect updated age questions and
September social-media questions in ASC.
[Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)

Continuation validation on 6 Oct ran one serial, resource-gated iOS regression
and the 80-test unit suite. Independent source review found no remaining
correctness issues after removing a duplicate test annotation. Current-head
hosted native/Watch CI and UI evidence are tracked separately. No credential,
store write, upload, promotion, submission or release occurred.
