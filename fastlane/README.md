# Fastlane Release Docs

Last updated: 2026-07-01

Fastlane owns Turn Timer's archive, signing-profile sync, TestFlight upload, and
App Store upload lanes. App Store metadata is not yet fully checked in on
`main`; marketing metadata drafts are being isolated separately before upload.

## Local Tooling

The repo pins Ruby through `.ruby-version`. If the local shell cannot find that
Ruby, use the rbenv shims first:

```bash
PATH="$HOME/.rbenv/shims:$PATH" bundle exec fastlane lanes
```

In this worktree, the pinned Ruby was not installed locally during the docs
audit, so Fastlane commands could not be fully exercised without installing the
matching Ruby or switching to the known working rbenv version.

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

`APP_STORE_SUBMIT_FOR_REVIEW=false` uploads without submitting. Set
`APP_STORE_AUTOMATIC_RELEASE=true` only when approved builds should release
automatically after App Review.

## Signing

`match` uses the shared certificate repository:

```text
git@github.com:dfakkeldy/echo-audiobooks-certificates.git
```

If entitlements change, dispatch the release workflow with
`refresh_signing_profiles=true` so App Store profiles are regenerated instead of
read-only fetched.

Current known app identifiers:

- `Dan.Visual-Timer`
- `Dan.Visual-Timer-Watch`
- Widget and watch-extension identifiers are staged on `nightly` and should be
  kept in sync with the project before release.

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
