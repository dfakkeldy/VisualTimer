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
  Combine, AVFoundation, and StoreKit.
* **Current Phase:** Turn Timer Pro uses a $4.99 one-time non-consumable unlock.
  Free users keep quick timer use, built-in starter templates, basic playback,
  and one custom saved template. Pro unlocks unlimited saved templates, full
  history/export, and iCloud template sync.
* **Roadmap:** Pro value grows through richer sharing, history sync, widgets,
  and advanced customization.
* **Product ID:** The StoreKit 2 non-consumable unlock is
  `turntimer.pro.unlock`; `TurnTimer.storekit` exists for local testing.

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
* **Template Documents:** New saved templates are `.turntimer` JSON documents in
  `Documents/Templates/<templateID>.turntimer`. Legacy `.vtgame` files may still
  be loaded for migration. Prioritize robust, safe parsing. Handle malformed
  files gracefully without crashing the app, and decouple storage/parsing logic
  from the UI.
* **Monetization Boundaries:** Never gate quick timer, built-in starter
  templates, or basic playback behind Pro. Pro gates reuse and portability:
  additional saved templates, full history/export, iCloud template sync,
  sharing, widgets, and advanced customization.
* **CloudKit Sync:** Template sync uses private CloudKit container
  `iCloud.Dan.Visual-Timer`, custom zone `TurnTimerTemplates`, and record type
  `Template`. Local builds can compile the sync layer and unit-test record
  mapping, but live account/container/subscription behavior requires a signed
  build and CloudKit Dashboard schema deployment before release.
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
