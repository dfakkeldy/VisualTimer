# Turn Timer Marketing Plan

Re-checked: 2026-10-06 UTC

Status: preparation only; no posts, featuring nomination or store submission
authorized. Readiness and candidate acceptance precede promotion.

## Positioning

Turn Timer makes time visible for real-world sequences: game turns, recipe
steps, classroom stations, meeting speakers, plant watering zones, focus blocks,
and household routines. The wedge is fair, visible turns for game night, with
natural expansion into routines that repeat.

The message should stay practical:

- Save the timer paths you reuse.
- See the current round and what comes next.
- Keep quick timer and starter templates free.
- Pay once for Pro reuse and portability.
- No account, ads, tracking, or subscription.

Avoid medical or accessibility claims that imply clinical validation. It is fine
to say the visual countdown can help people who prefer seeing time instead of
reading numbers; avoid promising ADHD, autism, therapy, classroom, or education
outcomes unless future evidence supports that language.

## Audience Segments

| Segment | Hook | Proof needed |
|---|---|---|
| Board games and family game night | Keep turns fair and visible | Screenshot 1 should show a live Game Night template |
| Routines and focus blocks | Chain steps without rebuilding a timer | Template editor and saved-template screenshots |
| Cooking | Time recipe steps one at a time | Recipe screenshot set after launch |
| Classrooms | Rotate stations calmly | Needs careful education/privacy copy and teacher feedback |
| Meetings | Time speakers and agenda items | Meeting Agenda screenshot set |
| Plant care | Make watering zones repeatable | Useful secondary campaign, not the launch wedge |

## Launch Funnel

1. Resolve release blockers in [readiness](../app-store/readiness.md).
2. Select a payload, pass strict native CI and internal acceptance.
3. With exact promotion/distribution authorization, pass external weekly
   acceptance before promoting to main.
4. Capture the candidate using [screenshot manifest](screenshot-plan.md).
5. Verify current ASC fields and reconcile [submission packet](../app-store/submission-packet.md).
6. Obtain exact authorization for store writes, pricing/legal declarations,
   upload/submission/release. Binary lanes skip store copy and screenshots.
7. Verify actual store approval and territory availability before a public push.
8. Publish launch/community/featuring material only when explicitly authorized.

Support/privacy URLs returned HTTPS 200 on 6 Oct. Historic passed launch dates
are not a current release schedule. No date is ratified by this audit.

## Channel Plan

### App Store

Primary acquisition surface. Use the app name/subtitle/keywords to balance the
Turn Timer identity with discoverable words like timer, countdown, turns,
routine, and classroom. Do not duplicate important words between title,
subtitle, and keyword field unless there is room.

### GitHub Pages and Devlog

Use the public website as the source for build-in-public updates, support links,
and launch readiness context. The devlog should remain factual and commit-based.

### Communities

Use discussion-first posts. Good angles:

- "How do you handle fair turn timing at game night?"
- "What makes reusable visual timers useful or annoying?"
- "I am building a visual timer around saved routines; what templates would you
  expect?"

Avoid drive-by promotional posts.

### Featuring

Submit a featuring nomination only after screenshots, support/privacy URLs, and
TestFlight/App Store links are ready. Use `docs/marketing/featuring-nomination.md`.

## Copy Rules

- Prefer "visual rounds", "turns", "routines", "templates", "history", and
  "pay once".
- Do not say widgets or watch features ship until the promoted build proves
  them.
- Do not mention price in screenshots.
- Do not claim "no ads/no tracking" unless the final binary still has no
  third-party analytics, ads, or tracking SDKs.
- Keep privacy copy aligned with the App Privacy labels and privacy policy.

## Metrics to Watch

- Product page conversion.
- First-run template start rate.
- Custom template save rate.
- Free-to-Pro conversion.
- Restore Purchase support volume.
- Reviews mentioning price, setup, widgets, sync, or watch.

## Saved Inputs

This plan preserves useful draft work from two places:

- `origin/codex/turn-timer-phase2:docs/app-store/*`
- `claude/blissful-bhaskara-95269d:fastlane/metadata/en-CA/*`

Those inputs are revised here as marketing drafts, not treated as final
upload-ready metadata.
