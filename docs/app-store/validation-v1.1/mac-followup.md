# Mac follow-up — 15 November 2026

- Base fetched and checked: `origin/nightly` at `3febb3abc5adc64a2f390f7b547031b5d920a266` is already an ancestor of PR150.
- Local Watch control gate ran through `xcode-build-slot.sh`: **exit 0**, one test passed, zero failures, 77.383 seconds. Test: `testQuickTimerControlsAreLabelledThroughStartPauseResumeReset`.
- Preflight reported the paired phone and Watch system processes stable for 25 seconds. Watch bootstatus timed out after 120 seconds, but the app subsequently launched and completed its controls/relaunch test.
- Exact original head `bad430f` also passed hosted Watch CI in run [43666676014](https://github.com/dfakkeldy/VisualTimer/actions/runs/43666676014). The mini failure is consistent with host startup trouble; these results do not prove memory pressure was its sole cause.
- Focused import inspection found no exported type declaration in the app Info.plist, although the picker filters exclusively on `com.fakkeldy.turntimer.template`. Added its `.turntimer` extension mapping and JSON conformance, plus a runtime registration regression test.
- Local iOS test attempt was refused by the build-slot resource guard (exit 75): pressure 2, swap total 7168 MB, swap free 690 MB, required free 2048 MB. No local import runtime pass is claimed. Hosted CI must run the new test before landing.
- Existing codec round-trip, unsafe-field normalization and non-overwriting import tests passed on original-head hosted CI. They do not establish Files-picker interaction or signed-device acceptance.
- Fresh-context Astra review round 1: one minor log-whitespace finding, corrected. `git diff --check origin/nightly` and Info.plist validation pass.
- Release/signing/workflow settings are unchanged. No archive, upload, TestFlight submission or Apple submission was performed.
