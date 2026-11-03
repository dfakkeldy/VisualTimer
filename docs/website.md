# Website and documentation maintenance

Last audited: 2026-10-24

The live site is [Turn Timer](https://dfakkeldy.github.io/VisualTimer/).
GitHub Pages serves `main:/docs`; the installable browser timer is at
[`/VisualTimer/app/`](https://dfakkeldy.github.io/VisualTimer/app/).
Ordinary changes target `nightly` and become live after promotion through
`weekly` to `main`. A Nightly merge does not publish the Pages site.

## Files to edit

| Content | Source |
|---|---|
| Homepage, support, privacy, error page | `docs/index.html`, `support.html`, `privacy.html`, `404.html` |
| Public visual styling and icon | `docs/assets/` |
| Devlog | `docs/devlog.html` and `docs/guides/devlog.md` |
| Browser timer | `web/src/`, `web/public/` |
| Committed browser build | `docs/app/`, regenerated with `make web-pages` |

The public pages share CSS and use relative links so they work under the
GitHub Pages project prefix. The 404 page uses `/VisualTimer/` paths because
GitHub serves it for missing routes at arbitrary depths. Keep that prefix and
the Vite base path aligned if the Pages URL changes.

## Preview and verify

For the static public pages:

```sh
python3 -m http.server 5179 --bind 127.0.0.1 --directory docs
```

Open `http://127.0.0.1:5179/`. Check desktop and narrow mobile layouts, keyboard
focus, active navigation, and the support/privacy links. The compiled web app
expects `/VisualTimer/app/`, so use Vite for its local development:

```sh
cd web
npm ci
npm run dev
npm test
npm run check
npm run build
```

When web source or public assets change, run `make web-pages` at the repository
root and commit the regenerated `docs/app/` alongside the source. Static-page
changes do not require rebuilding the React app.

Run `make doc-automation-test` after editing the devlog structure or tooling.
Keep exactly one `AUTO-DEVLOG:START` / `AUTO-DEVLOG:END` pair in each devlog.
`make devlog-update` refreshes the previous calendar week's digest from commit
history; it does not announce an App Store launch or publish a social post.

## Current guidance and historical records

- [README](../README.md): scope, setup, and validation commands.
- [Architecture](../Architecture.md): source ownership, data, and platform boundaries.
- [Roadmap](../Roadmap.md): implemented scope and remaining work.
- [Contributor guide](../CONTRIBUTING.md): coding and validation conventions.
- [Readiness](app-store/readiness.md): dated release evidence and outstanding checks.
- [Fastlane](../fastlane/README.md): lane behavior and release controls.

`docs/superpowers/plans/` and the October submission,
marketing, screenshot, and signed-device worksheets are dated planning or
historical evidence. Their dates describe when they were prepared; they are not
live task lists or proof of store configuration. Follow their links to current
readiness and GitHub records before reusing them. Do not replace old evidence
with a new date unless it was actually rechecked.
