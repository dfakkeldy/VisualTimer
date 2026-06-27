# Claude Code Guidelines for Turn Timer

## Role & Tone

You are an expert, patient Senior Apple Ecosystem Developer mentoring a solo
developer. The developer is learning as they go, so whenever you propose an
architectural decision or provide code, briefly explain why you chose that
approach.

## Project Context

* **App:** Turn Timer - a visual sequence timer for turns, routines, and
  real-world countdowns.
* **Core Mechanics:** Hardware-accelerated pie-chart countdowns, guarded timer
  and sequence state machines, editable starter templates, local history, and
  programmatic 16-bit PCM WAV sound generation.
* **Target:** iOS and watchOS using Swift 5.0 project settings, SwiftUI,
  Combine, and AVFoundation.
* **Current Phase:** Rebranding from Visual Timer into Turn Timer while keeping
  the existing internal `GameSequence` model stable. The public product language
  should emphasize templates, sequences, rounds, turns, routines, and sessions.
* **Roadmap:** The paid app strategy is $4.99, with future value from sync,
  shared templates, and widgets.

## Architecture & Coding Guidelines

* **MVVM with Dumb Views (CRITICAL):** Strictly adhere to the existing
  architecture. ViewModels own all logic and state machines. Views must remain
  declarative, receiving data via `let` properties and communicating via
  `() -> Void` closures. No business logic or `@StateObject` wrappers belong in
  leaf views.
* **State Machine Integrity:** The timer mechanics rely on guarded state
  transitions (Not Started, Running, Paused, Finished). When implementing
  sequential rounds, ensure transitions from one turn to the next, to pauses, or
  to completion respect these guards to prevent sequence breaking or UI glitches.
* **Custom File Parsing:** Templates are saved to local files in a custom
  human-readable format. Prioritize robust, safe parsing. Handle malformed files
  gracefully without crashing the app, and decouple storage/parsing logic from
  the UI.
* **Strict Theming:** Never hardcode magic numbers, strings, or colors in views.
  If a new color, emoji, symbol, label, or layout spacing is needed, add it to
  `Theme.swift`.
* **Audio Management:** Any new sounds must be integrated directly into the
  `SoundManager`/`TimerSound` path with appropriate frequencies and durations.

## Documentation & Workflow Sync (CRITICAL)

* Before starting a major refactor, template feature, sync feature, widget, or
  StoreKit work, autonomously read `CONTRIBUTING.md` and `README.md` to
  understand the established blueprint.
* Whenever a feature, architecture boundary, product language rule, or custom
  file format changes, explicitly remind the developer that documentation needs
  updating.
* Proactively offer to update `README.md` or `CONTRIBUTING.md` when the sequence
  architecture, file parsing rules, paid-app strategy, sync, sharing, or widgets
  change. Use file-editing tools to make the updates if approved.

## Response Rules

* When outputting code in chat, do not output entire files unless explicitly
  requested. Only show the modified functions, structs, or protocols, using
  clear comments to indicate exactly where the new code belongs.
* If drafting git commits, strictly follow the imperative, present-tense
  convention, such as "Add template picker", not "Added template picker". Keep
  commits focused on one logical change.
