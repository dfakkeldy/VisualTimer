# React web app design contract

The approved direction is a focused, dark, presentation-style timer rather than
a marketing dashboard. The countdown is the dominant object, with editing and
history available as adjacent product surfaces.

## Accepted references

| Surface | Reference | Native image size | Verification viewport |
|---|---|---:|---:|
| Active timer, desktop | [`timer-desktop.png`](timer-desktop.png) | 1536×1024 | 1536×1024 |
| Template editor, desktop | [`templates-desktop.png`](templates-desktop.png) | 1536×1024 | 1536×1024 |
| Active timer, mobile | [`timer-mobile.png`](timer-mobile.png) | 852×1846 generated output | 390×844 requested device viewport |

The mobile generator returned a larger raster than the requested viewport. The
implementation follows the 390×844 layout proportions and is acceptance-tested
at that functional viewport.

## Visual tokens

- Background: deep navy (`#071421`) with a quiet blue radial lift.
- Primary action and active navigation: coral (`#ff5750`).
- Text: warm off-white (`#f7f2e9`), with cool gray secondary copy.
- Surfaces: restrained navy elevations with one-pixel translucent borders.
- Shape language: circular countdown and status markers; eight- to fourteen-pixel
  control radii; no decorative card grid around the timer.
- Typography: Avenir Next where available, system fallbacks elsewhere, and a
  tabular monospace countdown.

## Copy lock

The active desktop surface keeps these above-fold labels: Turn Timer, Timer,
Templates, History, Settings, Current round, Next round, Elapsed, Pause,
Do-over, Skip, Restart, and `Turn n of n`. The mobile surface removes only the
desktop rail labels that are represented in the bottom navigation. No marketing
copy is added above the fold.

## Fidelity ledger

1. The 228-pixel desktop product rail, central countdown stage, and 360-pixel
   sequence rail preserve the reference's three-column hierarchy.
2. The countdown remains the largest object and uses a clockwise conic fill,
   central pause/play control, tabular remaining time, and subordinate elapsed
   time.
3. Current/next round headings and sequence progress keep the reference copy,
   ordering, color coding, emoji, and timing metadata.
4. The template editor keeps the left library, top command bar, sequence rows,
   repeat control, and inline duration editing.
5. The 390×844 layout moves navigation to a fixed bottom bar, hides the desktop
   sequence rail, shows compact `Turn n of n` progress, and fits without page
   scrolling or control overlap.
6. Icons are code-native SVGs, while starter emoji remain text so their exact
   appearance can vary by operating system.
7. Live countdown values intentionally differ from static references. The
   implementation displays real state rather than freezing concept values.
8. The shipped brand uses the actual Turn Timer app icon; the concept's simpler
   circular mark is not duplicated as a separate fake asset.
