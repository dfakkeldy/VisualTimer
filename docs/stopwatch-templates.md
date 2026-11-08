# Stopwatch routine templates — initial implementation

## Plan

1. Snapshot the routine's stable template and step identities, names, and optional targets.
2. Measure enabled steps with a small guarded state machine and an injected continuous clock.
3. Review, save on this device, and explicitly apply measurements through the template editor.
4. Compare each step against its captured target and chart dated recordings without judging speed.
5. Verify transitions, identity isolation, immutable snapshots, persistence, and editor save integration.

## V1 capture and behavior

In Templates, **Time this template** measures one pass through enabled rounds in their
current order. Repeat count, start-paused flags, sounds, and countdown notifications do
not control the stopwatch. Disabled rounds are omitted. **Plan a new routine** accepts
names without durations; its first recording has no targets. A new plan becomes an
editable template only after a complete recording and explicit Apply.

Start counts up. Next completes the displayed step and immediately starts the next;
Finish ends early and reviews only visited steps. Pause/Resume excludes paused time.
Elapsed time includes background/device sleep while the process remains alive and uses
a continuous monotonic clock, independent of wall-clock changes and UI refresh ticks.
Each step is capped at 24 hours; the display pauses at the cap. Stale duplicate Next
and Finish events are guarded by step identity; a brief Next guard also rejects a
second tap after the next step appears. Closing or restarting unkept work
requires an explicit discard choice.

Finish opens review; it does not save or alter a template. Save recording writes an
atomic, validated JSON file to Application Support/StopwatchRecordings. Apply saves
the recording first, then changes the editor's durations and leaves normal Save/Save
changes to persist the template. The existing Start/autosave path also remains in place.
Existing template save limits and Pro gates remain.
Measurements round to whole seconds, with the existing five-second template minimum;
review explains this conversion. Existing-template partial recordings change only
measured, still-enabled steps. A new routine requires every step to be measured.

Recordings retain immutable source names, targets, and identities. Renaming/reordering
steps does not rewrite them; a removed/replaced/disabled measured step prevents Apply
rather than guessing by name or position. New imports and new plans have distinct
template identities. Draft identity survives app restart and first save. Save a routine
template to make it easy to return to its recordings from the template picker.
**Local stopwatch recordings** also opens saved records across routines, including
new plans saved before Apply. A complete un-applied plan can be recovered into the
editor. For an existing saved source, open that template before applying measurements;
recovery never overwrites a different saved template.

Comparison bars and dated per-step trends use neutral target/actual language. Every
chart has visible text alternatives; target lines and actual points differ in shape
and stroke. Longer or shorter time has no success/failure meaning. Free history shows
the five most recent stopwatch recordings across routines; filtering by routine happens
after that limit. Pro exposes full retained history using the existing limit and paywall. All recordings remain on this device,
including with Pro. Storage failures are shown; malformed files are kept for recovery
while readable recordings remain available. Saved recordings can be explicitly deleted.

## Remaining scope and proof

This is initial implementation, pending the parent's approved review/hill-climb. It
adds no countdown capture, web/watch stopwatch, CloudKit recording sync, recording
export, automatic target rewrites, or release changes. In-flight stopwatch sessions
and un-applied name-only plans are memory-only: background time is supported, but
process termination loses an unfinished recording. Completed recordings must be
explicitly saved or applied. Existing countdown history is unchanged.

Twenty-two deterministic unit tests cover timing, transitions, partial completion, target snapshots,
identity isolation, persistence failures/round-trip, and applying via the dirty editor.
Apple build/test execution must use the Mac build-slot scheduler. On 2026-11-08,
the changed Swift sources/tests passed syntax parsing and the diff passed whitespace
checks. The wrapper deferred the iOS test command with exit 75 (outside permitted
build hours). The authored tests have not run; platform compilation and UI evidence
remain outstanding for the parent. No scored hill-climb or device testing occurred.
A source parse is
not a platform build, unit-test pass, UI observation, or device-acceptance result.
