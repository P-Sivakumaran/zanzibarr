# Fork release runbook

Release source: `P-Sivakumaran/zanzibarr`. Upstream releases are separate.
Flutter is pinned to 3.44.6; Dart dependencies and Rust dependencies use their
lockfiles. Preserve the Android signing key across all releases.

## Local Windows candidate

Run from the repository root with Flutter on PATH and Visual Studio C++ tools:

```powershell
cargo test --locked --manifest-path rust/Cargo.toml
cargo clippy --locked --manifest-path rust/Cargo.toml --all-targets -- -D warnings
flutter analyze --no-pub lib test
cargo build --locked --manifest-path rust/Cargo.toml
flutter test --no-pub
flutter build windows --release
$compiler = ./tools/windows/install-inno.ps1
./tools/windows/package.ps1 -Iscc $compiler
./tools/windows/smoke-installer.ps1
Get-FileHash dist/windows/zanzibarr-windows-x64-setup.exe -Algorithm SHA256
```

The compiler bootstrap downloads pinned Inno Setup 6.7.3 and verifies its
Authenticode signature and publisher before execution. Packaging reads the
version from pubspec and includes the full Flutter/Rust/media bundle plus
Visual Studio's x64 release CRT DLLs. App-local CRT servicing requires rebuilding
and distributing the app when runtime security updates become available.

The installer uses a stable AppId for upgrades, installs per user under
`LocalAppData/Programs/zanzibarr`, creates a Start menu entry and optional desktop
shortcut, and registers an uninstaller. It does not change file associations or
delete credentials/history. Keep the portable executable beside all bundled
DLLs and `data`; it is not a standalone single-file program.

Before promotion, test fresh install, upgrade, launch, playback/seek and uninstall
on a clean Windows user/VM. A local launch with developer tools installed does
not prove every clean-machine dependency. Sign the executable and installer
with the distribution certificate if available; no certificate is fabricated.
The scripted smoke test installs into a disposable workspace directory and
checks repeated installation, hidden process responsiveness, and uninstall.
It refuses to overwrite an existing installer registration. It does not assess
rendered UI or playback, and it stops only the process it created.

## In-app Windows updates

Settings includes **Check for updates**. Startup checks respect skipped versions;
manual checks can show them again. Windows **Update now** downloads
`zanzibarr-windows-x64-setup.exe`, verifies it against the same release's
`SHA256SUMS`, then opens the interactive installer. Setup asks to close running
applications before replacing files; its final page offers to launch the app.
Settings and history remain in their existing storage. Portable users are told
that this flow installs a per-user copy.

The installed Start menu and optional desktop shortcuts launch the app directly.
On each normal launch, Home checks for a newer release in the background, so
offline checks do not block opening the app. A newer release prompts for
**Update now**, **Later**, or **Skip this version**; installation is never
started without selecting **Update now**. No separate launcher is required.

Both assets must be attached to a published stable release on this fork.
Downloads accept only this fork's GitHub release asset URLs, have size/time
limits, and never launch after a checksum failure. SHA-256 verifies consistency
with the release manifest; it does not replace publisher signing. The current
installer is unsigned. No new stable release has been published for this work.

Before promotion, verify an actual old-to-new installation on a clean user/VM,
including settings/history retention, locked-file closure and post-install
launch. Existing builds without this button require one manual upgrade first.

## Other platforms

Linux CI pins Ubuntu 24.04 and produces a portable archive and Debian package.
The `.deb` installs under `/opt/zanzibarr`, registers a desktop entry, and declares
system runtime dependencies. It is not promised compatible with older Ubuntu,
other distributions or ARM. Validate in CI and on Ubuntu before distribution.

Android CI emits universal and split ABI APKs using the persistent secrets in
[ANDROID_SIGNING.md](ANDROID_SIGNING.md). This Windows host currently lacks
Android command-line tools; no local Android release is claimed.

iOS CI requires a macOS runner and produces an unsigned IPA. App Store/TestFlight
requires separate signing/provisioning. macOS packaging still requires the
maintainer's Mac, framework compatibility checks and Developer ID signing;
the vendored framework's effective OS minimum must be checked before advertising
compatibility. Do not upload an old upstream macOS package as a fork build.

## Draft and promote

1. Update `pubspec.yaml` and `docs/releases/vX.Y.md`; run
   `python tools/validate_release.py vX.Y`. Review the exact working tree and
   commit the intended source; build outputs stay ignored.
2. Tag the reviewed commit `vX.Y` and push the commit/tag to the fork.
   `release.yml` resolves that tag once and passes its SHA to every job.
3. Verification must pass before publishing. All platform builds must succeed;
   missing Android signing secrets block the combined release.
4. CI assembles a **draft** with Windows setup/ZIP, Linux deb/tar, Android APKs,
   unsigned iOS IPA, and `SHA256SUMS`. Inspect workflow results and artifact
   hashes. Hashes detect accidental corruption, not publisher identity.
5. Add a newly built signed macOS package only when validated, update checksums
   if adding assets, perform device checks, then publish the reviewed draft.

The updater consumes the fork's latest published release; drafts do not trigger
updates. To roll back a bad distribution, remove its latest-release status and
publish a corrected higher version; do not reuse tags or Android version codes.
