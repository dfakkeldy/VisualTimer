# Public Support and Privacy Page Drafts

Last updated: 2026-07-01

These are launch-page source drafts. Replace placeholders and get legal review
before publishing the privacy policy.

## Support Page Draft

```text
# Turn Timer Support

For help with Turn Timer, contact:

[CONTACT_EMAIL]

Please include:
- Your device model.
- iOS or watchOS version.
- Turn Timer app version.
- What you expected to happen.
- What happened instead.
```

### FAQ Topics

- What is Turn Timer?
- What is free?
- What does Turn Timer Pro unlock?
- How do I restore Pro?
- Why is iCloud sync not updating?
- How do widgets work, if included in the shipping build?
- Does importing overwrite existing templates?
- How do I delete local app data?

## Privacy Policy Draft Outline

```text
# Privacy Policy for Turn Timer

Effective Date: [DATE]
Last Updated: [DATE]

Developer: [DEVELOPER_NAME]
Contact: [CONTACT_EMAIL]
Website: [WEBSITE_URL]
```

Turn Timer is designed to work without accounts, ads, third-party tracking, or
third-party analytics SDKs. Timer templates, session history, settings, and
widget preferences are stored on device unless the user chooses iCloud sync
through their Apple account. In-app purchases are processed by Apple.

Data areas to describe:

- Timer duration and sound preferences.
- Saved templates: names, round names, colors, sounds, durations, repeats, and
  related settings.
- Recent/full session history, if enabled in the shipping build.
- Favorite-template/widget data, if widgets ship.
- Purchase entitlement state.
- Support request content the user chooses to send.

State clearly:

- No account is required for core app use.
- No third-party analytics SDKs are currently included.
- No advertising SDKs are currently included.
- No cross-app tracking is currently included.
- Location, contacts, camera, photos, microphone, HealthKit, and motion data are
  not currently accessed.
- Templates can be intentionally exported or shared as `.turntimer` files.

Retention draft:

- Local templates and history remain on device until deleted by the user or the
  app is deleted.
- iCloud-synced data remains in the user's private iCloud database according to
  Apple iCloud behavior and settings.
- Support messages are retained only as long as reasonably needed to respond and
  manage support.

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

Do not publish this as final policy text until placeholders are replaced and
the app's final data practices are verified.
