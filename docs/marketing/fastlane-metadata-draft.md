# Fastlane Metadata Draft

Re-checked: 2026-10-06 UTC. No App Store metadata upload authorized.

Prepared text lives in
[submission-draft/en-CA](../app-store/submission-draft/en-CA/), outside
`fastlane/metadata/` so it cannot be consumed as approved upload metadata.
[Submission packet](../app-store/submission-packet.md) is the field mapping.

Locale is a draft choice: historical en-CA/fallback notes need current ASC
verification. Do not create en-US or assert a name conflict based on old notes.
The name is Turn Timer; no rename decision is needed. Current `app_store` lane
skips metadata and screenshots, so a successful binary upload does not apply
this copy. File-backed `fastlane/testflight/en-US` is beta metadata, a separate
surface from App Store localization.

Before an authorized metadata write, verify selected build/screenshots, copy,
privacy answers, public URLs, IAP state, category and locale. Keep review-contact
phone/details in private ASC configuration; no credentials go in these files.
