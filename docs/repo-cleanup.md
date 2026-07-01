# Branch and Worktree Cleanup Map

Last audited: 2026-07-01

This ledger records the repo/worktree state found while syncing docs. Verify
live GitHub state again before deleting branches or worktrees.

## Live Branch State

| Branch | Status | Recommendation |
|---|---|---|
| `main` | Default branch and Pages source. At audit it included PR #78. | Keep. Merge docs and website fixes here. |
| `nightly` | Protected train branch, ahead of `main` with staged app work. | Promote intentionally through `weekly` after validation. |
| `weekly` | Protected beta train, behind `nightly`. | Promote from `nightly` when ready for external beta. |
| `origin/codex/fix-release-api-key-env` | Merged to `main` via PR #78. | Safe remote cleanup after confirming no local-only work. |
| `origin/codex/turn-timer-next` | Merged to `nightly` via PRs #76 and #77. | Safe remote cleanup after promotion/verification. |
| `origin/codex/ci-release-validation` | Merged to `nightly` via PR #74. | Safe remote cleanup after confirming `nightly` remains good. |
| `origin/codex/widgets-settings-share-polish` | Merged to `nightly` via PR #73. | Safe remote cleanup after confirming no unpromoted follow-up commits. |
| `origin/codex/cloudkit-history-sync-fixes` | Merged to `nightly` via PR #72. | Safe remote cleanup after confirming no unpromoted follow-up commits. |
| `origin/codex/template-editor-import-safety` | Merged to `nightly` via PR #71. | Safe remote cleanup after confirming no unpromoted follow-up commits. |
| `origin/codex/playback-session-fixes` | Merged to `nightly` via PR #70. | Safe remote cleanup after confirming no unpromoted follow-up commits. |
| `origin/codex/turn-timer-icloud-widgets-validation` | Merged to `nightly` via PR #18. | Safe remote cleanup after confirming no unpromoted follow-up commits. |
| `origin/codex/turn-timer-phase2` | Contains stranded launch assets under `docs/app-store/*` after the stacked phase PRs moved. | Save useful App Store/marketing assets in a separate PR, then delete. |
| `origin/chore/ci-release-ladder` | Merged release-ladder branch. | Safe remote cleanup. |

## Local Worktrees

| Path | Branch | Recommendation |
|---|---|---|
| `/Users/dfakkeldy/Developer/VisualTimer` | `nightly` | Keep as the primary local checkout. |
| `/Users/dfakkeldy/.codex/worktrees/33ef/VisualTimer` | `codex/docs-sync-app-store-readiness` | Current docs PR worktree. Keep until PR is merged. |
| `/Users/dfakkeldy/.codex/worktrees/e80d/VisualTimer` | `codex/fix-release-api-key-env` | Branch merged to `main`; inspect for local changes, then remove. |
| `/Users/dfakkeldy/.codex/worktrees/visualtimer-devlog-automation` | `codex/devlog-automation` | Devlog work has been merged or copied forward; inspect, then remove if clean. |
| `/Users/dfakkeldy/Developer/VisualTimer/.worktrees/turn-timer-next` | `codex/turn-timer-next` | Branch merged to `nightly`; inspect, then remove if clean. |
| `/Users/dfakkeldy/Developer/VisualTimer/.claude/worktrees/blissful-bhaskara-95269d` | `claude/blissful-bhaskara-95269d` | Contains Fastlane metadata and some app-code edits. Save metadata/marketing separately; review code edits before cleanup. |

## Salvage Items

- `origin/codex/turn-timer-phase2:docs/app-store/*`: App Store copy,
  featuring nomination, privacy policy draft, release checklist, screenshot
  plan, and support page. Marketing/copy assets should move to a separate
  marketing PR.
- `claude/blissful-bhaskara-95269d:fastlane/metadata/en-CA/*`: App Store
  metadata draft. This belongs with the marketing PR after copy review.
- `claude/blissful-bhaskara-95269d:fastlane/README.md`: Fastlane lane summary.
  The durable docs version is now maintained in `fastlane/README.md`.

## Cleanup Order

1. Merge the docs/website PR.
2. Create and merge the marketing PR from saved launch assets.
3. Promote or explicitly defer the `nightly` app stack.
4. Delete remote branches that are merged and no longer carry salvage content.
5. Remove local worktrees only after checking each has no uncommitted work.
