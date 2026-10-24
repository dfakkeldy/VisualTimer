# Building Turn Timer - The Devlog

Turn Timer's public build record is generated from the real commit history, with room for hand-written notes when a week needs more context.

Turn Timer is the public product name. The repository and Xcode project retain
VisualTimer / Visual Timer identifiers for compatibility.

---

<!-- AUTO-DEVLOG:START -->
## Automated update - Oct 12-18, 2026

*Generated from 5 commits merged during the week.*

### Fixed
- Improve countdown controls and completion alerts (#106) ([0c43e84](https://github.com/dfakkeldy/VisualTimer/commit/0c43e84))
- Skip unchanged train deliveries (#110) ([f45afb6](https://github.com/dfakkeldy/VisualTimer/commit/f45afb6))

### Build, docs, and housekeeping
- Wake Claude when Dan adds go:claude to an issue ([c8b9834](https://github.com/dfakkeldy/VisualTimer/commit/c8b9834))
- Record Watch and widget privacy manifests (#116) ([6e5f887](https://github.com/dfakkeldy/VisualTimer/commit/6e5f887))
- Document change-aware train delivery (#111) ([5ca5e00](https://github.com/dfakkeldy/VisualTimer/commit/5ca5e00))

<!-- AUTO-DEVLOG:END -->

The automated block is refreshed by `.github/workflows/devlog-update.yml`. The
workflow opens a reviewed PR against `main`, includes a factual commit digest,
and adds an optional AI-assisted draft only when `OPENAI_API_KEY` is configured.
Nothing is posted publicly without a human choosing to merge and reuse the copy.

## Notes

The generated weekly digest above is safe to refresh automatically. Hand-written launch notes can live below this section when there is a story worth telling in more detail.

### October 24, 2026: browser app and promoted Apple source

The [browser app](https://dfakkeldy.github.io/VisualTimer/app/) is live with six
starters, editable sequences, local history, and portable templates. The Apple
source reached `main` in [PR #114](https://github.com/dfakkeldy/VisualTimer/pull/114)
on October 17, followed by App Store Connect upload 1.0 (77). Upload is separate
from public availability; see the [readiness ledger](../app-store/readiness.md).

### July 2026: Pro sync and widgets validation

The implementation added the release-validation path for Pro iCloud sync and widgets:
template sync has a live CloudKit probe, completed history can sync through the
private `TurnTimerHistory` zone, and Home Screen plus Lock Screen widgets launch
templates from App Group snapshots. Local simulator builds cover compilation,
StoreKit JSON validity, mapper behavior, and extension embedding. A signed
iCloud build is still required before release to prove account/container access,
CloudKit subscriptions, schema deployment, cross-device propagation, and widget
taps against an installed build.
