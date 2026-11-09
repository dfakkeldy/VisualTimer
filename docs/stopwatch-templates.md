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
the current step whose time so far will be kept and how many later steps won't be
measured, and reviews only visited steps. For a new plan, it also explains that
partial measurements can be saved but cannot create a template. Pause/Resume excludes paused time.
Elapsed time includes background/device sleep while the process remains alive and uses
a continuous monotonic clock, independent of wall-clock changes and UI refresh ticks.
Each step is capped at 24 hours; the display pauses at the cap. Stale duplicate Next
and Finish events are guarded by step identity; a brief Next guard also rejects a
second tap after the next step appears. Close asks before discarding an edited plan,
a recording, or an unsaved review. For any new routine's unkept recording, the dialog
also offers **Discard measurements, keep plan**, which returns to the plan without
closing, including after an earlier recording was saved. With plan edits,
**Discard recording and plan** names the action that loses both; without edits,
**Discard recording** discards the measurements and closes. Deleting
a saved recording restores the plan baseline from the newest remaining recording
for that routine, or the opening plan if none remain. Plan edits that lose their
only saved recording therefore remain available through Return to stopwatch. Swiping
the sheet down keeps the same stopwatch in memory: Return to stopwatch shows its
state in the editor, and other stopwatch entries stay disabled until that work is kept or discarded. Opening Pro dismisses
the stopwatch first, uses the editor's paywall, and reopens the same stopwatch when
the paywall closes. A retained stopwatch also follows Pro entitlement changes
from Settings or transaction updates, including loss of access. This retention lasts
only while the app process is alive.

New-plan steps have options menus and accessibility actions for moving and deleting,
as well as drag and swipe shortcuts. Validation names a missing routine or step
name beside Start and in its accessibility hint; template-mode guidance points back
to the template editor for those edits. VoiceOver announcements follow step,
recording/pause, saved, and 24-hour-limit transitions; display ticks do not announce.
Review transitions request VoiceOver focus on the review heading; Back and successful
Delete request focus on Start or the library history heading. Successful Delete
announces “Recording deleted”. Step-options labels have a minimum 44-point target.
Pause/Resume and the disabled Saved row keep stable controls in the view structure.

Finish opens review; it does not save or alter a template. Save recording writes an
atomic, validated JSON file to Application Support/StopwatchRecordings. Apply saves
the recording first, then changes the editor's durations. Save in the editor to keep
those template changes. Starting the timer also saves a template that's already saved.
Existing template save limits and Pro gates remain.
Measurements round to whole seconds, with the existing five-second template minimum;
review compares the rounded whole-second values and names the template duration
when the minimum changes the rounded measurement. Existing-template partial
recordings change only measured, still-enabled steps. A new routine requires every
step to be measured.

Recordings retain immutable source names, targets, and identities. Renaming/reordering
steps does not rewrite them; a removed/replaced/disabled measured step prevents Apply
rather than guessing by name or position. Both editor application paths share the
review's preflight rule: impossible Apply actions are disabled with inline recovery
guidance naming the source template and Local stopwatch recordings. If that template
has changed while the review is unsaved, the guidance says to save the recording first.
Measured steps that were removed or disabled must be restored first. New imports and new plans
have distinct template identities. Draft identity survives app restart and first
save. Save a routine template to make it easy to return to its recordings from the template picker.
**Local stopwatch recordings** also opens saved records across routines, including
new plans saved before Apply. A complete un-applied plan can be recovered into the
editor. For an existing saved source, open that template before applying measurements;
recovery never overwrites a different saved template. The recovery hint names the
saved template's current title when available. Step identities absent from the current
plan, including disabled or deleted steps, are marked “not in current plan” in the
trend picker. It includes only steps with visible saved measurements and falls back
to the first measured step if the selection is no longer available. History rows are
disabled with an explanation while plan edits remain unkept; **Undo plan edits** asks
for confirmation and undoes those edits without closing the stopwatch.

Comparison bars and dated per-step trends use neutral target/actual language. At
standard text sizes, charts appear above always-visible text rows with duration-formatted
axes. Comparison bars are distinguished by position, legend, and text rows. In the trend chart, target
and actual series differ in shape and dashed versus solid stroke: circles show
actuals, while squares mark captured targets. A no-target comparison omits Target
from its legend. At accessibility text sizes, both charts give way to the wrapping
text rows: comparison rows retain step names, targets, actuals, differences and any
minimum template duration; trend rows retain dates, step names, actuals and original
targets. The trend hint describes those dated values without referring to hidden
chart symbols. Each comparison or trend row remains one combined accessibility
element. Longer or shorter time has no success/failure meaning. Free history
shows the five most recent stopwatch recordings across routines; filtering by
routine happens after that limit. Pro exposes full retained history using the existing limit and
paywall. All recordings remain on this device,
including with Pro. Storage failures are shown; malformed files are kept for recovery
while readable recordings remain available. **Check again** retries a load failure or
unreadable files. Saved recordings can be explicitly deleted.

The local recording schema accepts only its supported version. Add optional fields
without increasing that version; increase it only together with a decoder that
continues to read older recordings. A version bump on its own would hide existing
recordings as unreadable rather than migrate them.

An unsaved starter is restored on relaunch, even when saved templates exist, so its routine and step identities stay stable before its first save.

## Remaining scope and proof

This initial implementation remains under hill-climb review. It
adds no countdown capture, web/watch stopwatch, CloudKit recording sync, recording
export, automatic target rewrites, or release changes. In-flight stopwatch sessions
and plan edits without a saved recording are memory-only: background time is supported, but
process termination loses an unfinished recording. Completed recordings must be
explicitly saved or applied. A saved partial new-plan recording can be viewed later,
but cannot be reopened as an editable plan or resumed; only a complete recording
can create a template through Apply. Existing countdown history is unchanged.

Deterministic unit tests cover timing, transitions, partial completion, captured
targets, comparison text, dated trend order, persistence failures and retries,
plan baselines after save/delete, safe workspace guards, entitlement changes with
and without a paywall, Apply preflight, named validation, stable identity across
clean drafts and first autosave, and editor application/save policy.
Two focused XCUITests use the existing reset-persisted-state launch flow to exercise
Finish early Cancel/confirm and Apply-as-new replacement Cancel/confirm through the
actual view buttons. They require no additional app fixture infrastructure.
A third UI test requests the largest accessibility text size, verifies the override
through rendered label geometry, and audits an early-finish review for clipped text,
including the five-second minimum-duration hint. It saves rendered and accessibility
context and excludes only clipping issues verified to belong to the background
editor. The one-row audit passed an unfixed-chart probe, so it is a smoke check, not a
proven detector for the captured three-row truncation. Full comparison visibility
is checked before auditing. Same-data rendered captures remain the proof for that
layout failure; complete accessibility labels alone do not establish visibility.
Apple build/test execution uses the Mac build-slot scheduler. On 2026-11-08,
the iOS app, embedded Watch app, and iOS test targets compiled. All 182 unit
tests passed, including 52 stopwatch tests, and both confirmation UI tests
passed on the iPhone 17 Pro simulator with iOS 27.0. The tests exercise native
popover dismissal when the platform omits a cancel-role row. Source parsing,
whitespace, plist and StoreKit configuration checks also passed.
Rendered iPhone captures verify the accessibility-size text alternative, standard-size
charts, recording-button contrast and visible Next icon. iPad captures cover portrait
and landscape sheets and the landscape accessibility-size review. Charts suppress
their accessibility children so the combined text rows provide the spoken values;
standard-size comparison and trend snapshots confirm their chart elements are absent
while the combined text rows remain. A clipping audit cannot prove chart layout. Spoken
VoiceOver evidence also remains outstanding; compilation, labels and audit results
do not establish spoken announcements, focus or reading order. Hill-climb findings
and evidence are recorded separately. No physical-device acceptance or release
is claimed.
