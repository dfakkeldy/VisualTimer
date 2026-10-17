# Turn Timer Release Acceptance

Re-checked: 2026-10-06 UTC. Results: **not recorded for a selected candidate**.
This focused launch check is not a demand to retest each nightly update. Prefer
an authorized tester/agent; consolidate device-only observations into one
short session when convenient.

Record candidate branch/SHA, version/build, device/OS, date, expected behavior
and actual result. Leave results empty until observed. Compilation, unit tests
and upload receipts do not prove these interactions.

## Core timer first

- [ ] Fresh install: quick timer and starter template start without account or
  purchase; controls work on supported iPhone/iPad layouts.
- [ ] Quick timer/two-round sequence: pause/resume, skip final round, completion
  sound and one history entry; no hidden countdown after completion.
- [ ] Run a short timer, lock/background past expiry, then return. Compare
  numbers, pie, sound and sequence state to intended behavior. Source uses
  tick-based completion and wall-clock visual progress; do not assume a
  background alarm or correct reconciliation.
- [ ] Audio interruption and silent/media-volume behavior are understood and
  described truthfully; the routine keeps its active step.
- [ ] Save one free template, relaunch and load it; malformed imports fail safely.

## Paid and Apple surfaces

- [ ] Selected TestFlight build loads `turntimer.pro.unlock`; purchase/cancel/
  pending flows do not strand the UI. TestFlight purchases are sandboxed;
  preparation requires neither a real purchase nor a new credential.
- [ ] Restore after reinstall re-enables Pro; revoked access returns to free.
  Record actual ASC product state separately from local StoreKit tests.
- [ ] Signed production CloudKit: create/edit/delete a template and completed
  history record, relaunch and verify propagation to a second authorized
  device. Offline/signed-out operation keeps local data usable. Confirm
  production types `Template` and `HistoryRecord` in the private database.
- [ ] Home/Lock Screen widgets open the correct template. Locked widgets route
  usefully into the app; selected archive embeds the extension.
- [ ] If Watch is part of the candidate distribution, confirm actual archive/
  store inclusion first. Paired Watch: free quick timer and starter template start, pause/resume,
  and complete. Separately test iPhone saved-template delivery; App Group files
  alone are not cross-device proof. Record limitations before approving copy.
- [ ] Accessible in-app privacy link opens the public policy in the candidate.

## Preparation before requesting a verdict

Reproduce/resolve source blockers in [readiness](readiness.md); inspect selected
archive manifests/entitlements/SDK; pass native CI; capture store screenshots.
No LLDB injection into a TestFlight install is required. Development probe
`CloudKitValidationRunner` is not review instructions or proof of deployed schema.

Keep internal acceptance → external weekly acceptance → main. Record actual
external eligibility/review and tested build before promotion. Old external
receipts do not validate new nightly changes.
