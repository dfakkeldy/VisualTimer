# Fastlane Release Docs

Re-checked: 2026-10-06 UTC

Fastlane owns Turn Timer's archive, signing-profile sync, TestFlight upload, and
App Store upload lanes. App Store copy is prepared outside automation in
`docs/app-store/submission-draft/en-CA/`. The app-store lane skips metadata and
screenshots, so a binary upload does not apply those drafts.

## Local Tooling

The repo pins Ruby through `.ruby-version`. If the local shell cannot find that
Ruby, use the rbenv shims first:

```bash
PATH="$HOME/.rbenv/shims:$PATH" bundle exec fastlane lanes
```

The July local-Ruby availability observation is historical, not a current
release blocker. Hosted upload receipts and actual lane configuration are
recorded in [readiness](../docs/app-store/readiness.md).

## Required Secrets

Release workflows need:

- `APP_STORE_CONNECT_API_KEY_JSON`
- `MATCH_PASSWORD`
- `MATCH_GIT_SSH_KEY`

The workflow writes the App Store Connect key to a temporary file and passes its
path as `APP_STORE_CONNECT_API_KEY_PATH` before running Fastlane.

## Lanes

### `ios beta`

Builds and distributes `nightly` or `weekly` trains to TestFlight:

```bash
bundle exec fastlane ios beta channel:nightly
bundle exec fastlane ios beta channel:weekly
```

Channel policy:

- `nightly` uploads to the internal TestFlight group named `nightly`.
- `weekly` uploads to the external TestFlight group named `weekly`.
- Both wait for build processing before finishing.

### `ios app_store`

Builds the `main` release train and uploads to App Store Connect:

```bash
bundle exec fastlane ios app_store
```

The lane uploads without submitting by default. Set
`APP_STORE_SUBMIT_FOR_REVIEW=true` only when the build should enter App Review,
and set `APP_STORE_AUTOMATIC_RELEASE=true` only when approved builds should
release automatically after review.

## Signing

`match` uses the shared certificate repository:

```text
git@github.com:dfakkeldy/echo-audiobooks-certificates.git
```

If a separately authorized release needs changed entitlements, the workflow
accepts `refresh_signing_profiles=true`. This regenerates profiles and is not a
read-only preparation step; obtain exact authorization before using it.

Current known app identifiers:

- `Dan.Visual-Timer`
- `Dan.Visual-Timer.watchkitapp` (embedded paired Watch companion)
- `Dan.Visual-Timer-Watch` and `Dan.Visual-Timer-Watch.watchkitapp` (older
  watch-only identities, kept in `Matchfile` for existing records)
- `Dan.Visual-Timer.TurnTimerWidgets`

Automation comes from the default-branch workflow ref for every channel. Keep
source/automation SHAs distinct and follow internal nightly → external weekly →
main acceptance before an authorized promotion. Do not backport feature work
directly to weekly/main to obtain a green check.

## Validation

Useful local checks:

```bash
ruby -c fastlane/Fastfile
ruby -c fastlane/Appfile
ruby -c fastlane/Matchfile
```

When the pinned Ruby is available:

```bash
bundle exec fastlane lanes
```

Before declaring TestFlight success, inspect the hosted workflow logs for all
three Fastlane outcomes:

- package uploaded to App Store Connect
- build finished processing
- build distributed to the intended tester group

Green resolver or build steps alone do not prove TestFlight visibility.
