# Fork review and release preparation — 2026-10-12

Scope: upstream v1.8 release commit `024336b` through fork HEAD `b3c0162`,
plus the existing uncommitted multi-indexer, metadata, UI and branding changes.
The local `v1.8` tag was absent, so the release commit is the pinned baseline.
Independent Standards and Spec reviews used AGENTS.md and
`docs/INDEXER_SEARCH_PLAN_2026.md`; packaging received a second focused review.

## Standards

1. **P1 distribution — updater used upstream releases.**
   `lib/update/update_service.dart` checked `envermeister/zanzibarr`, allowing a
   fork build to offer unrelated upstream artifacts, including incompatible
   Android signing certificates. Fixed to use `P-Sivakumaran/zanzibarr`, with
   a request-destination regression test.
2. **P1 packaging — Linux artifact paths disagreed.**
   Initial `.deb` integration uploaded a root tarball alongside a nested deb;
   GitHub preserves paths relative to the common ancestor. The publish job
   would not find the deb for checksums. Both now upload from `dist/linux`.

No additional confirmed correctness/security regressions in the inspected
request-owned prefetch, repair selection, metadata transport/cache, secure
profile storage, generated bindings or release revision propagation. No
speculative refactoring findings were treated as violations.

## Spec

1. **P2 — unreadable profiles appeared unconfigured.**
   `SearchScreen._loadSettings` swallowed storage/JSON errors, contrary to
   “Corrupt stored profiles surface a load failure instead of silently becoming
   an empty list.” Fixed with a distinct load-failure/retry state that blocks
   search until recovery. Added UI regression coverage.
2. **P2 — pagination used accepted rather than raw RSS count.**
   Search parsing discards items without download URLs, while source cursors
   advanced using the remaining count. A discarded-only page prematurely ended
   pagination, contrary to “Each source advances by its own raw result count,
   before deduplication.” Internal parsed pages now retain raw item count;
   public FRB DTOs are unchanged. Added mixed/empty-accepted-page coverage.

Summary: Standards 2 findings (worst P1 distribution/packaging); Spec 2 findings
(worst P2 search recovery/pagination). All four have implementation fixes.

## Validation

- Final full gate: **266 Rust tests, 218 Flutter tests passed**, with 8 existing
  opt-in screenshot cases skipped. Locked Clippy/all targets/warnings denied,
  Flutter analysis and whitespace checks pass.
- Windows release built with product/file version `1.9.0+10`; Inno Setup 6.7.3
  downloaded from its official release and publisher signature verified.
- Local Windows installer and portable ZIP built, with x64 release CRT,
  Flutter/Rust/media DLLs, font/unrar notices and SHA-256 manifest.
- Actionlint and release tag/version/notes validation pass.
- Installer smoke checks cover installation, repeated installation, hidden
  process startup/responsiveness and removal. The first harness incorrectly
  expected a visible-window handle from a hidden process; corrected to test
  the intended hidden-launch behavior and clean up only its own process.

This review does not certify physical-device playback/casting, rendered UI,
accessibility, clean-machine startup, signing or notarization. Android signing
secrets are absent in the fork. Linux/iOS artifacts need CI execution; macOS
requires the signing host. See `docs/RELEASING.md` and candidate release notes.
