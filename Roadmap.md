# Turn Timer roadmap

Last audited: 2026-10-24

Turn Timer is a visual countdown and sequence timer for everyday routines.
This roadmap describes implemented source and remaining product work. Dated
build and delivery receipts live in the [readiness ledger](docs/app-store/readiness.md).

## Available on the web

The [browser app](https://dfakkeldy.github.io/VisualTimer/app/) is live and
installable, with a quick timer, six starter templates, editable sequences,
local history, and `.turntimer` import/export. Browser data stays local and
does not use Apple Pro purchases or iCloud.

## Implemented on Apple platforms

The October 17 promotion to `main` included:

- Quick visual countdown, editable rounds, repeats, skip, restart, and do-over.
- Game Night, Recipe Steps, Plant Watering, Classroom Stations, Meeting Agenda,
  and Morning Routine starters.
- One custom saved template and recent history free; one-time Pro unlock for
  additional templates, full history/export, sync, sharing, widgets, and
  customization.
- Portable `.turntimer` documents with safe import identities and legacy reads.
- Private CloudKit template/history sync, enabled with Pro.
- Home Screen and Lock Screen widget snapshots and launch links.
- Embedded Watch companion, live countdown, starter playback, saved-template
  transfer code, and permission-gated completion notifications.
- Timestamp-derived countdown reconciliation and accessibility fallbacks for
  the newer iOS timer visuals.

Main upload **1.0 (77)** succeeded on October 17. This is an upload receipt,
not evidence of current App Review status or public App Store availability.
Physical Watch delivery, live CloudKit, and background sound are not established
by source or simulator results.

## Remaining release work

- Reconcile the selected App Store build and current review/release state with
  the dated delivery receipts before a release decision.
- Resolve and record candidate-specific purchase/restore, production sync,
  widget, and paired-Watch evidence when those release checks are undertaken.
- Keep store copy and screenshots tied to the chosen candidate and its observed
  behavior. Existing metadata and screenshot plans remain dated drafts.
- Preserve the `nightly` → `weekly` → `main` ladder. Ordinary maintenance ends
  at a verified Nightly PR; promotion and public release are separate actions.

Routine documentation and website work does not require a new device test or
App Store action. Current PRs and issues, rather than a copied count here,
track active engineering work on [GitHub](https://github.com/dfakkeldy/VisualTimer).

## Later possibilities

Metadata upload automation, repeatable screenshot capture, focused product
pages for different routines, and an App Preview remain future work. Measure
traffic before planning product-page experiments. Keep marketing claims about
focus, health, or accessibility tied to evidence.
