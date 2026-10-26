# Version 1.31 Windows candidate

The user approved the rendered UI candidate and requested a push and new version.
The source version advances to 1.31.0+32, following the earlier 1.30.0+31 local
candidate. The approved interface and its completed edition/stack/legal
dependencies are included. Existing running applications are preserved.

## Source boundaries

The release commit excludes the unfinished `lib/catalog` hosted-video feature,
its tests, screenshots, guide and v1.27 notes. The default catalogue composition
uses the existing adult metadata library. Its opt-in behavior and provider
requirements are unchanged. The local working files for unfinished catalogue
development remain intact; the Git index selects the existing metadata route
and the corresponding Settings description for this commit. The unfinished
hosted guide is not added to packaging.

No public Clean/Restricted product is claimed. Those Windows profiles remain
development candidates with the limitations documented in
`EDITION_SPLIT_IMPLEMENTATION_2026-10-26.md`. Clean media admission stays closed.
Legal documents are drafts, and automatic installation remains unavailable
without real publisher trust pins.

## Verification and artifacts

The preceding UI working tree passed 290 Rust tests, Clippy, Flutter analysis,
native host build and 574 Flutter tests with 10 opt-in skips. This is background
evidence; the exact release source is independently verified before packaging.

Final source review, gate results, artifact paths and checksums will be recorded
here after they complete. Windows artifacts are prepared as an unsigned draft;
no installation or public stable promotion is part of candidate preparation.

## Standards

Independent exact-index review found no blocking standards defects in the UI,
edition/native boundaries, credential migration, updater checks or release
workflow. One nonblocking judgment call remains: Settings groups are assembled
with positional item indices. The current routes are correct; named groups
would make future additions easier to maintain.

## Spec

Independent review found the approved interface, sample-preview isolation and
hosted-catalogue exclusion consistent with the documented scope. It found stale
README links to v1.25; these were corrected to v1.31 and this verification ledger.
Final acceptance still requires verification and packaging of this exact source.

Review summary: Standards — one nonblocking maintainability heuristic; Spec —
one stale-documentation finding corrected. Neither axis found a blocking code
defect. Signing, clean-user and physical-device gates remain disclosed limits.
