# Building Turn Timer - The Devlog

Turn Timer's public build record is generated from the real commit history, with room for hand-written notes when a week needs more context.

This project is still being rebranded from Visual Timer, so update hand-written notes when the public naming settles.

---

<!-- AUTO-DEVLOG:START -->
## Automated update - Jun 22-28, 2026

*Generated from 1 commit merged during the week.*

### Build, docs, and housekeeping
- Add weekly automation ([46010c5](https://github.com/dfakkeldy/VisualTimer/commit/46010c5))

<!-- AUTO-DEVLOG:END -->

## Notes

The generated weekly digest above is safe to refresh automatically. Hand-written launch notes can live below this section when there is a story worth telling in more detail.

### Turn Timer Pro sync and widgets validation

This branch adds the release-validation path for Pro iCloud sync and widgets:
template sync has a live CloudKit probe, completed history can sync through the
private `TurnTimerHistory` zone, and Home Screen plus Lock Screen widgets launch
templates from App Group snapshots. Local simulator builds cover compilation,
StoreKit JSON validity, mapper behavior, and extension embedding. A signed
iCloud build is still required before release to prove account/container access,
CloudKit subscriptions, schema deployment, cross-device propagation, and widget
taps against an installed build.
