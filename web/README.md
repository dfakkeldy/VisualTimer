# Turn Timer Web

Turn Timer Web is an installable React progressive web app for visual turns,
routines, and sequences. It mirrors the native product's core timer experience
while remaining intentionally local-first.

## Run locally

Use Node.js 22 or newer:

```bash
npm ci
npm run dev
```

Open the local URL printed by Vite. Production verification is:

```bash
npm test
npm run check
npm run build
npm run preview
```

`npm run build:pages` writes the same production client to `docs/app/`. That
package is the future GitHub Pages `/VisualTimer/app/` tree, but Pages is served
from `main` `/docs`, and `docs/app/` is not on `main` yet. Until promotion, run
the client locally. The build intentionally leaves the existing Pages homepage,
support, privacy, and devlog routes intact.

## Architecture

| Area | Location | Responsibility |
|---|---|---|
| Domain | `src/domain` | Pure timer transitions, remaining-time calculations, template encoding and decoding |
| Controller | `src/hooks/useTurnTimerController.ts` | Timer orchestration, template editing, history, and application actions |
| Persistence | `src/hooks/usePersistentState.ts` | Versioned browser-local preferences, templates, and history |
| Screens | `src/components` | Declarative timer, template, history, navigation, and settings UI |
| Starter data | `src/data/starterTemplates.ts` | The six free starter workflows shared conceptually with the Apple app |
| PWA shell | `public/manifest.webmanifest`, `public/sw.js` | Installation metadata and a small application-shell cache |
| GitHub Pages package | `docs/app` | Committed production copy on `nightly`/`weekly`; not live on Pages until promoted to `main` |

The countdown is timestamp-derived rather than decrementing an integer once per
second. This keeps the timer accurate when the browser delays callbacks or a
background tab is resumed.

## Data and platform boundaries

- Browser data stays in local storage unless the user explicitly exports a
  template.
- Template import/export uses the portable `.turntimer` JSON document shape.
- Imported templates receive a new identity so they cannot overwrite an
  existing local document.
- Audio is generated through the Web Audio API and respects the browser's
  interaction requirements.
- StoreKit purchases, CloudKit sync, widgets, and watch support remain native
  Apple-platform features. The web client does not imitate entitlement state.

## Browser support

The production target is current evergreen browsers with ES modules, CSS grid,
the Web Audio API, and service workers. The layout is explicitly verified at
1536×1024 desktop and 390×844 mobile viewports. Reduced-motion preferences,
keyboard focus, semantic controls, and 44-pixel minimum touch targets are
supported.

## Design

The accepted visual references and fidelity notes are in
[`docs/design/spec.md`](docs/design/spec.md). Those references are a design
contract; they are not shipped as application UI.
