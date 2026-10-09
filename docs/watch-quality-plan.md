# Watch Quality Plan

Status: implemented in source on 2026-10-08; hosted simulator validation
passed on 2026-10-09 at implementation head
`78697ea9e66349f3a09f7eaace3b2bbc0e8c30e9`. The executed checks are
recorded below. A signed paired-Watch build and physical behavior remain
unverified.

## Diagnosis (Nightly `67800737`)

| Area | Finding |
|---|---|
| Quick Timer digits | `WatchTimerView` showed `totalDuration` while running, so the digits never counted down. |
| Quick Timer completion | Its private `TimerViewModel` never set `onFinish`. Completion auto-reset with no sound or haptic. |
| Navigation | The quick timer lived in a `@StateObject` inside the pushed view, so going back destroyed a running countdown. A template session kept running after back navigation, but there was no way back to it. |
| Controls | Quick Timer had small icon-only Play/Pause with Reset only while paused. Template playback had a tap-the-ring toggle, icon-only previous/skip buttons and no explicit reset or end. No accessibility identifiers. |
| Crown | The crown could select minutes or seconds while running. `setDuration` ignored the edit, so the selection had no visible effect. |
| Foreground return | Root activation refreshed templates only. Countdown reconciliation waited for the next 1 Hz tick. |
| Background | No local notification. Completion detected only by a foreground tick or a later reconciliation. |

## Plan

1. **Ownership.** `WatchAppModel` (App-level `@StateObject`) owns the quick
   timer, the session timer and `GameViewModel`, so leaving a screen never stops
   a countdown. The root list gains a "Resume Session" row while a session exists.
2. **Truthful digits.** Quick Timer and session digits come from the timer's Date-based
   `TimerVisualProgress.remainingSeconds(at:)`. This is the same source as the
   ring, so the digits stay correct between ticks and after wake.
3. **Controls.** Large labelled Start / Pause / Resume and Reset (Quick Timer) or
   Restart (resets the current round), Previous, Skip and End Session
   (sessions). End Session uses `GameViewModel.endGame()`, so ending a session
   midway saves a partial record to the Watch's local history, as iOS does. Each control has an
   accessibility label, a value where relevant, a stable identifier and a
   minimum height of 44 pt.
4. **Idle-only crown.** `WatchQuickTimerViewModel` accepts crown and VoiceOver
   adjustments only in `.notStarted`. Starting clears the selection.
5. **Completion alerts.** `WatchTimerAlertCoordinator` (shared, unit-tested)
   installs `onFinish` before any successor round starts. It picks one alert:
   - on screen and on time: the selected sound plus a `.notification` haptic
   - on screen but late: haptic only, or nothing when a notification already fired
   - off screen: nothing in the app; the notification owns the alert
6. **Notifications.** One `UNTimeIntervalNotificationTrigger` per running
   countdown at its exact finish date. Pause, reset, restart, skip, end and
   on-screen completion cancel it. Resume and each new round schedule a new one.
   IDs are unique per run, so a successor round can't replace a predecessor
   notification that hasn't been delivered yet. A cancel that overtakes an in-flight add removes the request again.
7. **Permission.** Permission is requested only from an explicit "Allow Alerts" row.
   When alerts are denied, the root shows honest copy: alerts work only while Turn Timer is on
   screen. With no notification, a completion missed while off screen gives one
   haptic on return. No entitlement, Info.plist, extended runtime, workout or
   background mode is added.
8. **Foreground reconciliation.** When the scene becomes active, both timers reconcile against the
   Date. A notification arriving while the app is active reconciles immediately
   and is not shown as a banner. When the app is inactive, it is shown.
9. **Preserved.** The overdue pause still completes the round and never pauses the
   successor, with no catch-up loop. iOS behavior, history files,
   template files, the free/Pro boundaries and the WatchConnectivity snapshot
   and revocation path are unchanged.

## Tests

- `Visual TimerTests/WatchTimerQualityTests.swift` (iOS-hosted, covers the shared
  sources): finish-date tracking, schedule, cancel and reschedule across pause, resume, reset and stop, on-time,
  late and background alert choice, denied fallback, permission changes during a run,
  overdue pause with successor round, and quick-timer digits, controls and idle-only crown.
- `Visual Timer Watch Watch AppUITests`: labelled Start → Pause → Resume →
  Reset flow with stable identifiers.

## Executed validation

[CI 37874975447](https://github.com/dfakkeldy/VisualTimer/actions/runs/37874975447)
passed at the implementation head above. The build gate executed the iOS and
watchOS builds, 115 iOS-hosted unit tests (including all 26 Watch quality
tests), six iOS UI tests and the Watch Start/Pause/Resume/Reset UI test, with
zero failures. The separate web job passed its domain tests, TypeScript,
production build and committed-site verification. Apple result bundles were
preserved by the workflow.

These are simulator and automated checks. They do not establish signing,
paired-device transfer, notification delivery, sound, haptics, Always On or
CloudKit behavior on hardware. No profile, entitlement, account resource or
release setting was changed to obtain this evidence. A later documentation
commit does not extend these results to untested source changes.

## Not verified physically

These need a signed paired-Watch pass:

- the notification while the wrist is down
- the banner when the app is inactive but frontmost
- the speaker sound and the haptic
- Always On updates
- the crown feel
- process termination during a countdown: the notification still arrives, but the countdown is not restored
