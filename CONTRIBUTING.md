# Contributing to Turn Timer

This document describes the codebase conventions and architecture
rules so that contributors (human or AI) can make changes that are
consistent with the existing design.

## Product Language

Use Turn Timer, templates, sequences, rounds, turns, routines, and
sessions in user-facing copy. Internal `GameSequence` naming can remain
until a dedicated model migration. Avoid describing the app as only a
generic timer or only a board-game timer.

## Architecture Rule: MVVM with Dumb Views

- **ViewModels own all logic.** `TimerViewModel` is the single source
  of truth for timer state, countdown mechanics, and screen-sleep
  management. `SoundManager` owns audio session configuration and
  playback.
- **Views are declarative.** Every SwiftUI view receives data through
  `let` properties and communicates back through closure callbacks.
  Feature container views may observe their owning view models, but leaf
  controls should stay stateless and business logic-free.
- **State flows down, events flow up.** Published properties drive
  the UI; button taps invoke closures that call ViewModel methods.

## Monetization Rules

Turn Timer uses a non-consumable StoreKit 2 Pro unlock with product ID
`turntimer.pro.unlock`. Do not block quick timer, built-in starter templates, or
basic session playback behind Pro. Pro gates reuse and portability: additional
saved templates, full history/export, sync, sharing, widgets, and advanced
customization.

## Adding a New View

1. Create the view in its own file (e.g., `MyNewView.swift`).
2. Accept all inputs as `let` properties and all outputs as `() -> Void`
   closures.
3. Use `Theme` constants for every color, dimension, symbol name, and
   animation value — never hardcode a number or string.
4. Write a `///` doc comment on the struct describing its purpose.
5. Compose the new view inside the relevant feature container; keep state
   management at the container or view-model layer.

## Modifying the Timer Behavior

- State-machine transitions live exclusively in `TimerViewModel`.
  Each transition method guards against invalid states so the UI can
  call them unconditionally.
- Timer mechanics (interval, tick handling) are private to
  `TimerViewModel`. External code only sees `@Published` state and
  the `onFinish` callback.
- If a new state or transition is needed, update `TimerState` first,
  then add the transition method, then update `ControlRingView` to
  render the corresponding button set.

## Modifying Audio

- All audio constants (sample rate, beep count, interval, volume,
  amplitude) are private enums inside `SoundManager`.
- Per-sound parameters (frequency, duration) are computed properties
  on the `TimerSound` enum.
- To add a new sound: add a case to `TimerSound`, provide its
  `displayName`, `frequency`, and `toneDuration` values. The WAV
  generator and settings picker will handle it automatically.

## Theme Constants

- `Theme.swift` is the single source of truth for all visual values.
- When adding a new color, dimension, or symbol, add it to the
  appropriate nested enum. Never duplicate a magic number across
  views.

## Commit Conventions

- Use imperative, present-tense commit messages (e.g., "Add snooze
  button to paused state").
- Keep commits focused — one logical change per commit.

## Testing

- Unit tests live in `Visual TimerTests/`.
- UI tests live in `Visual TimerUITests/`.
- Before submitting a PR, verify the app builds with `xcodebuild` and
  manually smoke-test the four timer states.
