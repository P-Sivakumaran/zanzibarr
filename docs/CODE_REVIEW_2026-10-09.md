# Code review — 2026-10-09

Scope: current HEAD `a366747`, v1.7 release commit `090e54a` through HEAD, and fork versus upstream main. Upstream main resolves to the same HEAD; no committed fork-specific source delta. The local AGENTS.md onboarding edit is separate.

## Implementation follow-up

All seven findings below have local fixes:

- Prefetch tasks belong to a request and advance only with consumption. Dropping the request cancels its tasks and releases in-flight claims.
- Android release signing uses a persistent keystore supplied through CI secrets, with no debug-key fallback. See `ANDROID_SIGNING.md` for the required configuration; no signing key was created or uploaded during this change.
- Android updates select the universal APK, or open the release page when it is absent.
- Manual release dispatch resolves the requested tag to one SHA used by all builds and the release-notes checkout.
- History reads/mutations serialize across store instances, failed writes do not block later operations, and older snapshots cannot replace newer ones.
- Legacy resume migrates only when the resolved video's filename matches the recorded title; watching another episode preserves that legacy record.
- Repair carries the selected entry through the regenerated Flutter/Rust bridge, selects a PAR2 index by its file descriptors, and excludes other sets' recovery volumes. Retrying playback preserves the selected entry. Repair overlays for previous episodes are retained.

Regression checks: 256 Rust tests passed, Rust Clippy passed with warnings denied, Flutter analysis passed, all 175 Flutter tests passed (8 existing opt-in screenshot cases skipped), and all workflows passed actionlint. This includes native bridge coverage of the selected repair key. Built the host Rust DLL required by the bridge tests and fixed screenshot setup to honor its opt-in flag before loading macOS-only fonts.

Signing and platform release builds require configured signing secrets and the corresponding platform toolchains; they were not run locally.

## Standards and existing correctness

1. **P1 — Prefetch continues without consumer backpressure.** `rust/src/engine/nntp_source.rs:260`: each successful background fetch starts `index + depth`. A cache miss can launch downloads through EOF even after the player pauses or its HTTP request closes. This violates AGENTS.md section 4's lazy streaming rule and evicts unread segments from the bounded cache. Advance a bounded prefetch window from consumer progress and cancel it when the request ends.
2. **P1 — Android release signing is not stable.** `android/app/build.gradle.kts:32`: production uses the debug signing configuration; Android CI neither restores nor supplies a persistent key. Fresh runner builds can use different certificates, preventing installation over the previous release. Supply a stable release keystore through CI secrets.
3. **P2 — Android updater always selects arm64.** `lib/update/update_service.dart:141`: armeabi-v7a and x86_64 installations receive an incompatible APK. Select the device ABI or the published universal APK.
4. **P2 — Manual release tag does not select the build revision.** `.github/workflows/release.yml:50`: the input tag controls publication, while reusable build workflows check out the dispatch revision. Dispatch from main with an older tag can upload main's binaries under that older release. Pass the requested ref to every checkout.
5. **P2 — History mutations can overwrite one another.** `lib/player/playback_history.dart:144`: save/remove independently read, modify and replace the complete JSON value. A final player save can finish after a home-screen removal and restore the removed record; overlapping saves can lose newer progress. Serialize mutations across store instances.

## v1.8 specification and integration

6. **P2 — Legacy season-pack resume positions are discarded.** `lib/player/player_screen.dart:648`: v1.7 history has no entry key. After v1.8's picker resolves a key, exact pair lookup misses the existing position even when the user chooses the same episode. The next save removes the legacy record. Migrate only when the selected video's identity matches the legacy record.
7. **P2 — Repair does not target the selected episode's recovery set.** `rust/src/engine/repair.rs:261`: all NZB PAR2 names are passed to repair, which chooses the first non-volume index. Choosing E02 in a pack with E01 and E02 recovery sets can verify clean E01 while damaged E02 remains unplayable. Carry selection into repair and select the appropriate recovery set.

Confirmed scope limitation: the picker lists direct files and archive sets, not videos within an archive. RAR/7z handling still selects the largest inner video, so a season pack inside one archive cannot choose episodes. This is not counted as a separate bug without an explicit inner-file selection requirement.

Fork configuration: `lib/update/update_service.dart:101` still checks upstream releases. Change this before distributing independent fork releases.

At initial review, findings were based on source tracing, not hardware reproduction: 250 Rust tests passed; Clippy failed on two `chunks_exact_to_as_chunks` lints in `par2.rs`; Flutter/Dart were unavailable. The implementation follow-up above records the completed fixes and current passing checks.
