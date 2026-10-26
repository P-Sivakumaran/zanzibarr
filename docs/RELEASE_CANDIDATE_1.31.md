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

The exact source at `18af3354336828540a7305e3d38d15ee1135a495` was checked out
into a separate clean build directory. Its fresh ordered gate passed:

- 290 Rust tests and Clippy with warnings denied.
- Flutter analysis, native host build, then 558 Flutter tests with 9 opt-in skips.
- 10 edition-preparation tests, 4 Android native-auditor tests, 4 release-asset
  tests, actionlint, release-input validation and whitespace checks.

The smaller Flutter count than the working preview reflects the excluded
hosted-catalogue tests. The existing debug Cargo cache was reused; the host DLL
was rebuilt against the release source and copied into the isolated checkout
for its FRB tests. The separate checkout retained a clean Git index after
normalizing generated plugin-file line endings, without any content changes.

The follow-up verification-record commit changes documentation only. Platform
builds resolve that final commit, and artifact `SOURCE.json` records its exact
SHA. Windows output is under `dist/windows/v1.31/`:

- `zanzibarr-windows-x64-setup.exe`
- `zanzibarr-windows-x64.zip`
- `SOURCE.json` and `SHA256SUMS`

Build, ZIP/bundle verification and installer-preflight results are recorded with
the GitHub draft and the local `dist/audit/v1.31/` logs. The checksum manifest
binds the packages to the source record; it does not authenticate a publisher.
No usable current-user signing certificate was present. The installed-copy
preflight requires a fresh user/VM for installer lifecycle validation, preserving
the existing installed application. No installation or public stable promotion
is part of this candidate preparation.

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
