# Turn Timer Phase 3: Sync and Shared Templates Implementation Plan

> Status update, 2026-07-01: archival plan. Phase 3 was merged into the stacked
> phase branch through PR #5, with follow-up sync/widget work now staged on
> `nightly`. Use `Roadmap.md` and `docs/repo-cleanup.md` for current status.

> **For Dan / Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to work this plan task by task. This branch is stacked on `codex/turn-timer-phase2`; open the PR against that branch unless Phase 2 has merged forward.

**Goal:** Make Turn Timer templates portable across devices and people. Pro users get iCloud-backed template sync. Everyone can import/export `.turntimer` files safely, and imports are duplicated into local work instead of overwriting existing templates.

**Branch / Worktree:** `/Users/dfakkeldy/Developer/VisualTimer-turn-timer-phase3` on `codex/turn-timer-phase3`, based on `codex/turn-timer-phase2`.

**Project Context:**
- App target deployment target: iOS 18.0.
- Watch target deployment target: watchOS 11.0.
- Swift language version: 5.0.
- Current persistence: local Documents files plus `@AppStorage`/`UserDefaults`.
- Current CloudKit state: no CloudKit code or entitlements.

**Architecture:**
- Keep template editing local-first.
- Introduce `.turntimer` JSON as the portable template document format.
- Store saved templates in `Documents/Templates/<templateID>.turntimer`.
- Keep legacy `.vtgame` loading for migration/compatibility, but save new templates as `.turntimer`.
- Add CloudKit private-database sync for Pro template records using CKSyncEngine.
- Use `NSUbiquitousKeyValueStore` for lightweight settings sync.
- Treat shared files as imports: duplicate with a new local template ID and never overwrite without a deliberate save.

**Global Constraints:**
- Preserve iOS 18.0, watchOS 11.0, and Swift 5.0 settings.
- Do not introduce third-party dependencies.
- Keep quick timer and starter templates free.
- Keep Pro gating from Phase 2: free users may keep one custom saved template; Pro unlocks unlimited templates, iCloud sync, and future shared-template conveniences.
- Sync failures must be visible and non-destructive.
- Real CloudKit end-to-end testing requires a signed container in the Apple Developer account; local verification must at least compile the CloudKit code and exercise the file import/export paths with unit tests.

## Task 1: Portable `.turntimer` Documents and Local Library

**Files:**
- Create: `Visual Timer/TemplateDocument.swift`
- Create: `Visual Timer/TemplateLibraryStore.swift`
- Create: `Visual Timer/TemplateImportExport.swift`
- Modify: `Visual Timer/GameEditorViewModel.swift`
- Modify: `Visual Timer/TemplateSavePolicy.swift`
- Modify: `Visual TimerTests/Visual_TimerTests.swift`

**Steps:**
- [ ] Add `TurnTimerTemplateDocument` with `schemaVersion`, `templateID`, `title`, `game`, `createdAt`, `modifiedAt`, and `exportedAt`.
- [ ] Add `TemplateDocumentCodec` using `JSONEncoder`/`JSONDecoder` with ISO-8601 dates, sorted keys, and pretty-printing for exported files.
- [ ] Add `SavedTemplate` metadata for editor display.
- [ ] Add `TemplateLibraryStore` to read/write/delete/list `Documents/Templates/*.turntimer`.
- [ ] Add import-as-copy behavior that generates a new template ID and conflict-safe title suffix.
- [ ] Add migration from legacy `lastGameFileName` `.vtgame` into the local template library on first load.
- [ ] Update tests for codec round-trip, import-as-copy, policy behavior, and legacy migration.

**Verification:**

```bash
xcodebuild build-for-testing -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** TEST BUILD SUCCEEDED **`.

## Task 2: Editor Import, Export, Share, and Saved Templates UI

**Files:**
- Modify: `Visual Timer/GameEditorView.swift`
- Modify: `Visual Timer/GameEditorViewModel.swift`
- Modify: `Visual Timer/Theme.swift`

**Steps:**
- [ ] Show saved templates alongside starter templates.
- [ ] Add toolbar import using `.fileImporter` for `.turntimer` files.
- [ ] Add share/export for the current template through `ShareLink`.
- [ ] Apply imported templates as duplicates and show a clear success/failure alert.
- [ ] Preserve the Phase 2 Pro paywall when a free user tries to create a second saved template.
- [ ] Ensure start/play and autosave still work from the editor.

**Verification:**

```bash
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: `** BUILD SUCCEEDED **`.

## Task 3: iCloud Settings and Template Sync

**Files:**
- Create: `Visual Timer/CloudSync/CloudSyncError.swift`
- Create: `Visual Timer/CloudSync/TemplateSyncConfiguration.swift`
- Create: `Visual Timer/CloudSync/TemplateCloudRecordMapper.swift`
- Create: `Visual Timer/CloudSync/TemplateCloudSyncEngine.swift`
- Create: `Visual Timer/CloudSync/TemplateSyncStatusView.swift`
- Create: `Visual Timer/UbiquitousSettingsStore.swift`
- Create: `Visual Timer/Visual Timer.entitlements`
- Modify: `Visual Timer.xcodeproj/project.pbxproj`
- Modify: `Visual Timer/SoundManager.swift`
- Modify: `Visual Timer/MainTabView.swift`
- Modify: `Visual Timer/SettingsView.swift`

**Steps:**
- [ ] Add CloudKit entitlement for container `iCloud.Dan.Visual-Timer`.
- [ ] Add `TemplateSyncConfiguration` for private CloudKit database, custom zone, record type, and UserDefaults state keys.
- [ ] Add `TemplateCloudRecordMapper` to map `.turntimer` documents to CloudKit `Template` records.
- [ ] Add CKSyncEngine wrapper that persists state, queues local saves/deletes, applies fetched records, and resolves timestamp conflicts.
- [ ] Add account/status monitoring and a compact status view.
- [ ] Add `UbiquitousSettingsStore` to sync selected sound through `NSUbiquitousKeyValueStore`.
- [ ] Start sync from `MainTabView` only when Pro is unlocked; keep local templates usable when iCloud is unavailable.

**Verification:**

```bash
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer Watch Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

Expected: both builds end with `** BUILD SUCCEEDED **`.

## Task 4: Docs, PR, and Release Notes

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `CONTRIBUTING.md`

**Steps:**
- [ ] Document `.turntimer` files, import/export, and Pro sync.
- [ ] Document CloudKit container setup and production schema deployment.
- [ ] Document local verification limitations for CloudKit.
- [ ] Run stale-copy scans for `Visual Timer`-era user-facing strings where relevant.
- [ ] Commit the phase and open a PR against `codex/turn-timer-phase2`.

**Final Verification:**

```bash
python3 -m json.tool TurnTimer.storekit >/dev/null
xcodebuild build-for-testing -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer' -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild build -project 'Visual Timer.xcodeproj' -scheme 'Visual Timer Watch Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

Expected:
- StoreKit JSON exits 0.
- iOS build-for-testing succeeds.
- iOS app build succeeds.
- watch app build succeeds.
