# Privacy Policy for Turn Timer

Effective Date: June 27, 2026
Last Updated: June 27, 2026

This is a starter privacy policy for the Turn Timer App Store release. Replace
the placeholders below with the developer's legal name, contact email, and
public website before publishing. This document is not legal advice.

Developer: `[DEVELOPER_NAME]`
Contact: `[CONTACT_EMAIL]`
Website: `[WEBSITE_URL]`

## Overview

Turn Timer is a visual sequence timer for turns, routines, and reusable
countdowns. The app is designed to work without accounts, ads, third-party
tracking, or third-party analytics SDKs.

Your timer templates, session history, settings, and widget preferences are
stored on your device unless you use iCloud template sync through your Apple
account. In-app purchases are processed by Apple through the App Store.

## Information We Collect

### Information Stored On Your Device

Turn Timer stores the information needed to run the app's core features:

- Timer duration and sound preferences.
- Saved templates, including template names, round names, colors, sounds,
  durations, repeat counts, and related template settings.
- Recent and full local session history, including template/session names,
  round names, timestamps, and timer events.
- Favorite-template information used to update widgets.
- Purchase entitlement state needed to unlock Turn Timer Pro features.

This information is stored locally on your device.

### iCloud Template Sync

If you unlock Turn Timer Pro and enable iCloud template sync, saved templates may
sync through Apple's iCloud service using your private CloudKit database. iCloud
sync helps keep templates available across your own Apple devices signed into the
same Apple account.

Turn Timer does not operate its own user-account server for this sync. Apple's
iCloud terms and privacy practices apply to iCloud storage and transport.

### App Store Purchases

Turn Timer Pro purchases are processed by Apple through StoreKit and the App
Store. The developer does not receive your full payment card details.

### Support Requests

If you contact support by email or another support channel, we may receive the
contact information and message content you choose to provide. Support requests
are used only to respond to you and resolve the issue you reported.

## Information We Do Not Collect

Turn Timer does not currently:

- Require an account.
- Use third-party analytics SDKs.
- Use advertising SDKs.
- Track you across apps or websites.
- Access location, contacts, camera, photos, microphone, HealthKit, or motion
  data.
- Sell, rent, or trade personal information.

## How We Use Information

Information stored by Turn Timer is used to:

- Run visual timers and reusable countdown sequences.
- Save, import, export, and sync templates.
- Show local session history.
- Restore and maintain Turn Timer Pro access.
- Update widgets with compact favorite-template snapshots.
- Respond to support requests that you send.

We do not use Turn Timer data to build advertising profiles or track you across
other apps and websites.

## Sharing

We do not sell your information.

Information may be shared only in these limited cases:

- With Apple services that you choose to use, such as iCloud sync and App Store
  purchases.
- When you intentionally export or share a `.turntimer` template file.
- If required by law, regulation, legal process, or a lawful government request.
- To respond to a support request that you initiated.

## Data Retention

- Local templates and history remain on your device until you delete them or
  delete the app.
- iCloud-synced templates remain in your private iCloud database according to
  Apple's iCloud behavior and your iCloud settings.
- Support messages are retained only as long as reasonably needed to answer and
  manage support.

## Your Choices

You can:

- Delete templates in the app.
- Delete local app data by deleting the app from your device.
- Disable or manage iCloud for the app through Apple system settings.
- Contact support at `[CONTACT_EMAIL]` for questions about support messages or
  privacy.

## Children's Privacy

Turn Timer is not directed to children under 13. We do not knowingly collect
personal information from children under 13. If you believe a child has provided
personal information through a support request, contact us at
`[CONTACT_EMAIL]`.

## Security

Turn Timer relies on Apple platform security for local device storage, iCloud,
StoreKit, and App Group storage. No method of storage or transmission is
perfectly secure, but the app is designed to minimize the data handled outside
your device.

## Changes

We may update this Privacy Policy when the app's features or data practices
change. The updated version will be posted at `[WEBSITE_URL]` and the "Last
Updated" date will be revised.

## Contact

For privacy questions, contact:

- Email: `[CONTACT_EMAIL]`
- Developer: `[DEVELOPER_NAME]`
- Website: `[WEBSITE_URL]`

## App Store Connect Privacy Label Mapping

Use this as a working checklist before App Store submission. Confirm the final
answers in App Store Connect and update them whenever app data practices change.

Current implementation summary:

| Area | Suggested App Store Connect Answer |
|---|---|
| Tracking | No |
| Third-party advertising | No |
| Developer advertising or marketing data use | No |
| Third-party analytics SDKs | No |
| Accounts | No account required |
| Payment information | Not collected by developer; purchases are processed by Apple |
| Location, contacts, camera, photos, microphone, health | Not collected |
| Diagnostics collected by developer | None currently implemented |
| User content | Saved timer templates and history may be stored locally; Pro template sync may store template content in the user's private iCloud database for app functionality |
| Purchases | StoreKit handles purchase entitlement; confirm whether App Store Connect requires purchase history disclosure for the final implementation |

Important release note:

Apple's privacy questionnaire depends on what data the developer and integrated
third parties can access. Turn Timer's CloudKit template sync stores user-created
template content in the user's private iCloud database for app functionality.
Confirm the final App Store Connect label with the Apple Developer account's
current form and legal guidance before submission.
