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

Start counts up. Next completes the displayed step and immediately starts the next.
Finish & review completes the last step. Finish early asks for confirmation, names
how many upcoming steps won't be measured, and reviews only visited steps. For a new
plan, it also explains that partial measurements can be saved but cannot create a
template. Pause/Resume excludes paused time.
Elapsed time includes background/device sleep while the process remains alive and uses
a continuous monotonic clock, independent of wall-clock changes and UI refresh ticks.
Each step is capped at 24 hours; the display pauses at the cap. Stale duplicate Next
and Finish events are guarded by step identity; a brief Next guard also rejects a
second tap after the next step appears. Close asks before discarding an edited plan,
a recording, or an unsaved review. Swiping the sheet down keeps the same stopwatch
in memory: Return to stopwatch shows its state in the editor, and other stopwatch
entries stay disabled until that work is kept or discarded. Opening Pro dismisses
the stopwatch first, uses the editor's paywall, and reopens the same stopwatch when
the paywall closes. This retention lasts only while the app process is alive.

New-plan steps have options menus and accessibility actions for moving and deleting,
as well as drag and swipe shortcuts. Validation names a missing routine or step
name beside Start and in its accessibility hint. VoiceOver announcements follow step,
recording/pause, saved, and 24-hour-limit transitions; display ticks do not announce.
Pause/Resume and the disabled Saved row keep stable controls in the view structure.

Finish opens review; it does not save or alter a template. Save recording writes an
atomic, validated JSON file to Application Support/StopwatchRecordings. Apply saves
the recording first, then changes the editor's durations and leaves normal Save/Save
changes to persist the template. The existing Start/autosave path also remains in place.
Existing template save limits and Pro gates remain.
Measurements round to whole seconds, with the existing five-second template minimum;
review explains this conversion and names the applied duration when the five-second
minimum changes the rounded measurement. Existing-template partial recordings change only
measured, still-enabled steps. A new routine requires every step to be measured.

Recordings retain immutable source names, targets, and identities. Renaming/reordering
steps does not rewrite them; a removed/replaced/disabled measured step prevents Apply
rather than guessing by name or position. New imports and new plans have distinct
template identities. Draft identity survives app restart and first save. Save a routine
template to make it easy to return to its recordings from the template picker.
**Local stopwatch recordings** also opens saved records across routines, including
new plans saved before Apply. A complete un-applied plan can be recovered into the
editor. For an existing saved source, open that template before applying measurements;
recovery never overwrites a different saved template. The recovery hint names the
saved template's current title when available. Earlier, replaced step identities
are marked “earlier step” in the trend picker.

Comparison bars and dated per-step trends use neutral target/actual language. Every
chart has visible text alternatives and duration-formatted axes. Comparison bars
are distinguished by position, legend, and text rows. In the trend chart, target
and actual series differ in shape and dashed versus solid stroke. Longer or shorter
time has no success/failure meaning. Free history shows
the five most recent stopwatch recordings across routines; filtering by routine happens
after that limit. Pro exposes full retained history using the existing limit and
paywall. All recordings remain on this device,
including with Pro. Storage failures are shown; malformed files are kept for recovery
while readable recordings remain available. Saved recordings can be explicitly deleted.

## Remaining scope and proof

This is initial implementation, pending the parent's approved review/hill-climb. It
adds no countdown capture, web/watch stopwatch, CloudKit recording sync, recording
export, automatic target rewrites, or release changes. In-flight stopwatch sessions
and un-applied name-only plans are memory-only: background time is supported, but
process termination loses an unfinished recording. Completed recordings must be
explicitly saved or applied. Existing countdown history is unchanged.

Deterministic unit tests cover timing, transitions, partial completion, captured
targets, comparison text, dated trend order, persistence failures and retries,
plan baselines, safe workspace guards, paywall return, named validation, stable
identity across clean drafts and first autosave, and editor application/save policy.
Apple build/test execution must use the Mac build-slot scheduler. On 2026-11-08,
the changed Swift sources/tests passed syntax parsing, the diff passed whitespace
checks, project and app plists passed lint, and the StoreKit configuration parsed.
The scheduler remained on HOLD outside permitted build hours, so the authored tests
have not run and platform compilation remains outstanding. The fake store's actor
conformance has not been compiler-verified. UI captures and spoken VoiceOver output
also remain unverified; source changes do not establish focus, layout, or presentation
behavior on a running app. No scored hill-climb or device testing occurred.
