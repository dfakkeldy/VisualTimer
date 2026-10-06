# Screenshot Capture Manifest

Re-checked: 2026-10-06 UTC. **Native images pending selected candidate**.
App icon PNGs/SVG exist; `web/docs/design/*.png` are web design evidence and
must not be uploaded as native screenshots. Do not fabricate screens or use
old main UI to illustrate nightly features. No screenshots have been uploaded.

## Required sizes

Current [Apple specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
require at least one image per required category, up to ten per size, JPEG/JPG/
PNG with no alpha/transparency. Required for the universal iOS app; Watch set
is conditional on an actually submitted Watch app/distribution:

| Platform | Category / accepted portrait dimensions |
|---|---|
| iPhone | Dynamic Island medium: 1179×2556 or 1206×2622 |
| iPad | 13-inch: 2064×2752 or 2048×2732 |
| Watch, if submitted | Choose one consistent size: 422×514, 410×502, 416×496, 396×484, 368×448 or 312×390 |

Apple also specifies scaling fallbacks/landscape reversals. Record the actual
ASC category's acceptance; an old large-iPhone image set is not automatically
proof that current categories are complete. No Mac screenshots: source has no
native Mac target.

## Minimum useful launch set

| File stem | Caption | Actual candidate screen |
|---|---|---|
| `01-visual-countdown` | Make time visible | Active quick timer with visible duration/controls |
| `02-reusable-rounds` | Keep every turn moving | Game Night playback with current/next round |
| `03-starter-templates` | Start with a routine | Six starter templates, including Morning Routine |
| `04-edit-steps` | Build the steps you need | Editor with public fixture names/durations |
| `05-pro-reuse` | Keep the setups you reuse | Real Pro screen; no price overlay or unsupported feature claim |
| `watch-01-starter` | Start a routine on Watch | Actual Watch starter/playback, after acceptance |

Capture iPhone and iPad sets using the same storyline; one real Watch image is
sufficient if Watch is included. Current iOS release scheme has an empty Watch
embed phase and no Watch dependency; a separate CI Watch build is not proof
of shipment. Resolve distribution before making the Watch set a requirement. Widget/sync campaign images can follow proof;
no saved-template Watch-sync image until its transport and result are verified.
Optional app preview/featuring/campaign sets are not prerequisites.

## Public fixture data

Game Night: Player A 60s, Player B 60s, Player C 60s, Break 30s (not a turn).
Recipe: Prep 5m, Simmer 12m, Stir 1m, Rest 5m.
Meeting: Opening 3m, Updates 10m, Decisions 8m, Wrap 2m.
Use generic fixtures only; no private tester/device/account content.

## Capture receipt

Record source/automation SHA, version/build, device/OS, locale, capture date,
pixel dimensions and alpha check beside each delivered set. Verify text is
legible, UI/controls are usable, no placeholder/login/splash-only image appears,
and every caption matches the screen. Caption overlays stay under eight words.

IAP review also needs an actual candidate paywall/unlocked-state screenshot.
Do not claim it exists based on a `.storekit` file or this manifest.
