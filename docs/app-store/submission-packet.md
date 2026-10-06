# Turn Timer Submission Packet

Prepared: 2026-10-06 UTC. **Draft only: do not upload or submit.**
[Readiness](readiness.md) records evidence and blockers. Files in
[submission-draft/en-CA](submission-draft/en-CA/) contain copy-ready text outside
`fastlane/metadata/` and automation. Packet approval does not authorize pricing,
legal declarations or release.

## Listing fields

| Field | Prepared value / pending evidence |
|---|---|
| Name | Turn Timer; locked product name. Confirm current ASC name/locale availability. |
| Subtitle | Visual rounds & routines |
| Category | Productivity proposal; source category is Utilities. Read ASC before choosing. |
| Platforms | iPhone/iPad with embedded widget. Separate Watch source target is not embedded by the current iOS release scheme; verify intended distribution/archive before including it in the listing. No native Mac target. |
| Locale | en-CA draft; historical en-CA/fallback notes need current ASC verification before creating en-US or asserting a name conflict. |
| Version | Source `1.0`; choose exact candidate/build after ladder gates. |
| Support | https://dfakkeldy.github.io/VisualTimer/support.html — HTTPS 200 on 6 Oct. |
| Privacy | https://dfakkeldy.github.io/VisualTimer/privacy.html — HTTPS 200 on 6 Oct. |
| Marketing | https://dfakkeldy.github.io/VisualTimer/ |
| Copyright | `2026 Dan Fakkeldy` proposal; confirm owner/legal text. |
| Review contact | Reuse verified ASC contact; private phone/contact fields remain unverified and must not be committed. |
| Login | No developer-run account/demo credentials for free use. iCloud uses the reviewer's Apple account. |
| Images | [Capture manifest](../marketing/screenshot-plan.md) ready; native images not yet captured from a selected candidate. |

Description covers implemented quick timer, six starters, editable sequences,
history and Pro reuse. iCloud template/history claims require production
acceptance. Saved iPhone-to-Watch sync/background alarms are not promised. Copy
does not remove or disable features. What's New is prepared only if the version
field applies; it omits developer documentation/release automation as features.

## In-app purchase

- Product `turntimer.pro.unlock`, source type **non-consumable**.
- Name `Turn Timer Pro` (14 characters); description draft:
  `Unlimited templates, history export, sharing.`
- No subscription group, renewal or trial configured in source.
- Source/local test price is `$4.99`, not proof of the ASC storefront price.
  Planning sources disagree. Inspect real price schedule and obtain one exact
  owner decision only if a change is needed. Do not set offers/prices here.
- Read product state, localization, availability, review screenshot, first-IAP
  version attachment and Paid Apps Agreement. Local `.storekit` does not
  establish these. Capture real paywall/unlocked-state review screenshot and
  record TestFlight purchase/cancel/pending/restore results. Settings and Pro
  sheet have Restore Purchases in source.

## Review notes

Prepared `submission-draft/en-CA/review_notes.txt` contains no credentials or
private fields. Reconcile with accepted candidate before using it. Never claim
schema deployment, physical-device success or unsupported behavior from code.

## Questionnaire worksheet: owner confirmation pending

| Topic | Source evidence | Pending |
|---|---|---|
| Privacy | No ads/tracking/analytics SDK found; local templates/history, Pro private CloudKit, Apple StoreKit. | Match actual flows/archive report to privacy answers. Data Not Collected is a proposal, not a filed declaration. |
| Manifest | iOS has UserDefaults `CA92.1` / FileTimestamp `C617.1`. | Check reasons and each executable's bundled coverage, Watch if submitted. |
| Accounts | No account creation; local data/Apple-managed iCloud. | Confirm deletion/retention wording, including automatic Pro sync. App-account deletion is not applicable to current design. |
| Age/content | Generic editable local rounds/starters; no social feed, messaging or public discovery found. | Complete current age/social-media questions; do not invent a numeric age rating. |
| Rights | PNG/SVG icon source; sounds synthesized in code; starters local. | Owner confirms rights to all app/store materials. Avoid clinical/licensed-game claims. |
| Export | Source non-exempt encryption flag false; Apple system services used. | Owner confirms exact encryption/territory answers/documents. |
| Account/legal | Current state not established by repo. | Read agreement/DSA/regional fields; owner handles declarations/agreements. |
| Accessibility | Current nightly CI includes UI tests; default-main release workflow limits tests to unit target. | Verify layouts/VoiceOver before claiming supported accessibility in ASC. |
| Review/release | Main upload skips metadata/images; submit/auto-release controls default false. | Read live status/release setting; preserve hold; obtain explicit promotion/upload/submission authorization. |

Re-checked against official [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/),
[screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications),
[privacy details](https://developer.apple.com/app-store/app-privacy-details/) and
[review guidelines](https://developer.apple.com/app-store/review/guidelines/).
Private account details and declarations stay outside this public repo.
