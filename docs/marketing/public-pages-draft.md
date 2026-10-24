# Public Support and Privacy Pages

Documentation audit: 2026-10-24. The support, privacy, homepage, and browser-app
routes return HTTPS 200. The proposed site changes are maintained in `docs/`
and reach Pages after promotion to `main`. Settings includes the privacy-policy
link. The policy now describes automatic Pro template/history sync and browser
storage. This note describes source and public URLs, not App Store privacy
questionnaire confirmation.

- Support URL: `https://dfakkeldy.github.io/VisualTimer/support.html`
- Privacy Policy URL: `https://dfakkeldy.github.io/VisualTimer/privacy.html`
- Developer: Kinnoki Labs
- Contact: `dfakkeldy@gmail.com`
- Website: `https://dfakkeldy.github.io/VisualTimer/`

## Support page summary

The public support page asks users to email `dfakkeldy@gmail.com` with device,
OS, app version, expected behavior, and actual behavior. It covers:

- What Turn Timer is.
- What is free.
- What Turn Timer Pro unlocks.
- Restore Purchases.
- iCloud sync troubleshooting, for the Apple app with Pro.
- Import safety for `.turntimer` files.
- Local and iCloud data deletion guidance.

## Privacy policy summary

The public privacy page states that Turn Timer is designed to work without
developer-run accounts, ads, tracking, or analytics SDKs. It says:

- Kinnoki Labs does not collect timer templates, session history, device
  analytics, advertising identifiers, or tracking data from Turn Timer.
- Timer settings, saved templates, local session history, and purchase
  entitlement state are stored by the app on device.
- When Pro unlocks sync and iCloud is available,
  saved templates and history are stored in the user's private iCloud
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
