# Turn Timer Roadmap

Last updated: 2026-07-01

This roadmap tracks the path from the current Turn Timer rebrand to App Store
submission. It separates what is merged to `main`, what is staged on `nightly`,
and what still needs product or App Store work.

## Release Posture

`main` is the deployable website and App Store release branch. `nightly` is
ahead with app work that should be promoted through `weekly` before release.
There were no open GitHub PRs at the latest audit on 2026-07-01.

## Completed on Main

- Turn Timer product language and starter-template model.
- Free quick timer, starter templates, one custom saved template, and recent
  history.
- StoreKit non-consumable Pro unlock wiring for `turntimer.pro.unlock`.
- Template import/export using `.turntimer` documents.
- Pro template sync architecture using CloudKit container
  `iCloud.Dan.Visual-Timer`.
- Release-train workflow for `nightly`, `weekly`, and `main`.
- Basic GitHub Pages devlog from `main` `/docs`.

## Staged on Nightly

- Pro history sync and CloudKit validation helpers.
- Widget snapshots, App Group wiring, and template deep links.
- Watch template playback refinements.
- Shared Xcode scheme and fail-hard CI gate updates.
- Fastlane signing target updates for widget and watch identifiers.
- Echo-style devlog review body generation.

These need promotion or selective backporting before they are described as
shipping production behavior.

## App Store Next Ten Steps

1. Promote or deliberately backport the `nightly` app stack so `main`,
   `weekly`, and docs agree on the shipping code.
2. Run the CI build gate on the promoted branch and keep the hosted check green.
3. Dispatch `Release Trains` for `nightly` with
   `refresh_signing_profiles=true` to regenerate iCloud/App Group capable App
   Store profiles when needed.
4. Confirm a processed internal TestFlight build reaches the `nightly` tester
   group.
5. Complete signed-device validation: Pro purchase/restore, template sync,
   history behavior, widget taps, watch launch, and offline/iCloud-signed-out
   flows.
6. Deploy CloudKit development schema to production for every shipping record
   type and zone.
7. Publish support and privacy-policy pages, then add the privacy-policy link
   inside the app.
8. Configure App Store Connect metadata: app name, subtitle, description,
   keywords, category, age rating, privacy labels, support URL, privacy URL,
   copyright, review notes, and Pro IAP metadata.
9. Capture final screenshots from the promoted build and validate required
   device sizes before uploading.
10. Promote `weekly` to `main`, run the `appstore` release train, verify build
    processing in App Store Connect, attach IAP/review metadata, and submit.

## V1 Readiness Gates

- No placeholder App Store metadata.
- No root 404 on the GitHub Pages site.
- `PrivacyInfo.xcprivacy` matches the final binary.
- `ITSAppUsesNonExemptEncryption` is set correctly.
- StoreKit product exists in App Store Connect and restore works.
- Screenshots show the actual promoted app UI.
- Review notes explain Pro, iCloud, widgets, and watch limitations honestly.
- The branch/worktree cleanup ledger has no unsaved launch assets.

## After V1

- Automated App Store metadata upload through checked-in Fastlane metadata.
- Screenshot automation once fixtures and capture flows are stable.
- Custom Product Pages for game night, classroom, cooking, meetings, and plant
  watering.
- App Preview video after screenshots are stable.
- Product Page Optimization only after enough traffic exists to measure.
