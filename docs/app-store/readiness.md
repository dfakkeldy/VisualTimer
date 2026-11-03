# App Store Readiness

Documentation audit: 2026-10-24. The table below preserves the October 17
release receipts, with the historical main upload checked October 20. Main
upload **1.0 (77)** succeeded. Current App Review, selected-build, and public
App Store state were not rechecked in this documentation pass. The earlier
"submission on hold" wording described an old preparation session, not a live
store status.

Current source checkpoint: `nightly` `0599f744d4a3ff36aed183c66c8b2fa300dafa4a`
and `main` `8aeab7eb5cabc38b0f61c517a69f467786fa62bd`. Nightly
[CI 39504562374](https://github.com/dfakkeldy/VisualTimer/actions/runs/39504562374)
passed. The public homepage, browser app, support, and privacy routes returned
HTTPS 200 on October 24. Pages serves `main:/docs`; a Nightly documentation
merge alone does not publish new website content.

Account details and tester identities belong in the private release ledger,
not this public repository. This ledger records evidence and remaining release
work; it does not authorize a promotion or store action.

## Dated release evidence

| Surface | Verified state |
|---|---|
| `nightly` | `c253fec98aefbf70a69b4914fc8f73f21715dbde` (17 Oct, PR #117) |
| `weekly` | `a6f18e7ccdc4a799c73f80dfa2ea42c286c0fd3a` (17 Oct, [PR #113](https://github.com/dfakkeldy/VisualTimer/pull/113) merge) |
| `main` | `95c9fe87b5b764bc21a309eee866410d50312831` (17 Oct, [PR #114](https://github.com/dfakkeldy/VisualTimer/pull/114) merge of Weekly `a6f18e7ccdc4a799c73f80dfa2ea42c286c0fd3a`) |
| Native CI | [39053772715](https://github.com/dfakkeldy/VisualTimer/actions/runs/39053772715): exact #114 head `f4b626663d82d04dee5f5a9dbc7e4c65e62cc889`. Web job passed. Native gate passed: 115 unit tests, 6 iOS UI tests, Watch control test with five fresh cycles, release-control checks. |
| Internal delivery | [39052587053](https://github.com/dfakkeldy/VisualTimer/actions/runs/39052587053), 17 Oct: source `c253fec98aefbf70a69b4914fc8f73f21715dbde`, 115 unit tests; receipts confirm **1.0 (75)** uploaded, processed and distributed internally. Match installed `match AppStore Dan.Visual-Timer.watchkitapp`. |
| External delivery | [39053761895](https://github.com/dfakkeldy/VisualTimer/actions/runs/39053761895), 17 Oct: source `a6f18e7ccdc4a799c73f80dfa2ea42c286c0fd3a`, 115 unit tests; receipts confirm **1.0 (76)** uploaded, processed and distributed to External testers at 17:39 UTC. Same Watch App Store profile installed. |
| Main upload | [39055266912](https://github.com/dfakkeldy/VisualTimer/actions/runs/39055266912/job/117461910375) completed successfully after #114: **1.0 (77)** uploaded on 17 Oct at 18:05:26 UTC. `submit_for_review=false` and `automatic_release=false`. This historical upload does not establish a current selected build, App Review decision, public release or physical-device acceptance. |
| App Store review / live | Current App Store version, selected build, review approval, release setting and territory availability remain unverified. Beta distribution does not establish store approval. The 17 Oct nightly and weekly jobs ran with `APP_STORE_SUBMIT_FOR_REVIEW=false` and `APP_STORE_AUTOMATIC_RELEASE=false`. Public release stays manual. |
| Public URLs | [Support](https://dfakkeldy.github.io/VisualTimer/support.html) and [Privacy](https://dfakkeldy.github.io/VisualTimer/privacy.html) returned HTTPS 200 on 17 Oct. |
| Assets | iOS default/dark/tinted and watch icon PNGs exist. No native store screenshot set is committed; `web/docs/design/` images describe the web app. |

The project supports iPhone/iPad (iOS 18+) and embeds its widget extension.
Since PR #103 it also embeds the watchOS 11+ companion: iOS depends on the
Watch target, the Embed Watch Content phase copies it, and the Watch app uses
`Dan.Visual-Timer.watchkitapp` with `WKWatchOnly=NO` and
`WKCompanionAppBundleIdentifier=Dan.Visual-Timer`. Signed TestFlight 1.0 (75)
and 1.0 (76) used that matching Watch App Store profile. Physical paired-Watch
hardware acceptance is still unverified. Marketing version is `1.0`; source
build `1` is replaced by Fastlane's next TestFlight number. CI pins Xcode 26.6.
The project build setting is not the uploaded build number.

## Release gates and permissions

Keep `nightly` internal testers → `weekly` external testers → `main` App Store.
Protection metadata checked October 20 requires **Build gate + tests** on all
three branches, with admin enforcement and zero required review approvals.
Weekly and Main require an up-to-date base; Nightly does not. Recheck the current
rules before each promotion. Nightly branch CI includes unit and UI test targets and fails
without a runnable iOS simulator. The default-main release workflow limits
testing to `Visual TimerTests` and can skip those tests without a simulator;
nightly workflow files differ. Inspect the actually executed workflow ref and
steps rather than assuming identical gate strength.

Release workflows execute from `main`, check out the channel's source, and
replace `.ruby-version`, `Gemfile` and `fastlane/` from the workflow-ref copy.
Record both source and automation SHA. A `main` app-path push can trigger an
upload. The `app_store` lane skips metadata/screenshots. Review submission and
automatic release are separate controls, default false. The 17 Oct nightly and
weekly delivery jobs ran with both flags false. Live repository variable values
were not re-read after the #114 merge. See [Fastlane](../../fastlane/README.md).

Ordinary documentation and website maintenance targets `nightly` in a ready
PR after relevant validation. Promotions, release dispatches, uploads,
submissions, signing changes, prices, and legal declarations need their own
authorization. Do not treat historical preparation holds as a requirement to
keep ordinary maintenance PRs in draft.

## Candidate-specific verification still requiring evidence

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
   current candidate UI remain acceptance checks. The separate displayed session
   elapsed counter still counts callbacks; no session-time correction is claimed.
3. **Watch packaging and saved templates:** PR #103 embeds the companion and
   adds `WatchTemplateConnectivity`, which sends full template snapshots over
   WatchConnectivity (application context plus file transfer) with atomic
   writes, revision ordering, latest-state retry and legacy reads. Revoking Pro
   clears Watch templates without deleting the iPhone library. Unit tests cover
   the transfer payloads; signed paired-device delivery is unverified. Verify
   it on hardware before promising saved-template sync.
   Quick timer/starter templates are separate paths. The Watch timer source
   repairs the fixed Quick Timer digits and its silent completion. On screen,
   completion now plays the selected sound with a haptic. Off-screen completion
   uses a permission-gated local notification that is cancelled or rescheduled
   on pause, resume, reset and end. There is no extended runtime and no
   guaranteed background execution ([plan](../watch-quality-plan.md)). Physical
   Watch acceptance of notifications, sound, haptics and Always On is pending.
   [Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity)
   describes cross-device transfers.
4. **Paid/production sync:** source implements purchase, cancellation, pending
   purchase, transaction verification and restore. The StoreKit config is
   connected to the launch scheme. ASC IAP status, Paid Apps Agreement,
   TestFlight sandbox purchase/restore, signed entitlements and production
   CloudKit schema are not proved by source or unit tests.
5. **Candidate/screenshots:** nightly, weekly and main now share the 17 Oct
   promoted payload (PRs #113 and #114). Select one SHA, clear remaining
   blockers, then capture that build. Do not describe current features using
   old August main images.

The June issue audit closed the old bug backlog after checking the fixing
PRs against source and hosted CI. As of October 24, the repository has no open
issues; open engineering PRs remain separate from that count. Use the live
[issues](https://github.com/dfakkeldy/VisualTimer/issues) and
[pull requests](https://github.com/dfakkeldy/VisualTimer/pulls) instead of the
old "roughly 50 open RW issues" count. New reports still require reproduction
on the selected SHA.

## Privacy and capabilities

- iOS, Watch, and widget each have their own `PrivacyInfo.xcprivacy`. All three
  declare tracking false and an empty collected-data list. iOS and Watch declare
  UserDefaults `CA92.1` and FileTimestamp `C617.1`. The widget declares
  UserDefaults `CA92.1`. Verify the archive privacy report and that each shipped
  bundle contains its manifest. A signed archive or upload has not proven that
  yet.
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

## Historical packet and future store reconciliation

[Submission packet](submission-packet.md) retains the October 6 metadata and
IAP/review drafts. Its unchecked fields describe preparation at that date and
are not a current list of missing store configuration. [Screenshot plan](../marketing/screenshot-plan.md) gives
current sizes and fixtures. [Acceptance](signed-device-smoke.md) keeps focused
release checks; no result is pre-filled.

When the owner next signs in, read current app/version/selected build, locales,
name, screenshots, IAP state/price, review contact, privacy/age/content-rights/
export answers, agreements/DSA and release settings. Resolve only consequential
choices with the owner. Helper project dates/prices are planning data, not store
configuration or authorization.

The October 6 requirements review referenced Xcode/SDK 26 and updated age
questions. Recheck the current requirements and questionnaire for a future
submission rather than treating that dated review as current policy.
[Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)

Continuation validation on 6 Oct ran one serial, resource-gated iOS regression
and the 80-test unit suite. Independent source review found no remaining
correctness issues after removing a duplicate test annotation. Current-head
hosted native/Watch CI and UI evidence are tracked separately. No credential,
store write, upload, promotion, submission or release occurred.

Exact repair-head hosted [CI 37410738760](https://github.com/dfakkeldy/VisualTimer/actions/runs/37410738760)
completed successfully: 80 unit tests, six UI tests, ten web tests and Watch
compilation. Local regression failed before the repair and the complete local
80-test unit suite passed afterward. These results do not establish physical
background alarm delivery or paired Watch-template transport.
