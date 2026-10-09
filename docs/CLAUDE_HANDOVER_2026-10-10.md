# Claude handover — 10 October 2026

## Start here

Repository: `C:\Users\prash\Documents\src\zanzibarr` (Windows PowerShell).
Fork: https://github.com/P-Sivakumaran/zanzibarr
Branch: `main`; base HEAD: `a3667474072aa1529c62a6e07d087ef2dae3e9ff`.
Version remains `1.8.0+9`. This handover and the implementation are included in the 10 October commit prepared for `origin/main` at the user's request. Use `git log -1` and `git status --short` to confirm the checkout state. No release or tag was created.

Read `AGENTS.md` first, then this file, `docs/CODE_REVIEW_2026-10-09.md`, `docs/UI_UX_REVIEW_2026-10-10.md` (including implementation follow-ups), and `docs/ANDROID_SIGNING.md`. Inspect `git status --short` and the existing diff before editing. Preserve all existing work. Current fork conversations are in English; upstream Turkish/Mac environment notes are historical.

The user requested cloning, code review, implementation of all findings, UI/UX review, implementation, this handover, and then a push to the fork. Both implementation batches are complete. Further feature or release work requires its own scope.

## Product and constraints

Flutter UI and Rust NNTP engine communicate through flutter_rust_bridge 2.12.0. NZB video streams lazily through a local HTTP range server into media_kit/libmpv. Targets are desktop, Android/Android TV, and iOS; no web target.

Keep decoded yEnc offsets authoritative, network fetching lazy and request-owned, and LAN casting token-gated. Never include provider credentials/API keys in source, logs, files, or command arguments. Use `TESTPASS123` for test placeholders. Regenerate FRB when native APIs change. Preserve the custom libmpv and vendored unrar work.

## Implemented code-review fixes

| Area | Result and principal files |
| --- | --- |
| Prefetch | Bounded request-owned `PrefetchWindow`/JoinSet; cancellation aborts tasks and RAII clears inflight claims. No recursive chain to EOF. `rust/src/engine/nntp_source.rs`. |
| Android signing | Persistent environment/secrets configuration; removed debug fallback. `android/app/build.gradle.kts`, workflows, signing document. |
| Android OTA | Prefer universal APK, fall back to release page. `lib/update/update_service.dart`. |
| Release provenance | Resolve requested tag to immutable SHA and pass it through reusable builders and publishing. `.github/workflows/*.yml`. |
| History races | Serialize operations across store instances; older timestamps cannot overwrite newer entries. `lib/player/playback_history.dart`. |
| Legacy resume | Migrate keyless resume only when resolved filename/title matches selected episode. Playback startup guard/player. |
| PAR2 selection | Pass selected entry key through repair bridge; choose index by FileDesc coverage, constrain recovery volumes to matching set, preserve overlays and selection during retry. Rust repair/API and generated bindings. |

Also fixed current Clippy `as_chunks` lints and prevented disabled screenshot tests from attempting Mac-specific font setup.

## Implemented UI/UX changes

| Area | Result |
| --- | --- |
| Mobile controls | Audio-track access at every width; labeled overflow for secondary actions below 600px. |
| Touch targets | Shared player icons, track menus, speed, and history removal use at least 48px targets; explicit semantic tap action; elapsed time reflows. |
| Setup/recovery | Missing provider credentials open targeted setup and retain pending NZB/episode. Player recovery retains selection. Added a single-connection, 15-second provider check without fetching media or saving credentials. |
| Search | Pagination, counts, deduplication, original-query preservation, same-offset retry, stale-response guards, clear cancellation, and focus on new pages. Changing indexer clears old results. |
| Settings drafts | Targeted provider/indexer forms; Save/Discard/Keep editing; failed saves retain drafts; scroll to first invalid field; loading timeouts/retry and disposal cleanup. |
| Filenames | Wrapped episode names and visible Cancel; selectable full-name details reachable by touch, keyboard, and remote. |
| Readability | Larger metadata, stronger opacity, narrow reflow, TV minimum text scale 1.25 while preserving user scaling; expanded dropdowns work at 200% text. |
| Errors | Friendly explanations, settings/retry actions, separately selectable sanitized diagnostics, history read retry, and deletion failure preservation. |

Principal UI files: `lib/main.dart`, `lib/player/{entry_picker,gyuni_player_controls,player_screen}.dart`, `lib/search/search_screen.dart`, `lib/settings/settings_screen.dart`, and new `lib/ui/error_feedback.dart`.

Native provider check: `rust/src/api/streaming.rs` (`check_provider`) and regenerated FRB files. Safe static error categories do not echo server response text. Search diagnostics additionally remove the active API key.

Localization: new strings across 14 ARBs and regenerated Dart. English/Turkish supplied; remaining locales use English fallback consistent with existing convention. Existing translations preserved. `intl ^0.20.2` became a direct dependency at its existing locked version; no dependency version upgrades.

Tests include new `test/ux_flows_test.dart` (12 flows), phone controls at 360/390px and 200% text, native provider error categorization, history races/failures, and repair/prefetch regressions. Existing D-pad tests pass. `HomeScreen` has injected stores and optional player route builder so tests avoid real playback.

## Latest verification

These results apply to the final application code, superseding earlier counts in review history:

| Check | Result |
| --- | --- |
| Rust tests, locked | **257 passed** |
| Clippy, all targets, warnings denied | Passed |
| Host Rust build, locked | Passed |
| Flutter analysis, lib/test | No issues |
| Flutter tests | **190 passed; 8 existing opt-in screenshot cases skipped** |
| Git whitespace check | Passed |
| Actionlint | Passed during the workflow-fix batch; workflows unchanged in UX batch |

No live provider, physical phone/TV, screen-reader, GUI playback, or release-platform build was tested. Contrast compliance was not measured; this is not accessibility certification. Existing screenshots predate the UX changes.

## Toolchain and repeatable commands

Flutter 3.44.6 / Dart 3.12.2: `C:\Users\prash\Documents\src\.tools\flutter\bin` (not system PATH).
FRB generator 2.12.0: `C:\Users\prash\Documents\src\.tools\frb\bin\flutter_rust_bridge_codegen.exe`.
Rust/Cargo are available on PATH.

From the repository root:

```powershell
cargo test --locked --manifest-path rust/Cargo.toml
cargo clippy --locked --manifest-path rust/Cargo.toml --all-targets -- -D warnings
cargo build --locked --manifest-path rust/Cargo.toml
C:\Users\prash\Documents\src\.tools\flutter\bin\flutter.bat analyze --no-pub lib test
C:\Users\prash\Documents\src\.tools\flutter\bin\flutter.bat test --no-pub
git diff --check
```

Build Rust before Flutter bridge tests: they need `rust/target/debug/rust_lib_zanzibarr.dll`; `cargo test` alone does not produce that top-level DLL.

For native API changes:

```powershell
$env:PATH = 'C:\Users\prash\Documents\src\.tools\flutter\bin;' + $env:PATH
C:\Users\prash\Documents\src\.tools\frb\bin\flutter_rust_bridge_codegen.exe generate
```

One-shot edit scripts under sibling `.tools` (`implement-zanzibarr-*`, `finish-zanzibarr-ux.py`, `polish-zanzibarr-ux.py`) are non-idempotent: **do not rerun**. Formatting/EOL cleanup helpers already ran; avoid blanket formatting unrelated code. Final Flutter evidence is `.tools/zanzibarr-ux-verified.log`; older iterative logs contain resolved failures. No system PATH changes were made.

## Remaining work and known limits

1. Independently inspect the existing diff before further changes. Both review documents retain original findings plus implementation notes.
2. Smoke-test on Android phone/TV: pending provider/indexer setup, wrong credentials/offline recovery, pagination/D-pad focus, large text/RTL/long filenames, history failures, selected-episode repair, pause/cancellation network behavior, and casting.
3. Check TalkBack/NVDA and actual contrast; regenerate screenshots using a suitable environment. Screenshot tests are opt-in and retain Mac-specific font assumptions when enabled.
4. Configure persistent Android signing with the original certificate where upgrades are required. Required secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Local builds can use `ANDROID_KEYSTORE_PATH` instead of base64. No key was created/uploaded and no secrets configured. Historical changing debug certificates cannot be reconstructed.
5. Before distributing the fork independently, review the OTA repository endpoint in `lib/update/update_service.dart`: it still checks upstream releases. Run actual platform builds before a release.
6. The archive picker selects direct files/archive sets, not individual inner archive videos; RAR/7z still chooses the largest inner video.
7. Upstream Gran.Torino RAR4 diagnostic/root-cause issue remains open; these changes do not resolve it. Mac lipo/LINKEDIT notes remain relevant only to Mac builds.

## Suggested initial prompt

> Continue in C:\Users\prash\Documents\src\zanzibarr. Read AGENTS.md and docs/CLAUDE_HANDOVER_2026-10-10.md first, then inspect git status and the complete existing diff. Preserve all uncommitted changes. The seven code-review fixes and eight UI/UX improvements are implemented and verified locally; use the handover's remaining checks to orient further work. Report your assessment before assuming a new feature or release scope.
