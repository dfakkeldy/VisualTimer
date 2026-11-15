# Native v1.1 candidate screenshots

Four inspected images per device, captured 2026-11-15. These are original PNGs
from the repository's native UI capture tests, without alpha channels, image
edits or promotional overlays. The fixture uses generic sample data.

| Scene | iPhone 17 | iPad Pro 13-inch (M5) |
|---|---|---|
| Ready quick timer | [PNG](iphone/01-timer-ready.png) | [PNG](ipad/01-timer-ready.png) |
| Paused quick timer | [PNG](iphone/02-timer-paused.png) | [PNG](ipad/02-timer-paused.png) |
| Recent history | [PNG](iphone/08-history.png) | [PNG](ipad/08-history.png) |
| Routine stopwatch | [PNG](iphone/13-routine-stopwatch.png) | [PNG](ipad/13-routine-stopwatch.png) |

Suggested upload order: stopwatch, ready timer, history, paused timer.
All foreground labels in the retained images were inspected for clipping.
The iPad stopwatch is a native sheet over the dimmed editor; background content
is naturally obscured by the sheet. No debug overlays or account data appear.

The [manifest](manifest.json) records dimensions, hashes, source and tooling.
The source app still reports 1.0 (1); 1.1 is the intended release, not the
captured binary's marketing version. Match these screens to the final candidate
before uploading. No upload or submission occurred. See the
[handoff](../../v1.1-preparation.md) and [capture procedure](../../../marketing/screenshot-plan.md).
