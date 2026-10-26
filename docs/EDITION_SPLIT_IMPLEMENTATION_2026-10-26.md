# Clean and Restricted Windows development candidates

Implemented against base `d8f4ac05e72db7df9cfcd97e1c39c97363c14b1f` plus the recorded working changes. This is a partial implementation of the [edition design](EDITION_SPLIT_DESIGN_2026-10-23.md), not a completed release or a content-safety certification.

## Implemented behavior

- Separate Windows executable names, installer GUIDs, installation directories and window identities. The existing Legacy application keeps its original identity and data keys.
- Separate secure-storage namespaces, support directories, browser profiles and native temporary roots. New editions neither import Legacy data nor start its MCP server. Their updater refuses the Legacy release channel; updates remain disabled until independently verified edition channels exist.
- Both entrypoints check the loaded native edition and policy before showing application content. The bundle audit checks a unique compiled Dart marker, native exports, source-manifest binding and artifact hashes. Clean also requires an explicit allowlist for its project import graph and scans packaged files for known restricted endpoints.
- Restricted starts locked, requests Windows device authentication, invalidates late or timed-out requests, relocks on background/focus loss or four-hour expiry, and provides a manual Lock control. Relocking dispatches player stop and native cancellation before disposing protected views. Native stream/search/download/repair entrypoints reject locked access. Device authentication establishes local-user access; it does not establish age or legal eligibility.
- Clean exposes an empty approved-library view. Missing, stale, conflicting or unverifiable classifications fail closed. Raw media, indexer search, adult catalogues, chat and plugin routes are absent from its Dart application graph; native media admission remains closed. The classification model is tested but has no production trusted-catalogue adapter or media-provenance binding yet. Consequently Clean cannot currently browse or play films.
- Immutable source preparation defaults to Clean. Restricted must be selected explicitly. A manual Windows CI workflow builds and audits one development candidate at a time without publishing.

The root application preserves unfinished hosted-catalogue and legal work. Restricted snapshots deliberately substitute the existing adult-library route and exclude the unfinished hosted catalogue. This is not a claim to implement additional hosted playback integrations.

## Verification

The ordered shared gate passed: **284 Rust tests**, Clippy with warnings denied, Flutter analysis, native host build and **535 Flutter tests with 10 opt-in skips**. Final Dart fixes were followed by fresh analysis and the full Flutter suite; unchanged native code retained the passing Rust evidence. Ten source-preparation regressions and actionlint passed. Both actual compiled profiles passed their four native admission tests each (eight profile checks total). Both complete bundles passed source/native/AOT identity audits; all 60 Clean and 62 Restricted packaged files matched their portable ZIP entries byte for byte. Installer/ZIP SHA-256 checks and ZIP CRC checks passed. Installer executables were not run.

Standards review found repeated native initialization, delayed playback stopping and uncancelled authentication timeouts; these were fixed. Specification review found late background unlock, shared native temporary paths and a weak artifact-marker check; these were fixed. Final reviews reported no further confirmed blocking code defects within this implemented slice. The incomplete acceptance items below remain substantive.

Both Windows profiles compiled the new WinRT authentication helper. Final source snapshots are `dist/editions/clean-08` and `dist/editions/restricted-08`. Their source manifests record every input hash, the base revision and dirty working state. Final AOT compilation reused the earlier native build directories only after comparing every native, Windows, asset and dependency input hash. The final Dart targets came from the final snapshots; package aliases and exact paths are recorded in `dist/audit/edition-split/*08-cache-provenance.json`. Both final builds passed. Review bundles and packages are under `dist/editions/artifacts/{clean,restricted}-08/`.

Logs are under `dist/audit/edition-split/`, including `rust-test.log`, `clippy.log`, `native-build.log`, `verified-analyze.log`, `verified-flutter-test.log`, final cached build logs, preparation/audit reports and packaging logs. The candidates retain source version **1.27.0+28** and are unsigned development artifacts, not a versioned public release.

## Remaining work before release

1. Implement a trusted Clean catalogue and bind allowed canonical titles to verified media provenance. A rating or filename cannot establish the safety of arbitrary NZB contents. Keep playback closed until that boundary exists.
2. Validate actual Windows authentication, cancellation and relocking while playing, clean-user co-installation, independent browser/storage state and same-edition upgrades. Include accessibility, remote navigation and real device playback. Compilation and widget tests do not establish those results.
3. Implement signed, edition-specific update manifests, publisher verification, rollback policy and promotion gates. Both new edition updaters intentionally remain disabled.
4. Resolve operator identity/contact/territories, redistribution/native-library permissions, provider eligibility and any applicable age-assurance requirements. Final edition-specific legal copy cannot be inferred from NZBgeek terms. Device authentication is not age verification.
5. Finish distinct edition icon badges, then implement and validate identities, authentication and isolation for other supported platforms before offering those edition builds.

The installed application and current playback were preserved. No installation, commit, push, tag or publication was performed by this implementation.
