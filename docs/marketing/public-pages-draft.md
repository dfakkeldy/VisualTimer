# Public Support and Privacy Pages

Re-checked: 2026-10-06 UTC

Both URLs below returned HTTPS 200 on 6 Oct. They are existing public contacts;
a domain/email migration is not a launch prerequisite. In-app privacy-policy
access is missing in current source and remains a release blocker. The policy
says sync is chosen by the user, while Pro entitlement enables sync automatically
in source: reconcile that wording before final privacy confirmation. No public
policy change or legal attestation is made by this audit.

- Support URL: `https://dfakkeldy.github.io/VisualTimer/support.html`
- Privacy Policy URL: `https://dfakkeldy.github.io/VisualTimer/privacy.html`
- Developer: Kinnoki Labs
- Contact: `dfakkeldy@gmail.com`
- Website: `https://dfakkeldy.github.io/VisualTimer/`

## Support Page Summary

The public support page asks users to email `dfakkeldy@gmail.com` with device,
OS, app version, expected behavior, and actual behavior. It covers:

- What Turn Timer is.
- What is free.
- What Turn Timer Pro unlocks.
- Restore Purchases.
- iCloud sync troubleshooting, only if the installed build includes sync.
- Import safety for `.turntimer` files.
- Local and iCloud data deletion guidance.

## Privacy Policy Summary

The public privacy page states that Turn Timer is designed to work without
developer-run accounts, ads, tracking, or analytics SDKs. It says:

- Kinnoki Labs does not collect timer templates, session history, device
  analytics, advertising identifiers, or tracking data from Turn Timer.
- Timer settings, saved templates, local session history, and purchase
  entitlement state are stored by the app on device.
- If an installed build includes iCloud sync and the user chooses to use it,
  supported templates or history are stored in the user's private iCloud
  database through Apple's CloudKit service.
- Kinnoki Labs does not operate a separate account server for this sync and
  cannot read the contents of the user's private iCloud database.
- Apple processes App Store purchases through StoreKit.
- Support email receives only the email address and message content the user
  chooses to send.

## App Store Privacy Label Notes

Confirm the final App Store Connect questionnaire against the final binary. The
current intended posture is:

- Tracking: no.
- Third-party advertising: no.
- Third-party analytics SDKs: no.
- Accounts: no app account required.
- Payment information: processed by Apple, not collected by the developer.
- User content: templates/history may be stored locally and, for Pro sync, in
  the user's private iCloud database for app functionality.

Suggested label: Data Not Collected, because the developer does not receive
templates, history, analytics, advertising identifiers, or tracking data from
the app, and private CloudKit data is stored in the user's Apple account.
Verify this in App Store Connect before confirming the questionnaire.
