# Windows reliability installer - 2026-10-21

Built local candidate **1.28.0+29** from an isolated, hash-inventoried source
snapshot at `dist/candidates/v1.28/source`. Base commit is
`3080da6d039c1b7ab2ff95fb15a94743ad245998`, plus the reviewed local reliability
changes. This is not a committed or published release. The root pubspec and
unfinished v1.27 catalog changes are preserved; their main/settings routing,
source screen, tests and packaging changes were excluded in the snapshot using
the base versions. The snapshot uses its own v1.28 pubspec and release notes.

Includes HTTP/redirect/DNS/key-origin hardening, Playback Doctor with typed
native observations, cancellable repair coordination, OS-random cast
capabilities, MCP cancellation/deadlines/live authorization and existing UI.
See [reliability evidence](RELIABILITY_FOLLOWUP_2026-10-21.md).

## Artifacts

- `dist/windows/v1.28/zanzibarr-windows-x64-setup.exe`
- `dist/windows/v1.28/zanzibarr-windows-x64.zip`
- `dist/windows/v1.28/SHA256SUMS`
- `dist/windows/v1.28/SOURCE.json` (base SHA and SHA-256 for 857 source files)

The installer is unsigned. It uses the existing per-user AppId and packaging
script; full native libraries, CRT DLLs, AOT data and notices are included.
Version resource checked as 1.28.0+29 before packaging. No certificate fabricated,
no GitHub push/release and no upgrade of the user's installed application.

## Fresh candidate verification

- Release inputs validated for v1.28; Flutter 3.44.6 / Dart 3.12.2.
- Ordered gate on the isolated snapshot: 280 Rust tests, Clippy with warnings
  denied, clean Flutter analysis, native build and 445 Flutter tests passed
  (9 opt-in skips). Root whitespace check passed.
- Windows release build passed in 381.4 seconds. Existing native plugin CMake
  and conversion/shadowing warnings remain recorded in the build log.
- Initial build lacked NuGet on PATH. Used the existing local NuGet 6.14.0 after
  verifying its Valid Microsoft signature; PATH changes were process-local.
  An overlapping retry was stopped and one clean build completed successfully.
- Inno Setup 6.7.3 was bootstrapped using the existing publisher-validation script.
- Artifact SHA-256, ZIP CRC, every zipped file against its source bundle, required
  native/CRT/WebView loader/AOT/docs, and all 857 source hashes passed.
- Installer lifecycle smoke refused the existing installation registration with
  `An installed copy exists; use a fresh user/VM for the smoke test`. Existing
  registration/files were preserved. No install/reinstall/uninstall smoke pass
  or rendered UI/playback validation is claimed for this candidate.

Logs: `dist/audit/installer-1.28-*`. Reproducible package checks are in ignored
`dist/audit/verify_installer_1_28.py`. Real publisher signing, clean-user/VM
installation, physical playback/cast/accessibility and a sanitized cessation/
RAR4 reproducer remain outstanding.
