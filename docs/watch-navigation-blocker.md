# Watch navigation verification blocker

PR #124 adds failure attachments before the two initial navigation assertions
in `testQuickTimerControlsAreLabelledThroughStartPauseResumeReset`. It records
cycle, expected identifier, app state, screenshot, button counts, labels,
frames, hittability and the accessibility hierarchy. It also reuses that
capture helper for the later label waits. It does not fix navigation.

In GitHub Actions run 39167884206, the root Quick Timer button exists and is
tapped at 19.96 seconds. The destination `watch.quick.primary` does not appear
within five seconds; the assertion at the old line 51 fails at 28.8 seconds.
The navigation link is in `WatchRootView.swift` and its destination control
is in `WatchTimerView.swift`. Both are Watch-specific views. The iPhone does
not execute this navigation path. The available evidence does not identify
a shared timer-state defect that could be reproduced by an iPhone test.

Verification is blocked on a Watch simulator or device. The November 16,
2026 task explicitly forbids Watch work on the rented M4 mini, so no Watch
simulator was created, booted or tested. No speculative production fix was
made. iPhone unit or UI tests cannot demonstrate that this Watch navigation
failure or the new failure attachments work.

A follow-up on an authorized Watch host must reproduce the initial navigation
failure, exercise both attachment branches, and verify any resulting fix with
a failing-before and passing-after regression. Keep the PR draft until then.

The branch is now updated with nightly `030cb96`. Nightly already includes
these diagnostics and a guarded second root tap plus longer polling waits.
The merge keeps nightly's Watch test unchanged. The remaining PR diff is this
blocker record; neither the inherited retry nor the diagnostics were validated
on a Watch during this task.
