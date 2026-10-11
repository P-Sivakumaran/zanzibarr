# AGENTS.md — zanzibarr

**Living context document for every AI coding agent (Kimi, Claude, ChatGPT/Codex, …) that works on this repository.**

> ## Agent protocol — read first
> 1. Read this file **fully** before touching any code, then follow the onboarding order in §10.
> 2. **Keep this file alive.** At the end of every work session, before handing off: update §6 (Current state), §7 (Known issues / watch list), §8 (Roadmap) and append a dated entry to §9 (History). This file is the project's memory across different AI tools and sessions — if you skip the update, the next agent starts blind.
> 3. Obey the standing rules in §4. Each one was earned through a real production bug.

---

## 1. Project snapshot

- **zanzibarr** streams video from Usenet NZBs **without downloading**: seekable playback straight from NNTP segments, through a local range-aware HTTP server, into libmpv.
- Repo: <https://github.com/envermeister/zanzibarr> (public) · Site: <https://zanzibarr.app> (GitHub Pages, served from `docs/`, download links point at `releases/latest`)
- Local working copy: `~/Downloads/USENET/Zanzibarr` (renamed 2026-09-08; formerly `~/Downloads/CodexGPT/UseNews`). Sibling fork: **Usetopia** at `~/Downloads/USENET/Usetopia` (repo `envermeister/usetopia`) — a separate app developed with Claude/ChatGPT; never touch it during zanzibarr work.
- Upstream release: **v1.8**. Fork candidate: **v1.9** (`pubspec.yaml` → `1.9.0+10`); candidate work is not a published release — see §6.
- Platforms: **macOS** (arm64, signed), **Windows**, **Android** (phone + Android TV leanback), **Linux** (new), **iOS** (unsigned package; no TestFlight yet). Web is intentionally out of scope (no raw NNTP in browsers).
- The owner communicates in **Turkish** → always reply in Turkish. Repo artifacts (code comments, docs, release notes) in **English**. Commit messages: **Turkish conventional commits** (`feat(engine): …`, `fix(android): …`).
- Donations: buymeacoffee.com/envermeister + ko-fi.com/envermeister (referenced in README/site only).

## 2. Architecture

- **UI:** Flutter (one codebase, no Electron). Entry `lib/main.dart`.
- **Engine:** Rust, bridged via `flutter_rust_bridge` (FRB). Crate root `rust/`, FRB glue generated into `lib/src/rust/`. After changing any `rust/src/api/*.rs` signature, regenerate with `flutter_rust_bridge_codegen generate`.
- **Player:** `media_kit` / libmpv, with **custom-built libmpv 0.41 + FFmpeg 8.1.2 + libplacebo** (TrueHD/Atmos, DTS-HD MA, AV1, Dolby Vision Profile 5). Android build produced in the separate repo `envermeister/libmpv-android-video-build` (local: `~/Downloads/USENET/libmpv-android-video-build`); vendored into `vendor/media_kit_libs_*_video/`.

```
 .nzb ─▶ NZB parser ─▶ segment map (yEnc begin/end)        rust/src/engine/nzb.rs, yenc.rs
                          │
             NNTP pool (TLS, pipelined, semaphore)          nntp/connection.rs, nntp/pool.rs
                          │
         fetch → yEnc decode → CRC32 verify                 locator.rs, seekable_decode.rs
                          │
   archive layer (RAR4/RAR5, 7z STORE/LZMA/AES,             archive.rs, rar.rs, rarcrypt.rs,
   compressed RAR via vendored libunrar)                    sevenzip.rs, rarcompressed.rs
                          │
   PAR2 verify + Reed-Solomon repair overlay                par2.rs, repair.rs
                          │
        localhost HTTP server (Range requests)              http.rs, server.rs
                          │
                 libmpv / media_kit                         lib/player/*
```

Key directories:

- `rust/src/engine/` — the whole streaming engine (see map above). `rust/src/api/` — FRB-exposed API surface (`streaming.rs`, `search.rs`, `repair.rs`, `simple.rs`).
- `lib/player/` — player screen, controls (`gyuni_player_controls.dart`), keyboard/remote handling, Smart Canvas, subtitle overlay, PiP, media prefs, playback history ("continue watching").
- `lib/settings/` — provider (NNTP) settings, indexer settings, UI prefs. `lib/search/` — Newznab search UI. `lib/cast/` — Chromecast/AirPlay discovery + session control (`dart_cast`). `lib/update/update_service.dart` — OTA update check. `lib/l10n/` — 14 locales (en default, tr, es, de, fr, pt, it, ru, zh, ja, ko, hi, ar, fa; ar/fa RTL).
- `vendor/` — `unrar-rs` + `unrar-sys` (**patched fork**, see §5), `media_kit_libs_android_video`, `media_kit_libs_macos_video`.
- `rust_builder/` — cargokit bridge. `tools/` — `zanzibarr-cli` (NNTP/keychain CLI), asset scripts.
- `docs/` — website (`index.html`, Vue via CDN), `docs/releases/vX.Y.md` (release notes, referenced by CI `body_path`), `docs/screenshots/`.
- `.github/workflows/` — `android|windows|linux|ios-build.yml` (`workflow_dispatch` + reusable `workflow_call`) and `release.yml` (see §5).

## 3. Provider, indexer, accounts

- Provider of record: **Easynews**, `secure-eu.news.easynews.com:563` (TLS). Connection limit configured to 60 — plan support for that number was never verified; lower if auth/throttle errors appear.
- NNTP engine (`:563`) and the Easynews **web search API** are separate code paths; web API integration is still on the roadmap.
- Indexer: any **Newznab-compatible** one (developed against Miatrix): `?t=caps` discovery → search → release-name parser (resolution/codec/HDR/audio/group) → NZB straight into the player. Cross-indexer dedup is still open.
- Optional OMDb title/IMDb lookup and source-labelled ratings are implemented
  locally in the fork; TMDB browsing/ID translation remains planned.

## 4. Standing rules (non-negotiable)

1. **Secrets:** never in code, tests, files, CLI args, logs or `Debug` output. Credentials live only in the OS keychain (`flutter_secure_storage` in-app, `keyring` crate in the CLI, `rpassword` prompt). Test fixtures may use only the placeholder password `TESTPASS123`.
2. **Seek offsets come only from decoded yEnc `begin/end`** (`YencPart` / `record_part`). NZB `bytes` (encoded article size) is used for download planning/progress only — never for offsets.
3. **Lazy streaming:** serve segment-by-segment (`locator.decoded_span`); when the player pauses, network activity must stop. Never pre-fetch a whole open-ended range.
4. **LAN exposure is token-gated:** the engine's second listener (`bind_lan`, for casting) only serves paths under `/cast/<128-bit-token>/`; loopback stays unauthenticated. Never serve LAN requests without the token check.
5. **Test discipline:** every engine module is proven with offline unit tests before integration. Before calling any work done, the full gate must pass (§5). Fixture archives live in `rust/tests/fixtures/`.
6. **Minimal diffs**, match surrounding style; no speculative refactors. Don't touch unrelated files.
7. **Update this file** at the end of the session (see protocol at top).

## 5. Build, test, release

Verification gate (run all four, in order):

```bash
cd rust && cargo test                      # ~250 tests (run to confirm current count)
cd rust && cargo clippy --all-targets -- -D warnings
flutter analyze lib test
flutter test                               # ~166 tests
```

Release pipeline (v1.4+):

1. Write `docs/releases/vX.Y.md` (English release notes — CI uses it as `body_path`).
2. Bump `pubspec.yaml` version, commit, `git tag vX.Y`, `git push --tags`.
3. `release.yml` builds Windows / Android / Linux / iOS via the reusable `*-build.yml` workflows and publishes assets with `softprops/action-gh-release`.
4. **macOS asset is built locally** (signing requires the local keychain — paid dev cert, team `8665FDLXA6`, `keychain-access-groups` entitlement; ad-hoc signing fails with `-34018`) and uploaded manually: `gh release upload vX.Y dist/macos/zanzibarr-macos-arm64.zip`.
   - **Xcode 27 (macOS 26.6) gotchas:** (a) `lipo <file> -verify_arch <a1> <a2>` is broken system-wide ("requires exactly one input file") — put a shim earlier in `PATH` that splits multi-arch verify into per-arch calls (recipe in §7), then `PATH=/tmp/zanzibarr-lipo-shim:$PATH flutter build macos --release`; (b) deployment targets below 12.0 are rejected — project + pods are pinned to 12.0 (see `macos/Podfile` post_install). Package with `ditto -c -k --sequesterRsrc --keepParent zanzibarr.app dist/macos/zanzibarr-macos-arm64.zip`. Note: bundled homebrew Mpv.framework is built for macOS 26, so the app effectively requires a recent macOS regardless of the 12.0 deployment target.
5. Sync `docs/index.html` (site) if features/roadmap changed — download URLs are `releases/latest`-based, so no link edits needed.

Debug hooks (developer-only, env vars): `ZANZIBARR_DEBUG_NZB=/path/to.nzb` (open NZB directly at startup), `ZANZIBARR_DEBUG_PROBE=1` (dump video params + audio tracks to stdout).

## 6. Current state (updated 2026-10-12)

**2026-10-12 release preparation:** v1.9 fork candidate adds per-user Windows
Inno Setup installer + portable ZIP with app-local CRT, Ubuntu 24.04 `.deb`,
automated verification, tag/version/notes checks, checksums and draft release
publication. Updater now targets `P-Sivakumaran/zanzibarr`. Review fixes surface
indexer storage failures with retry and advance source cursors by raw RSS item
count. See `docs/RELEASING.md`, `docs/releases/v1.9.md` and the dated review.
Android repository signing secrets are currently absent; combined release CI
cannot complete until configured. Existing user branding/metadata work preserved.
Final source gate: **266 Rust + 218 Flutter tests passed**, 8 opt-in screenshots
skipped; Clippy/analyze/actionlint clean. Windows executable, setup and portable
ZIP built at `1.9.0+10`. Installer smoke covers repeated install, hidden startup
and uninstall, not rendered UI or live playback.
Candidate source is committed on `release/v1.9-packaging`. Push/PR/platform CI
are blocked by the current GitHub OAuth token lacking `workflow` scope; SSH
authentication also fails. Refresh with `gh auth refresh -h github.com -s workflow`,
then push the branch, create the draft PR, and dispatch Linux/iOS build workflows.
No tag, PR or remote release was created during preparation.

**Fork multi-indexer continuation:** Claude's interrupted implementation has
been resumed. Phases 1–5 of `docs/INDEXER_SEARCH_PLAN_2026.md` are now
implemented locally, including test migration, independent source cursors,
stable download source IDs, deterministic deduplication, profile ordering,
search toggles, draft/save recovery, and D-pad dialog navigation. Existing
logo/font/background edits are preserved. Phase 4 adds explicit OMDb
title/IMDb lookup, synopsis and available source-labelled IMDb/Rotten
Tomatoes/Metacritic scores, plus manual IMDb/TVDB search. The optional key
uses secure storage; release search works without it. Capability-aware
native requests use supported IDs and season/episode parameters, with full
title fallback when unavailable. Editing the query clears the selected ID;
pagination preserves it. No release/tag created.

OMDb settings now offers Test API key against the unsaved draft, bypassing
cached metadata without saving credentials. The outlined key field validates
key-only input, trims outer whitespace, supports visibility toggling, and
clears test status after edits. Success, rejected key, quota and connection
failures have static, readable messages. Windows debug app is rebuilt for
local use; live OMDb account verification remains user-triggered.

Continuation gate: **265 Rust tests and 216 Flutter tests passed**, with 8
existing opt-in screenshot cases skipped. Clippy (locked, all targets,
warnings denied), Flutter analysis, and host native build passed.

The owner requested committing and pushing the completed review fixes, UX implementation, and Claude handover to the fork's `origin/main`. See `docs/CLAUDE_HANDOVER_2026-10-10.md` for continuation details. No release/tag is being created; device/signing checks in sections 7–8 remain outstanding.

All eight UI/UX review findings have local implementations: mobile audio access and 48px player targets; provider/indexer setup that returns to the pending task; a single-connection TLS provider test; unsaved credential protection; paginated search with retry/dedup/focus handling; full filename inspection; more readable metadata and a directional-navigation text profile; actionable errors with sanitized diagnostic disclosures and history failure feedback. Review and implementation notes: `docs/UI_UX_REVIEW_2026-10-10.md`. Live device and screen-reader testing remains outstanding.

Final UX gate: **257 Rust tests and 190 Flutter tests passed**, with the same 8 opt-in screenshot tests skipped. Clippy (`--locked --all-targets -- -D warnings`), Flutter analysis (`--no-pub lib test`), native host build, and `git diff --check` passed. Previous actionlint validation remains applicable; workflows were not changed during the UX implementation.

Fork review fixes are implemented locally: bounded request-owned prefetch; persistent Android signing configuration; universal Android updates; release-tag SHA propagation; serialized history operations; filename-checked legacy resume migration; selected-episode PAR2 repair with regenerated FRB bindings. See `docs/CODE_REVIEW_2026-10-09.md` and `docs/ANDROID_SIGNING.md`. Full gate passes: 256 Rust tests, Clippy with warnings denied, Flutter analysis, 175 Flutter tests (8 existing opt-in screenshot tests skipped), and actionlint. Upstream main matched fork HEAD `a366747` at review time.

Local toolchain: Flutter 3.44.6 / Dart 3.12.2 at `C:\Users\prash\Documents\src\.tools\flutter\bin`; FRB generator 2.12.0 at `C:\Users\prash\Documents\src\.tools\frb\bin`. SDK paths are session-local, not added to the system PATH. Dependency versions were preserved.

Before running Flutter bridge tests on a fresh checkout, build the host library with `cargo build --locked --manifest-path rust/Cargo.toml`. `cargo test` alone does not produce the top-level DLL those tests load. Screenshot test setup now respects the existing opt-in flag before loading macOS fonts.

**Fork onboarding (2026-10-09):** P-Sivakumaran fork cloned to `C:\Users\prash\Documents\src\zanzibarr` on Windows, tracking `origin/main`. Rust/Cargo are on PATH; Flutter/Dart are not. No application changes or verification gate run during clone-only onboarding. This fork uses English conversation; upstream Turkish-owner and macOS-local environment notes below describe the upstream maintainer.

**v1.8 shipped** (tag `v1.8`, release notes `docs/releases/v1.8.md`): the multi-file NZB picker (below), byte-level RAR4 parse diagnostics, and the local macOS build fix (`[profile.release.build-override]`, §7). CI built Windows/Android/Linux/iOS; macOS built locally (lipo shim + build-override both needed) and uploaded manually. Site synced ("What's new" v1.8, version var, roadmap picker item flipped to done).

**v1.7 shipped** (tag `v1.7`, release notes `docs/releases/v1.7.md`): the Android TV D-pad overhaul (below) — one-commit release on top of v1.6. All 8 assets published (CI built Windows/Android/Linux/iOS; macOS local with the lipo shim). Site synced ("What's new" v1.7 + the `version` var had been stuck at `v1.3` since the v1.6 sync missed it — fixed).

**v1.6 shipped** (tag `v1.6`, release notes `docs/releases/v1.6.md`). Contents: **Chromecast/AirPlay casting**, **subtitle font picker**, **obfuscated NZB set support** (four-round root-cause saga below — confirmed fixed on the owner's Pixel 8a), **Android NZB download fix** (issue #3), **macOS deployment target 12.0** (Xcode 27). Site (`docs/index.html`) synced: cast feature card, "What's new", roadmap.

Casting architecture (unchanged since implementation):

- `dart_cast` (MIT, pure Dart) added for discovery + remote control; Chromecast primary, AirPlay best-effort (dart_cast's AirPlay video path is unverified on real hardware; we have no Apple TV to test).
- Engine: `server.rs` gains `bind_lan` (0.0.0.0) + per-session 128-bit path token — LAN listener requires `/cast/<token>/` prefix (403 otherwise), loopback behavior unchanged. `StreamInfo.cast_url` carries the LAN URL (empty if LAN bind failed). dart_cast's MediaProxy is bypassed via a `_DirectUrlTransformer` — receivers fetch straight from the engine's range server.
- Flutter: `lib/cast/` (`cast_service.dart` `CastController` interface + `AppCastService`, `cast_device_picker.dart` dialog); cast button in the player top toolbar next to PiP; local playback pauses while casting, play/pause/seek/volume mirror to the receiver, cast position feeds `_position` so continue-watching stays correct; disconnect re-syncs the local player to the cast position.
- Platform plumbing: Android manifest gains `ACCESS_WIFI_STATE` / `CHANGE_WIFI_MULTICAST_STATE` / `ACCESS_NETWORK_STATE` / `NEARBY_WIFI_DEVICES`; iOS + macOS `Info.plist` gain `NSLocalNetworkUsageDescription` + `NSBonjourServices` (`_googlecast._tcp`, `_airplay._tcp`); macOS entitlements already had `network.server`.
- i18n: `cast*` keys added to all 14 locales (en+tr translated, rest English fallback).
- **Subtitle font picker** (same wave): catalog `sans`/`serif`/`mono` (bundled Noto TTFs, OFL) extracted to app support dir and applied via `sub-fonts-dir` + `sub-font` (`lib/player/subtitle_fonts.dart`, `AdvancedPlaybackController.setSubtitleFont`); persisted per-title in `MediaPreferences.subtitleFont`; menu in the subtitle controls overlay next to the color picker. Text subs only — ASS keeps authored styles.

Gate after the change: 223 Rust tests, clippy clean, flutter analyze clean, 152 Flutter tests. **Still pending: on-device casting test** (Homatics Android TV box has Chromecast built-in) — v1.6 shipped without it; Chromecast path is code-reviewed but not hardware-verified, AirPlay video is best-effort.

**Obfuscated NZB support** (2026-09-24, Pixel 8a bug report): posts whose files are renamed to `hash.NN` (real extensions stripped) previously died at selection with "no direct video or supported split 7z/RAR STORE set". The engine now falls back to a content probe: `Nzb::numbered_volume_sets()` groups digit-extension files (contiguity required, start number free), `prepare_stream_source` fetches the first segment of the first (then, for alphabetically-renamed old-style `.rNN`+`.rar` posts, the last) volume and `archive::sniff_archive_kind` recognizes RAR4/RAR5/7z magic; last-volume hits rotate the set into archive order. The resolved set flows into the unchanged RAR/7z pipelines (STORE and compressed both work). Fixture: `rust/tests/fixtures/obfuscated-numbered-set.nzb` (the actual report NZB, 42 volumes `.10`–`.51`). Live NNTP verification still pending — the CLI keychain entry is stale (§7), so `zanzibarr-cli stream-check` gets 502 until the owner reruns `zanzibarr-cli setup`.

**Obfuscated-set head-volume detection** (2026-09-24, second Pixel 8a report, `Martyrs.2008.Uncut...PTer.nzb`, 54 volumes `.10`–`.63`): magic-byte sniffing alone is insufficient for RAR — **every** volume of a RAR set starts with `Rar!`, so a first-volume sniff can't tell the archive head from a continuation volume; old-style posts numbered alphabetically (`.rar` last) crashed layout validation with "split chain flags are corrupt (part 1/54)". `rar::sniff_rar_volume_role()` now peeks the first file header's `split_before` flag (RAR4: file block right after MAIN; RAR5: CRC-less header walk skipping SERVICE blocks, `None` on ENCRYPTION/unknown layout → numeric order trusted). The probe rotates the set only when the tail volume is a *confirmed* head, and falls back to the original order (accurate chain error instead of a misleading "neither RAR nor 7z") when neither end verifies. Gate: 238 Rust + 152 Flutter. **Still failed on-device**: the PTer set's numbering is neither archive order nor old-style — see next entry.

**Obfuscated-set authoritative ordering** (2026-09-24, same PTer NZB, second on-device failure): role probing covers archive-ordered and alphabetically-renamed posts, but this set's `hash.NN` numbering matches neither — and with `-hp`-encrypted headers the role sniff can't even see split flags. Name-based guessing is fundamentally unreliable, so the probe now has a third stage: when neither end is a confirmed head, it fetches the first segment of *every* middle volume (JoinSet, pool-bounded) and sorts the set by the **RAR5 volume number** in each MAIN header (`rar::sniff_rar_volume_number`) — readable on plaintext RAR5; real `-hp` fixtures proved ENCRYPTION comes first there, so numbers are *not* readable under `-hp`. Missing/duplicate numbers (RAR4, `-hp`, old tools) fall back to original order with the accurate chain error. `volume_number_permutation` is a pure, unit-tested function. **Third on-device failure** (still part 1/54, set has no NZB password meta so it isn't `-hp` — headers parse plaintext) → diagnostics added: the probe now returns a trace string (`rar h=C t=? nums=54/54 sorted 0..53 first=…` etc.) that is appended to the setup error shown in the player dialog (`[trace]`), and the split-chain error itself now dumps the offending part's `split_before`/`split_after` values — the owner's screenshot of the error is the live diagnosis channel. Real-fixture sniff regression test added. Gate: **244 Rust** + 152 Flutter, clippy/analyze clean. Live NNTP verification still pending (§7).

**Obfuscated-set root cause FOUND** (2026-09-25, instrumented build `dac1261` on Pixel 8a): the trace read `split_before=true, split_after=true [rar h=C t=C nums=53/54 unsortable, original order]` — the poster's numbering matches neither end convention (both end volumes are continuations), and **exactly one volume lacks a readable RAR5 volume number**. WinRAR omits the number field on the *first* volume (implied 0), so the unnumbered volume is the archive head, lost mid-list in the poster's shuffled numbering; the permutation had demanded all 54 numbers and fell back to the (wrong) numeric order. Fix: `volume_number_permutation` now **gap-fills exactly one unnumbered volume** — fills a single internal gap, or implies it at the front (`min-1`, the implied volume 0) / back (`max+1`) when the known numbers are contiguous; multiple unknowns, duplicates, or multi-value gaps still fall back. `sniff_rar_volume_number` also walks past SERVICE blocks to reach MAIN. Trace marks such sorts with `(1 implied)`. Gate: **246 Rust** + 152 Flutter. **Confirmed fixed on-device** (owner's Pixel 8a, 2026-09-25 — the PTer NZB now plays); shipped in v1.6.

**Android NZB download fix** (2026-09-24, GitHub issue #3, Android TV): `newznab_download_nzb` wrote fetched NZBs under `std::env::temp_dir()`, which is unwritable on Android (no `TMPDIR`, `/tmp` denied) — surfaced as "no permission to create a temp folder", and Android TV's permission settings page shows nothing for it. The FRB call now takes an optional `download_dir`; Dart passes `path_provider`'s app cache dir (no permission needed on any platform), Rust falls back to system temp only when absent (desktop/CLI path). Gate after both fixes: **232 Rust** + 152 Flutter, clippy/analyze clean. Issue #3 answered; its first point (remote-only settings/search navigation) is unfixable-by-verification here — no TV device — see §7/§8.

**Android TV D-pad navigation overhaul** (2026-10-01, GitHub issue #4, NVIDIA Shield video report): on remote-only devices the settings screen was untraversable — single-line fields swallow up/down (EditableText), the password/API-key eye buttons hijacked vertical moves (an IconButton centered in its row sits *higher* than the field's editable rect, so the geometric directional algorithm preferred it and skipped the field entirely), and nothing autofocused. Fixes: `lib/tv_focus.dart` — `dpadTraversalFocusNode` (up/down always traverse; left/right exit only at caret edge; optional `focusOnRightEdge` hook) + `dpadFieldActionFocusNode` (`skipTraversal: true` removes the eye from traversal candidacy so down-arrow always lands on the field; reachable only via right-arrow at text end, left-arrow returns). Indexer test/save buttons stacked vertically (side-by-side pairs are unreachable by vertical walk). Focus visibility theme (`focusColor` + `_tvFocusStyle`) and autofocus/focus rings on settings dropdowns, home cards, and search (first result card grabs focus after results load). `test/tv_navigation_test.dart` proves the full D-pad chain end-to-end with real key events. Gate: **246 Rust** + **159 Flutter**, analyze clean. Shipped as **v1.7** (2026-10-01); **still pending: reporter's on-device confirmation** (asked on issue #4; no TV device/emulator locally).

**Multi-file NZB picker** (2026-10-08, GitHub issue #5): NZBs carrying more than one playable video (season packs, multi-episode posts) previously auto-picked the largest candidate with no user say. The engine now exposes a session-free candidate listing — `playable_entries(&Nzb)` returns `PlayableEntryDto { key, name, kind, encoded_bytes, part_count }` for every direct video (segment-validated), 7z set, RAR set and obfuscated numeric set (probe copies eliminated via `archive_bases`), sorted by size desc then name; `select_stream_by_key` resolves `direct:<filename>` (case-sensitive) / `7z:`/`rar:`/`probe:<lowercase-base>` (case-insensitive) keys and errors on unknown keys; `begin_stream` gains `entry_key: Option<String>`, plumbed through `load_stream_selection*` / `run_stream_session` (CLI passes `None`). Flutter: `lib/player/entry_picker.dart` — a D-pad-friendly AlertDialog (first row autofocused, kind icon, size·type·parts subtitle) shown from `PlayerScreen._start` when >1 candidate and no `initialEntryKey`; cancel pops back out without starting the player; a listing failure silently falls back to the legacy auto-pick path so the existing error surface is preserved. Continue-watching is now per-episode: `PlaybackHistoryEntry.entryKey` (nullable, JSON-tolerant) makes the identity `(nzbPath, entryKey)`, and saving an episode record sweeps the legacy keyless record for the same NZB (ghost-card migration). i18n: `entryPicker*`/`entryKind*`/`entryParts` keys in all 14 locales (en+tr translated, rest English fallback). Gate: **250 Rust** + **166 Flutter**, clippy/analyze clean. Shipped in **v1.8**; awaiting reporter's on-device confirmation (issue #5) — no multi-video test NZB verified on hardware locally.

## 7. Known issues / watch list

- Fork v1.9 distribution: Android signing secrets are absent; Windows signing
  certificate, live playback/casting and clean-machine checks remain separate
  distribution requirements. Linux/iOS builds need CI, macOS needs the signing
  host. No all-platform readiness claim follows from offline test results.

- Multi-indexer: live indexer/caps/download and physical TV verification
  remain outstanding. Multi-source totals are intentionally unknown after
  deduplication. Failed sources retain cursors for retry. Caps testing is
  optional so configuration can be saved offline. See the search plan for
  implementation decisions and proposed release-filter/health follow-ups.

- Metadata: live OMDb lookup needs a personal API key entered in the app;
  only offline service/UI tests were used here. Availability of individual
  ratings varies. There is no direct Rotten Tomatoes API, scraping, logo
  use, TMDB browsing or TVDB lookup. Direct RT integration requires its
  licensing process. Metadata is requested explicitly, bounded to 15 seconds
  and 1 MiB, and cached only in memory (six hours, 100 entries maximum).
  Check real indexer capabilities/ID results and physical remote navigation
  before distributing. New English/Turkish copy has English fallbacks elsewhere.
  Use the settings Test API key button to verify a draft against OMDb; offline
  tests cover this flow but no personal key was read or tested by the agent.

- UI/UX follow-up: local fixes cover all eight findings. Verify real phone/TV playback, physical remote navigation, TalkBack/NVDA, and final rendered contrast on target devices. New copy is English/Turkish with English fallbacks in the other locales, preserving all existing translations. Existing desktop screenshots predate the UX changes.

- *Pillarbox report* on `The.Runner.2026.1080p...` (16:9 content, bars on sides) — fit/fill button added in `3713b31`; if bars persist on a 16:9 TV, that's a render bug → get on-device logcat.
- Owner's Mac keychain still holds a stale `usenews` entry (old password) — CLI gets 502; the release app reads its own `zanzibarr` entries and is unaffected. Confirmed 2026-09-24: `zanzibarr` service has no keyring-visible entries at all, `usenews` holds the old password; this now also blocks live `stream-check` verification of the obfuscated-set fix. Fix: owner runs `zanzibarr-cli setup` once with the current Easynews password.
- Easynews 60-connection limit unverified (§3).
- *Xcode 27 lipo regression (macOS 26.6, Xcode 27.0):* `lipo <file> -verify_arch <a1> <a2>` fails system-wide ("requires exactly one input file"); single-arch verify works, multi `-extract` works. Local macOS builds need a PATH shim that loops per-arch. Shim recipe (write to `/tmp/zanzibarr-lipo-shim/lipo`, `chmod +x`): resolve real lipo via `xcrun --find lipo`; if args contain `-verify_arch`, run `"$REAL" "$1" -verify_arch <each arch>` and AND the exit codes, else `exec "$REAL" "$@"`. Remove when Apple/Flutter fix it (then `flutter build macos --release` works unshimmed again).
- *Issue #3 / #4 (Android TV), remote-only navigation:* fixed and shipped in **v1.7** (2026-10-01; §6 D-pad overhaul). #4 closed with the v1.7 release note — reopen if the reporter still hits remote issues on-device. No TV device/emulator on the dev machine.
- *Mpv.framework spctl complaint (cosmetic, by design):* `codesign --verify --deep --strict` / `spctl -a -vv` report "code has no resources but signature indicates they must be present" for the adhoc-signed `Mpv.framework` subcomponent — identical on shipped v1.5 and v1.6 packages; the main app carries a valid Developer ID signature (team `8665FDLXA6`) and runs fine via right-click → Open (owner-verified). Don't chase this unless notarization becomes a goal.
- *Issue #5 (multi-file NZB picker):* implemented 2026-10-08 (§6), shipped in **v1.8** — awaiting the reporter's on-device confirmation; no multi-video NZB has been verified on hardware locally.
- *Gran.Torino.2008.720p.BDRip RAR4 parse failure (Pixel 8a, 2026-10-08):* "could not read RAR header: RAR4 FILE header is short" on a 49-volume old-style `.r00…rar` set. The Flutter guard maps any "rar4"-containing engine error to the misleading `errRar4` ("legacy format") explanation — the real failure is a CRC-valid FILE block with head_size < 36, which no legitimate RAR4 header can have; the archive carries a structure the parser doesn't model. Root cause still unknown. Byte-level trace shipped in **v1.8** (`[rar4 vol_off=… flags=… hsz=… add=… body=…]` in the error dialog + `eprintln`) — waiting for the owner's trace screenshot, then fix + fixture test. Local macOS repro is impossible: the Mac app has **no stored provider credentials** (owner tests on Android; the login keychain holds only the stale `usenews` entry, no `zanzibarr` items) — the app opens but never dials NNTP.
- *Xcode 27 / macOS 26 toolchain — proc-macro LINKEDIT:* `cargo build --release` fails with `can't find crate for tokio_macros`/`futures_macro` — dyld on macOS 26+ rejects stripped proc-macro dylibs ("mis-aligned LINKEDIT string pool", [rust-lang/rust#157750](https://github.com/rust-lang/rust/issues/157750)); surfaced 2026-10-08 after a rustup/Xcode update (the 2026-10-01 build was still fine). Fixed via `[profile.release.build-override] debug = 2, codegen-units = 256` in `rust/Cargo.toml` (committed) — host-side macro builds keep debuginfo, shipped binaries unchanged. Remove when rustup ships the llvm-objcopy alignment fix.

- **Fork signing setup (2026-10-09):** Android release builds require the four repository secrets documented in `docs/ANDROID_SIGNING.md`. Keys from earlier CI debug-signed APKs cannot be reconstructed; upgrades require their original certificate. No release was built or published during the fixes.
- **Fork code review (2026-10-09):** seven findings have fixes and regression coverage; episode picker still cannot select inner files of a single archive. Fork updater endpoint configured during v1.9 preparation.

## 8. Roadmap (priority order, status)

- Fork v1.9: validate Windows installer lifecycle and platform CI artifacts,
  configure persistent Android signing, complete device checks and promote the
  reviewed draft. Packaging/runbook work is implemented; signing is not assumed.

- Fork multi-indexer plan: Phases 1–5 implemented locally, including optional
  OMDb and manual structured/ID search. Next: release preferences, indexer
  health/rate budgets, duplicate alternatives, and bounded completion checks. See
  `docs/INDEXER_SEARCH_PLAN_2026.md`.
  OMDb setup includes live API testing; verify real account access in the app.

- Fork UI/UX: implementation complete locally; device validation and refreshed release screenshots remain before distribution.

Fork next steps: configure the persistent Android signing key, review the local fixes, and verify release builds/casting/playback on target hardware. All seven review fixes are implemented locally; SDK and regression checks are available.

| # | Item | Status |
|---|------|--------|
| 1 | Multi-file NZB picker — choose episode/file inside a season pack | shipped in v1.8 — awaiting reporter's on-device confirmation (issue #5) |
| 2 | Play queue / auto-play next episode (natural follow-up to #1) | proposed |
| 3 | NZB completion pre-check — sample STAT on segments before playback, health badge in search results | proposed |
| 4 | Easynews web search API (separate code path) | open |
| 5 | Cross-indexer dedup | implemented locally with multi-indexer search; live validation pending |
| 6 | TMDB + OMDb metadata | OMDb implemented locally; TMDB discovery/ID mapping proposed |
| 7 | OpenSubtitles integration | open |
| 8 | Sleep timer (TV-friendly) | proposed |
| 9 | Search history / saved searches | proposed |
| 10 | iOS TestFlight distribution | open |
| 11 | Android TV Play Store listing | proposed |
| 12 | Chromecast / AirPlay | shipped in v1.6 — Chromecast awaiting on-device test (Homatics), AirPlay video unverified |
| 13 | HDR10+ detection | research: mpv exposes no ST 2094-40 signal at runtime (see `HdrCapabilities`); release-name badge possible, true detection likely needs container-level parsing |
| 14 | Remote-friendly (D-pad) settings + search navigation on Android TV | shipped in v1.7 — awaiting reporter's on-device confirmation (issue #4) |

Done since v1.0: Newznab indexer search (v1.1-era), RAR4/RAR5 STORE, split 7z STORE/LZMA + AES-256, PAR2 Reed-Solomon repair, custom libmpv (TrueHD/DTS-HD/AV1), DV Profile 5 on macOS+Android+Windows+Linux, Android TV leanback + remote, 14 languages, dark/light themes, OTA updates, compressed RAR seek, subtitle color, Smart Canvas, continue-watching, Chromecast/AirPlay casting, subtitle font picker, obfuscated (`hash.NN`) NZB sets via content sniffing, multi-file NZB episode picker.

## 9. History (append dated entries at the bottom — newest last)

- **v1.0 (2026-07)** — Phase 0–2: FRB skeleton; NZB parser + yEnc decoder; NNTP pool (rustls/tokio); segment↔byte-range locator from yEnc begin/end; lazy localhost range server; media_kit playback+seek proven against real Easynews. Newznab search, 14 locales, dark/light, GitHub Pages site, Reddit launch.
- **v1.1** — RAR5/RAR4 multi-volume STORE as one virtual seekable file; split 7z STORE + AES-256; PAR2 verify+repair (Reed-Solomon, byte-exact vs par2cmdline); Android TV leanback; Smart Canvas.
- **v1.2** — Dolby Vision Profile 5 fixed on Android: custom mpv 0.41 + FFmpeg 8.1.2 + libplacebo build (repo `libmpv-android-video-build`), GPU reshaping with 8-bit path that survives drivers lacking 16-bit linear sampling (Samsung Xclipse) and Adreno. End of the pink/green saga.
- **v1.3** — embedded-subtitle visibility fix on Android; TV remote key handling; released to all platforms.
- **v1.4 (2026-08)** — continue-watching history, subtitle color, DV Profile 5 on Windows/Linux, first Linux + iOS (unsigned) packages, tag-push CI release pipeline (`release.yml` + reusable builders).
- **v1.5 (2026-09-08)** — OTA updates (GitHub Releases check, in-app install on Android); compressed RAR stream-seek (vendored libunrar, decode-ahead); Android TV remote focus fix; Android silent-start fix + fit/fill toggle; `libc++_shared` APK packaging fix (friend-tested); debug hooks. README test badge corrected (220 Rust + 141 Flutter).
- **2026-09-08** — Cross-AI continuity: added `AGENTS.md` (this file), `CLAUDE.md`, `docs/HANDOVER_PROMPT.md`. Local layout: project moved to `~/Downloads/USENET/Zanzibarr` (parent `CodexGPT` → `USENET`, `UseNews` → `Zanzibarr`). Forked 1:1 into **Usetopia** (`~/Downloads/USENET/Usetopia`, repo `envermeister/usetopia`) — developed as a separate app with Claude/ChatGPT; zanzibarr continues here with Kimi.
- **2026-09-12 (unreleased, main)** — Chromecast/AirPlay casting: engine `bind_lan` + token-gated `/cast/<token>/` prefix, `StreamInfo.cast_url`; `dart_cast` for discovery/control with a direct-URL transformer (receiver fetches straight from the engine range server — no MediaProxy hop); cast button in the player toolbar, control mirroring, position sync into continue-watching; platform permissions for Android/iOS/macOS. Subtitle font picker (bundled Noto Sans/Serif/Mono via `sub-fonts-dir` + `sub-font`). Gate: 223 Rust + 152 Flutter. Awaiting on-device test (Homatics box).
- **2026-09-24 (unreleased, main)** — Obfuscated NZB fix (Pixel 8a report, `Martyrs.2008...H265-FW.nzb`): selection now falls back to content sniffing for `hash.NN` numbered sets — `numbered_volume_sets()` grouping + `sniff_archive_kind()` (RAR4/RAR5/7z magic) probing first/last volume's first segment, with rotation for alphabetically-renamed old-style posts. New `StreamSelection::Probe`; RAR/7z builder arms factored into `build_rar_source`/`build_sevenzip_source`. Real NZB added as fixture. Live NNTP check blocked by stale CLI keychain entry (§7). First Kimi desktop session (takeover from Kimi Code CLI per `docs/HANDOVER_PROMPT.md`); `.gitignore` gains `kimi-export-*.zip` + `/debug/`.
- **2026-09-24 (ikinci oturum, unreleased, main)** — Issue #3 (Android TV): indexer NZB downloads failed with "no permission to create a temp folder" — `newznab_download_nzb` used `std::env::temp_dir()` (unwritable on Android); now takes optional `download_dir`, Dart passes the app cache dir via `path_provider`. FRB regenerated. Issue answered (English). Remote-only settings/search navigation logged as roadmap #14 (no TV device to verify). Gate: 232 Rust + 152 Flutter. CI test builds produced for all four CI platforms (artifacts under `dist/*/ci-6709d7a/`).
- **2026-09-24 (üçüncü oturum)** — Local signed macOS build produced (`dist/macos/zanzibarr-macos-arm64.zip`, team `8665FDLXA6`, keychain-access-groups verified, launch smoke test passed). Required Xcode 27 adaptations: lipo multi-arch `-verify_arch` shim (§7) and deployment target bump 10.15 → 12.0 (`macos/Podfile` + `project.pbxproj`, committed). v1.5's adhoc-signed Mpv.framework behavior unchanged (bundler script signs `--sign -` by design).
- **2026-09-24 (dördüncü oturum, unreleased, main)** — Obfuscated-set follow-up (Pixel 8a, `Martyrs.2008.Uncut...PTer.nzb`): "split chain flags are corrupt (part 1/54)". Root cause: every RAR volume carries the `Rar!` signature, so `probe_numbered_set`'s magic-byte sniff proved the set is RAR but not *which* volume is the head — old-style `.rNN`+`.rar` posts numbered alphabetically put `.rar` last, and the continuation volume (`.r00`) was taken as head. Fix: `rar::sniff_rar_volume_role()` peeks the first file header's `split_before` flag (RAR4: block after MAIN; RAR5: walks MAIN→SERVICE→FILE with a CRC-less `peek_rar5_block`; `None` on encrypted headers/unknown layout → keep numeric order). Probe now validates head role, rotates only a *confirmed* head from the tail, and falls back to original order (accurate chain error) when neither end verifies. 6 new unit tests. Gate: 238 Rust + 152 Flutter. **Same error persisted on-device** → next entry.
- **2026-09-24 (beşinci oturum, unreleased, main)** — Obfuscated-set round 3 (same PTer NZB, still "part 1/54"): the set's `hash.NN` numbering matches *neither* archive order nor old-style alphabetical, and `-hp`-encrypted headers would hide split flags anyway — name/role-based guessing is fundamentally unreliable. Probe gains a third stage: if neither end is a confirmed head, fetch every middle volume's first segment (JoinSet, pool-bounded) and sort by the **RAR5 volume number** from each MAIN header (`rar::sniff_rar_volume_number`); missing/duplicate numbers → original order + accurate chain error. 5 new unit tests. Gate: 243 Rust + 152 Flutter. Android + macOS test packages built (`dist/android/ci-152ecad/`, `dist/macos/`).
- **2026-09-24 (altıncı oturum, unreleased, main)** — Obfuscated-set round 4 (same error on-device a third time): keychain check confirmed no CLI-visible credentials (app entries live in the `8665FDLXA6…` access group) → live `stream-check` repro impossible without owner action. Real `rar5hp` fixtures disproved a wrong assumption: under `-hp` the ENCRYPTION header comes **first** and MAIN is encrypted — volume numbers are only readable on *plaintext* RAR5. The PTer NZB carries no `<meta type="password">`, yet the engine parsed 54 named entries, so the set is plaintext RAR5. Ground-truth instrumentation: probe returns a trace string appended to the player-facing setup error (`[rar h=C t=? nums=54/54 sorted 0..53 first=…]`), and the split-chain error now prints the offending part's `split_before`/`split_after` values. New assertive real-fixture sniff test. Gate: 244 Rust + 152 Flutter.
- **2026-09-25 (yedinci oturum, unreleased, main)** — **Root cause found via instrumented build**: trace showed `nums=53/54 unsortable` with both end volumes being continuations. WinRAR omits the RAR5 volume-number field on the **first** volume (implied 0) — the one unnumbered volume is the archive head, and the strict "all numbers must parse" rule discarded an otherwise complete ordering. `volume_number_permutation` now gap-fills exactly one unnumbered volume (internal gap / implied front `min-1` / implied back `max+1`; duplicates, multi-gaps and multiple unknowns still fall back), and `sniff_rar_volume_number` skips leading SERVICE blocks. 4 new/updated unit tests. Gate: 246 Rust + 152 Flutter. Android + macOS test packages rebuilt (`dist/android/ci-*/`, `dist/macos/`).
- **2026-09-25 — v1.6 shipped.** Owner confirmed the PTer NZB plays on his Pixel 8a (obfuscated-set saga closed). Cut: `docs/releases/v1.6.md`, `pubspec.yaml` → `1.6.0+7`, tag `v1.6` → `release.yml` built Windows/Android/Linux/iOS; macOS built locally with the lipo shim (Xcode 27) and uploaded manually. Site synced: cast feature card, "What's new", roadmap (open items added: multi-file picker, play queue, completion pre-check, TMDB/OpenSubtitles, TestFlight/Play Store). macOS package note: `spctl`/`codesign --deep --strict` still flag the adhoc `Mpv.framework` resource envelope — cosmetic, identical to v1.5, app runs via right-click → Open (§7). Reddit update post covering v1.3→v1.6 drafted in the v1.3 post's style at `dist/reddit-v1.6-update.md`, and the main r/UsenetNoRules announcement refreshed to v1.6 at `dist/reddit-main-post-v1.6.md` (Reddit markdown; a plain-text mirror sits next to it as `.txt`) (both gitignored, not repo artifacts) — owner posts them manually.
- **2026-10-01 — Android TV D-pad overhaul (issue #4, NVIDIA Shield).** Settings/search/home D-pad navigation rebuilt: `lib/tv_focus.dart` (`dpadTraversalFocusNode` — up/down always traverse single-line fields, left/right exit only at caret edge, `focusOnRightEdge` explicit neighbor hook; `dpadFieldActionFocusNode` — `skipTraversal: true` so the password/API-key eye buttons stop hijacking vertical moves: their 48px rect sits higher than the field's editable area, so geometric traversal skipped the fields). Indexer test/save buttons stacked (vertical-walk reachable), theme-wide focus visibility (`focusColor` + `_tvFocusStyle`), autofocus chains on settings dropdown / search field / first result card / home cards. `test/tv_navigation_test.dart` (7 tests) drives real key events through the full chain. Root-cause method: read Flutter's `focus_traversal.dart` (`DirectionalFocusTraversalPolicyMixin`) instead of guessing — `OrderedTraversalPolicy` does NOT affect directional moves (only Tab order), don't reach for it here. Gate: 246 Rust + 159 Flutter, analyze clean. CI Android APK built for the reporter; on-device verification pending (§7).
- **2026-10-01 — v1.7 shipped.** Owner green-lit release before the reporter's confirmation. Cut: `docs/releases/v1.7.md`, `pubspec.yaml` → `1.7.0+8`, tag `v1.7` → `release.yml` built all four platforms; macOS built locally (lipo shim recreated — regression still present on Xcode 27.0; shim verified three-way: multi-arch pass / missing-arch fail / passthrough) and uploaded with `--clobber`. 8 assets on the release. Site synced: "What's new" v1.7, roadmap D-pad item — and the `version` var was found stuck at `v1.3` (v1.6 site sync missed it), fixed. README roadmap backfilled with v1.6/v1.7 done items (it had stopped at iOS build). Issue #4 answered with the fix summary + CI test APK link; awaiting reporter's on-device word to close.
- **2026-10-08 — Multi-file NZB picker (issue #5).** Season-pack NZBs no longer auto-pick the largest file: the engine lists every playable candidate (`playable_entries` — segment-validated direct videos, RAR/7z sets, obfuscated numeric sets with probe-copy elimination; key-addressed via `select_stream_by_key`, `begin_stream(entry_key)` plumbed through the session loaders), and the player shows a D-pad-friendly picker dialog (`lib/player/entry_picker.dart` — autofocus first row, kind/size/parts badges; cancel exits cleanly; listing failure falls back to legacy auto-pick). Continue-watching identity became `(nzbPath, entryKey)` with legacy-keyless sweep on first episode save. 4 Rust + 7 Flutter tests. Gate: **250 Rust + 166 Flutter**, clippy/analyze clean. FRB regenerated. Awaiting reporter's on-device confirmation.
- **2026-10-08 (ikinci oturum) — RAR4 parse diagnostics + local macOS build rescue.** Owner's Gran.Torino.2008 NZB failed on Pixel 8a with "RAR4 FILE header is short" (masked by the `errRar4` "legacy format" explanation — the Flutter guard matches any "rar4"-containing error). Static analysis proved a genuine RAR4 FILE header can never be < 25 body bytes, so the archive carries an unmodeled structure; byte-level trace embedded in the error (`[rar4 vol_off=… flags=… hsz=… add=… body=…]`, PTer method, shipped in v1.8) — owner sends the next screenshot, then the real fix lands. Local repro failed: macOS app has no stored NNTP credentials (zero port-563 connections observed; keychain holds only the stale `usenews` item). Meanwhile the local release build broke with `can't find crate for tokio_macros` — macOS 26 dyld rejects stripped proc-macro dylibs ("mis-aligned LINKEDIT string pool", rust-lang/rust#157750); fixed with `[profile.release.build-override] debug = 2` in `rust/Cargo.toml`. Both commits pushed; trace APK built for the owner (`dist/android/ci-9ff200f/`).
- **2026-10-08 — v1.8 shipped.** Owner green-lit release with the picker + diagnostics. Cut: `docs/releases/v1.8.md`, `pubspec.yaml` → `1.8.0+9`, tag `v1.8` → `release.yml`; macOS built locally (lipo shim + the new build-override — both required) with smoke test, uploaded manually. Site synced: "What's new" v1.8, version var, roadmap picker item done. Reddit update post (covers v1.7 D-pad + v1.8 picker, v1.6-post style) at `dist/reddit-v1.8-update.md` — owner posts manually. Issue #5 got the release comment; left open pending reporter confirmation. **Still open: Gran.Torino RAR4 root cause** (§7 — trace screenshot pending).

- **2026-10-09 — Fork onboarding.** Cloned `P-Sivakumaran/zanzibarr` locally on Windows at `a366747`. Origin tracks the fork; Rust/Cargo available, Flutter/Dart absent from PATH. No application code changed; tests not run.

- **2026-10-09 — Fork code review.** Reviewed current HEAD, v1.7→v1.8, and upstream parity. Seven findings documented in `docs/CODE_REVIEW_2026-10-09.md`; no application changes. Rust tests: 250 passed. Flutter SDK unavailable.

- **2026-10-09 — Implemented all seven review fixes.** Request-owned bounded prefetch with cancellation cleanup; persistent Android signing configuration and universal OTA APK; release-tag SHA propagation; serialized history mutations and filename-checked legacy migration; selected-entry PAR2 repair and regenerated FRB bindings. Added regression tests, fixed two current-toolchain Clippy lints, and made skipped screenshot setup honor its opt-in flag. Installed pinned local Flutter/FRB tools and built the host Rust DLL. Gate: **256 Rust + 175 Flutter**, 8 opt-in screenshot cases skipped; Clippy/analyze/actionlint clean. Signing secrets and actual platform release builds remain deployment setup, documented in `docs/ANDROID_SIGNING.md`. Local working changes, no release published.

- **2026-10-10 — UI/UX review.** Reviewed Flutter source plus existing home/settings/search/player desktop screenshots. Documented eight prioritized issues and proposed validation in `docs/UI_UX_REVIEW_2026-10-10.md`; no app code changes, device testing, or accessibility certification. Previous implementation work preserved.

- **2026-10-10 — Implemented UI/UX review.** Fixed mobile track access/touch targets, pending-task provider/indexer setup, draft protection, pagination/late-response/dedup/focus behavior, filename inspection, readability/large-text reflow, and recoverable errors/history feedback. Added a bounded single-connection native provider test and regenerated FRB/localization bindings. `intl` is now a direct dependency at its existing locked version. Added offline flow, narrow-screen/200%-text/RTL, redaction, native-bridge, and history failure regressions. Gate: **257 Rust + 190 Flutter**, 8 opt-in screenshots skipped; Clippy/analyze/native build/diff check passed. Prior code-review fixes remain intact; nothing committed, pushed, or released.

- **2026-10-10 — Claude handover.** Added `docs/CLAUDE_HANDOVER_2026-10-10.md` with the uncommitted implementation scope, latest verification evidence, local Windows toolchain, remaining device/release checks, and continuation prompt. No application changes or additional test run; prior final gate remains 257 Rust + 190 Flutter (8 opt-in screenshots skipped).

- **2026-10-11 — Resumed multi-indexer development.** Migrated remaining
  screenshot/UX/TV tests to profile lists and fan-out results. Fixed source
  cursors, duplicate-name download routing, all-failed retry, cross-page
  deduplication, unreadable-storage handling, draft protection, failed-save
  recovery, and D-pad dialog navigation. Added profile ordering and search
  toggles. Regenerated FRB/localizations and rebuilt the host library.
  Gate: 260 Rust + 203 Flutter passed (8 opt-in screenshots skipped),
  Clippy/analyze/native build clean. Preserved prior branding/background
  changes; no commit, push, release, or tag during this continuation.

- **2026-10-11 — Metadata and precise release search.** Added optional
  secure-stored OMDb setup, explicit title/IMDb lookup, source-labelled
  ratings/synopsis, title confirmation, and manual IMDb/TVDB/season/episode
  entry. Native search honors advertised ID parameters and safely falls
  back to full text; result IMDb attributes become lookup hints. Added
  bounded/cached/coalesced metadata requests, safe errors, draft recovery,
  large-text scrolling, and query-identity/pagination regressions. Regenerated
  FRB/localizations. Gate: **265 Rust + 214 Flutter**, 8 opt-in screenshots
  skipped; Clippy/analyze/native build/diff check passed. Updated indexing
  follow-up plan. Live API/device checks remain outstanding; no commit,
  push, release or tag during this continuation.

- **2026-10-11 — OMDb API test and form formatting.** Added an explicit
  uncached API check using the draft key, without persisting it. Added
  key-only format validation, whitespace trimming, visibility toggle,
  structured status feedback and edit invalidation. Offline regressions
  cover successful/rejected keys, malformed input and cache bypass.
  Gate: **265 Rust + 216 Flutter**, 8 opt-in screenshots skipped;
  Clippy/analyze/diff check clean. No personal API key accessed.

- **2026-10-12 — Fork review and release preparation.** Fixed silent profile
  load failures, raw RSS pagination counts and upstream update routing. Added
  Windows Inno Setup/portable packaging with CRT/notices/version checks, Linux
  deb packaging, verification CI, release input validation/checksums/drafts,
  v1.9 candidate notes and runbook. Final gate: 266 Rust + 218 Flutter passed,
  8 opt-in screenshots skipped; Clippy/analyze/actionlint clean. Windows native
  release and installer built. Android signing secrets absent; physical-device,
  macOS signing and clean-machine validation remain outstanding.
  Candidate committed on `release/v1.9-packaging`; remote push rejected for
  missing OAuth `workflow` scope, and SSH public-key auth unavailable. No remote
  PR/tag/release or Linux/iOS CI build was created.

### Key technical decisions (the *why* — don't relitigate without cause)


- **Rust + FRB, on-device, no server:** mature crate ecosystem (NNTP/yEnc/RAR/7z/PAR2), clean FFI, no runtime. NZBDav (C#, MIT) is reference blueprint only — algorithms ported, code never copied.
- **STORE first, archives later:** end-to-end playback was proven on STORE releases before any archive work; RAR/7z/AES/PAR2 came in phased afterwards. Keep this discipline for new media features.
- **Custom libmpv builds:** stock media_kit libs lack TrueHD/DTS-HD and botch DV P5 (pink/green). P5 is reshaped on GPU via libplacebo; HDR10-based profiles ride the natural decoder path. Never "fix" DV by forcing SDR silently.
- **Vendored unrar fork** (`vendor/unrar-rs`, `vendor/unrar-sys`): upstream unrar 0.5.8 + patches — `UCM_CHANGEVOLUMEW` handler must not touch `p1` (heisenbug SIGABRT), `USE_LUTIMES` off on Android, per-target link flags (`c++_shared` / `c++` / `stdc++`), `-fno-stack-check` on Apple targets. Prefer patching the fork over replacing the approach.
- **Android C++ runtime:** engine `.so` links `libc++_shared`, which must be *packaged into the APK* (`copyLibcxxShared` task) — static linking was tried and abandoned (`--undefined-version` hacks in CI).
- **OTA via GitHub Releases:** update check reads latest release; Android installs in-app through a FileProvider content URI; desktop links out.

## 10. Onboarding order for a fresh agent

1. This file.
2. `README.md` — product surface and feature wording.
3. `docs/releases/v1.4.md` (and any newer `v*.md`) — what shipped last.
4. `rust/src/engine/mod.rs` → `server.rs` / `http.rs` / `locator.rs` — the streaming spine.
5. `lib/main.dart` → `lib/player/player_screen.dart` — app shell and player wiring.
6. `pubspec.yaml`, `rust/Cargo.toml` — dependency ground truth (never assume a package exists).
7. `.github/workflows/release.yml` — how releases actually happen.

Working with the owner: replies in Turkish; test feedback arrives as screenshots/screen recordings from friends' devices (Samsung/Poco phones, Homatics Android TV box, Windows PC); test NZBs live under `~/Downloads/USENET/` (parent of this repo); use the §5 debug hooks to reproduce quickly. Commit + push is pre-authorized (Turkish conventional commits) — still never commit secrets, build outputs or the `kimi-export-*` session files.
