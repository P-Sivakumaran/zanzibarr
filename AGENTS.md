# AGENTS.md - Zanzibarr fork

Canonical working instructions for agents collaborating with Treewizard on
`P-Sivakumaran/zanzibarr`. Read this before editing. Current user instructions
take precedence. Historical upstream notes are context, not authorization or
current owner preferences.

## 1. Communication and collaboration

- Use **English** for conversation, new documentation, PR descriptions and new
  commit messages. Use English Conventional Commits, such as
  `fix(search): preserve raw source pagination counts`. Preserve existing
  translations and comments unless changing them is part of the task.
- Treat "review", "clean up" and "can you build" as instructions to do the work.
  Continue through implementation and appropriate verification; do not stop at
  a plan or repeatedly ask for confirmation of authorized steps.
- Make reasonable reversible choices and state material assumptions. Ask only
  when missing information, credentials or authorization actually blocks work.
  Prepare a concrete reviewable result before requesting a final decision.
- Give concise progress updates during substantial work. Handoffs should state
  what changed, verification results, artifact paths and remaining blockers.
- Preserve unrelated user edits, branding and work from other agents. Inspect
  the working tree first. Do not reset, stash, overwrite or broadly reformat it
  to make a task easier. Work only in this repository unless instructed otherwise.
- Use sub-agents only when the user or an applicable skill explicitly requests
  delegation. Give editors clear file ownership and preserve concurrent edits.
- Do not inherit blanket commit/push, release or messaging permission from the
  upstream maintainer's historical instructions. Continue actions already
  authorized in this session; do not invent additional approval gates either.

### Durable memory

When mem0 tools are available, use `user_id: "prashanth"` for writes and an
explicit `user_id: "prashanth"` filter for searches. Do not use the duplicate
email-based entity. Proactively store durable preferences and corrections;
skip temporary task state, code facts and anything recoverable from Git.
Never store secrets. Repository state belongs in this file and linked docs.

## 2. Repository and local environment

| Item | Source / location |
|---|---|
| Fork / release destination | `https://github.com/P-Sivakumaran/zanzibarr` |
| Upstream / attribution | `https://github.com/envermeister/zanzibarr` |
| Local checkout | `C:\Users\prash\Documents\src\zanzibarr` |
| Primary shell / host | PowerShell on Windows |
| Local Flutter / Dart | `C:\Users\prash\Documents\src\.tools\flutter\bin` |
| Local FRB generator | `C:\Users\prash\Documents\src\.tools\frb\bin` |
| Versions last verified | Flutter 3.44.6, Dart 3.12.2, FRB 2.12.0 |
| Dependency truth | `pubspec.yaml`, `pubspec.lock`, `rust/Cargo.toml`, `rust/Cargo.lock` |

Paths describe this checkout; discover tools on other hosts. Flutter/Dart may
not be on PATH; use explicit local `.bat` paths or set PATH for the current
process. Do not change global SDK configuration as a task side effect. Verify
installed versions before changing pins.

`zanzibarr.app` and inherited donation/signing links belong to upstream unless
verified otherwise. Check fork download links and the updater when releasing.
Never assume upstream assets, accounts, signing identities, test devices or
another maintainer's Mac are available to this fork.

## 3. Architecture and onboarding

Zanzibarr provides seekable video playback from Usenet NZBs. It fetches segments
on demand through a Rust engine, serves HTTP byte ranges locally, and plays them
with Flutter/media_kit/libmpv. Compressed archives can use temporary disk space;
do not describe every path as download-free or entirely in memory.

| Area | Main files / directories |
|---|---|
| App bootstrap / home | `lib/main.dart` |
| Player, controls, resume, subtitles | `lib/player/` |
| Providers, indexer profiles, preferences | `lib/settings/` |
| Multi-indexer / structured search | `lib/search/`, `rust/src/api/search.rs`, `rust/src/engine/newznab.rs` |
| Optional OMDb lookup / ratings | `lib/metadata/` |
| MCP, provider plugins, Codex account connection | `lib/integrations/`, `docs/INTEGRATIONS.md` |
| Casting | `lib/cast/`, `rust/src/engine/server.rs` |
| Updates / localization | `lib/update/update_service.dart`, `lib/l10n/` |
| Native API / generated bridge | `rust/src/api/`, `lib/src/rust/`, `rust/src/frb_generated.rs` |
| Streaming engine | `rust/src/engine/` |
| Native build / patched dependencies | `rust_builder/`, `vendor/` |
| Offline tests / archive fixtures | `test/`, Rust module tests, `rust/tests/fixtures/` |
| Release automation / packaging | `.github/workflows/`, `tools/windows/`, `tools/package_linux.py` |

Start with `git status --short`, the current branch and relevant diffs. Read
`README.md`, the relevant plan/review and current release notes. For engine work,
read `mod.rs`, `server.rs`, `http.rs`, `locator.rs` and the affected module.
For bridge changes, read `flutter_rust_bridge.yaml`; for releases, read
`docs/RELEASING.md` and the actual workflow files. Code and verification evidence
take precedence over stale handover descriptions.

## 4. Engineering rules

1. **Protect credentials.** Application credentials use OS secure storage;
   CLI credentials use keyring/prompted input. Never put real secrets in source,
   tests, ordinary files, command arguments, logs, exception text or `Debug`
   output. Credential-bearing DTOs must not derive `Debug`. Test credentials
   use only `TESTPASS123`. Signing uses documented CI secrets; temporary
   keystores stay outside Git and must be cleaned up.
2. **Use decoded offsets.** Seek positions come only from decoded yEnc
   `begin/end` via recorded parts. NZB encoded `bytes` counts are for planning
   and progress, never for media offsets.
3. **Keep streaming bounded and cancellable.** Fetch segment-by-segment; never
   prefetch an entire open-ended range. Prefetch belongs to its requesting
   stream. Release child tasks/connections on cancellation or shutdown and
   preserve pause/seek/close behavior and temporary-file cleanup.
4. **Gate LAN access.** Casting listeners require the per-session 128-bit token
   under `/cast/<token>/`; reject other paths. Loopback stays local. Never
   expose an unauthenticated LAN endpoint.
5. **Preserve search identity and recovery.** Route downloads by stable profile
   IDs, not display names. Advance sources by raw RSS item counts before
   filtering/deduplication; retain failed cursors for retry. Surface storage
   failures, protect drafts on failed saves and ignore stale async results.
   Query edits invalidate selected title IDs; pagination preserves query identity.
6. **Keep metadata optional and bounded.** Search works without an OMDb key.
   Preserve explicit lookup, sanitized errors, timeout/body limits and bounded
   caches. Label rating sources honestly; OMDb-provided Rotten Tomatoes scores
   are not direct RT API integration or scraping.
7. **Preserve native media fixes.** Review patched unrar before replacing it:
   volume callbacks, platform link flags and Android runtime packaging address
   real crashes. Do not silently force SDR to hide Dolby Vision failures.
   Verify media-library provenance per platform. Preserve `UCM_CHANGEVOLUMEW`
   callback pointer safety, Android `USE_LUTIMES` handling and platform-specific
   C++ linkage; package Android `libc++_shared` with the APK.
8. **Respect input and localization.** Preserve touch targets, D-pad traversal,
   visible focus, large text and RTL layouts. Directional focus does not follow
   Tab ordering automatically. Keep locales valid, disclose English fallbacks
   and regenerate localizations with the pinned tools.
9. **Prefer focused changes.** Fix demonstrated problems; avoid speculative
   abstractions and unrelated dependency upgrades. Add meaningful regressions
   for behavioral fixes. Format changed code without rewriting unrelated Rust
   modules or vendored dependencies; inspect formatter output immediately.

After changing a public Rust API signature, regenerate with
`flutter_rust_bridge_codegen generate` using version 2.12.0 and the repository
configuration. Do not manually synchronize generated bridge files.

## 5. Review and verification

Pin reviews to a real SHA/tag and include relevant working changes and untracked
source. Report actionable findings with severity, file/line, trigger, impact
and correction. Separate confirmed bugs, missing requirements, recommendations
and unverified platform risks. Follow an invoked review skill; a simple fix
does not require an arbitrary spec or elaborate review ceremony.

For application/native behavior changes and release candidates, run the full
gate from the root, in order, stopping on failures:

```powershell
cargo test --locked --manifest-path rust/Cargo.toml
cargo clippy --locked --manifest-path rust/Cargo.toml --all-targets -- -D warnings
flutter analyze --no-pub lib test
cargo build --locked --manifest-path rust/Cargo.toml
flutter test --no-pub
git diff --check
```

Run `flutter pub get` first on a fresh checkout or when dependency resolution is
needed. The host `cargo build` is required for FRB tests: `cargo test` alone does
not produce the top-level DLL they load. For workflow changes, run actionlint.
For release inputs, run `python tools/validate_release.py vX.Y`.

Documentation-only edits need content/link and whitespace checks, not a full
application test run. Packaging changes need the affected build/package checks.
Do not repeatedly rerun unrelated suites after a passing gate. State what ran,
results and skips; never present old evidence as a new run. Save bulky logs
under ignored `dist/audit/` and summarize them in handoffs.

## 6. DevOps, packaging and releases

Detailed commands: [release runbook](docs/RELEASING.md).

- Use focused review branches and reviewable commits where appropriate. Inspect
  staged content; exclude credentials, build outputs and session exports.
  Default to draft PRs/releases for preparation tasks. Merge, tag, push and
  publish within the user's authorized scope; do not force-push or rewrite
  shared history as routine cleanup.
- Preserve lockfiles and align toolchain pins across local builds and CI. Check
  proposed dependency/security updates against official sources and run relevant
  tests; do not upgrade everything as generic cleanup.
- Match release tags, `pubspec.yaml` version/build and English notes at
  `docs/releases/vX.Y.md`. Android build codes must increase. Validate inputs
  before starting platform builds.
- Build assets from one resolved commit SHA. `release.yml` passes that SHA to
  verification and reusable builders. Preserve read-only verification permissions
  and keep signing secrets out of pull-request verification jobs.
- Keep artifact paths consistent through upload/download/checksum/publication.
  Packages uploaded together should share a staging directory. Generate and
  verify `SHA256SUMS`; checksums do not replace publisher signatures.
- Record distinct states: implemented, tested, built, installer-smoked, signed,
  CI-validated and published. A local build is not a public release, a hidden
  launch is not rendered UI validation, and a host test is not device playback.
- Resolve actual authentication/signing blockers without bypassing permissions.
  Report the failed action and missing capability. Do not repeatedly retry
  unchanged credentials, fabricate certificates or report partial success as complete.
- Promote a reviewed draft after applicable artifact/device checks and within
  release authorization. Keep the updater on the fork. Roll forward with a
  corrected higher version; do not silently replace tags or reuse version codes.

| Platform | Packaging / evidence required |
|---|---|
| Windows x64 | `flutter build windows --release`; `tools/windows/install-inno.ps1`, `package.ps1`, `smoke-installer.ps1`. Setup + full portable ZIP include CRT/native DLLs and notices. Stable installer AppId; per-user install. Sign when a certificate is available. Test a clean user/VM and live playback separately. |
| Ubuntu 24.04 x64 | CI builds the bundle, tarball and `.deb` via `tools/package_linux.py`. System GTK/libmpv/secret-service dependencies apply. Validate on Ubuntu; do not claim other distros/architectures. |
| Android / TV | CI creates universal + ABI APKs using persistent secrets from `docs/ANDROID_SIGNING.md`. Preserve certificate identity for upgrades and package `libc++_shared`. Verify phone/TV playback and physical remote input. |
| iOS | macOS CI produces an unsigned IPA. Sideloading requires signing; App Store/TestFlight needs separate provisioning. Label unsigned artifacts explicitly. |
| macOS arm64 | Requires an appropriate Mac, frameworks and signing identity. Verify nested frameworks, effective OS minimum and signing/notarization rather than assuming upstream compatibility or certificate access. |
| Web | Out of scope: the engine requires raw NNTP/native dependencies. |

The macOS release build override preserves proc-macro debug information for a
recorded dyld/LINKEDIT issue. Upstream also recorded an Xcode `lipo` multi-arch
verification workaround. Reproduce on the actual Mac before applying/removing
workarounds; details remain in the historical archive.

## 7. Current state and blockers - last verified 2026-10-17

- Latest local Windows candidate is **1.14.0+15**, adding Claude API-key chat
  and Gemini API-key/registered Google Desktop OAuth chat. AI connections opens
  from film chat or MCP & AI. Credentials use secure storage; Google supports
  PKCE, refresh and cancellation. Stale startup results cannot undo provider
  changes. Fresh full gate: 266 Rust and 312 Flutter passed, 8 screenshot skips;
  Clippy, analysis and native build passed. Windows setup/ZIP built; hashes,
  ZIP integrity, libraries and bundled guides verified. Unsigned, not installed
  or published. Installed version is 1.13.0+14; its Codex connection failure
  remains unresolved although a real Dart login-start/cancel probe passed.
  Live Claude/Gemini inference and Google consent await user credentials/client
  registration. Native 1.14 UI, clean-user installation and playback remain
  unverified. See [setup](docs/AI_CONNECTIONS.md) and
  [verification](docs/AI_CONNECTIONS_VERIFICATION_2026-10-17.md).

- Previous local Windows candidate was **1.13.0+14**, with a labelled **MCP & AI**
  entry in all Settings routes and a sign-in shortcut at the top of Integrations.
  D-pad Up to Back and Right to MCP & AI are covered by regression tests.
  Fresh full gate: 266 Rust and 300 Flutter tests passed, 8 screenshot skips;
  Clippy, analysis and native build passed. Windows setup/ZIP built and hashes,
  ZIP integrity and components verified. Unsigned, not installed or published.
  Installed 1.12.0+13 was inspected: the Search gear hid Integrations; full
  Settings exposed it. The app was left on its existing Codex login controls.
  Live OAuth/inference and native 1.13 login remain unverified. See
  [connection verification](docs/CONNECTIONS_VERIFICATION_2026-10-17.md).

- The **1.12.0+13** candidate introduced in-app Codex film chat, recommendations,
  saved ordered playlists and release-search handoff. Its gate passed 266 Rust
  and 297 Flutter tests (8 screenshot skips). Signed-out Codex 0.162.1 accepted
  the ephemeral thread configuration without inference. See [film chat setup](docs/FILM_CHAT.md) and [verification](docs/FILM_CHAT_VERIFICATION_2026-10-17.md).

- Previous local Windows candidate was **1.11.0+12**, with opt-in MCP control,
  external MCP tools, metadata-provider plugins and Codex managed account sign-in.
  Rust: 266 tests; Flutter: 287 tests and 8 screenshot skips; Clippy, analysis,
  host build, Windows release build and packaging passed. Three stdio bridge
  tests and a signed-out Codex 0.162.1 handshake passed. Hashes/ZIP verified.
  Installer is unsigned and not published or installed; the installed copy is
  1.10.0+11. Live OAuth/providers, inference and physical playback remain unverified.
  No embedded chat UI or Claude subscription token import. See
  [integration verification](docs/INTEGRATIONS_VERIFICATION_2026-10-16.md).

- Previous local Windows candidate was **1.10.0+11**. The latest update-button
  work adds manual checks and verified Windows installer downloads. Public
  maintainer branding uses **Treewizard**; account URLs and mem0 IDs stay unchanged.
  Rebuilt setup/ZIP and verified hashes and portable components. Full serial
  Rust gate: 266 passed (initial parallel run had two socket-resource failures);
  Flutter: 266 passed, 8 screenshot skips. Clippy, analysis and host build passed.
  Installer lifecycle smoke refused an existing installation registration;
  preserve it and use a fresh user/VM. Signing, playback and publication remain
  unverified. See `docs/releases/v1.10.md`. The v1.9 evidence below is historical;
  `dist/windows/` now contains v1.10 artifacts.

- Candidate: **1.9.0+10** on local branch `release/v1.9-packaging`. Upstream v1.8
  history is separate from this unpublished fork candidate. Inspect Git for
  the current commit/working tree rather than relying on copied SHAs here.
- Multi-indexer search, optional OMDb metadata, structured ID search, UI recovery
  and branding are included. Latest review fixes cover profile-load recovery,
  raw RSS cursor counts and fork update routing.
- Last full application gate: **266 Rust + 218 Flutter tests passed**; 8 opt-in
  screenshot cases skipped. Clippy, Flutter analysis and actionlint passed.
  This is release-preparation evidence, not a new run for subsequent docs.
- Windows release, setup and portable ZIP built at `1.9.0+10` under
  `dist/windows/`, with verified hashes. Install/reinstall/hidden startup/uninstall
  smoke passed. Executable/installer are unsigned; clean-machine playback,
  rendered UI and accessibility checks remain outstanding.
- Last push failed because the GitHub OAuth token lacked `workflow` scope;
  direct SSH public-key authentication failed too. User refresh was requested
  with `gh auth refresh -h github.com -s workflow`. Recheck after access changes.
  No remote PR/tag/release or Linux/iOS CI artifact was created in preparation.
- Android signing secrets were absent when checked; local command-line tools
  were incomplete. Combined release CI needs signing setup. macOS signing and
  iOS provisioning are not available on this Windows host.
- Live NNTP/indexer/OMDb checks, casting, physical TV/phone input and updated
  screenshots remain pending. Do not assume upstream accounts/devices are ours.
- Reported Gran Torino RAR4 parsing failure remains unresolved; preserve its
  diagnostics and obtain a fixture/trace before changing parsing. Archive-set
  selection does not select inner files within a single archive.

## 8. Next work and handoff

Recommended sequence, subject to the user's current priorities:

1. Restore workflow-capable GitHub authentication; push the reviewed branch,
   create a draft PR and run verification/Linux/iOS CI. Fix concrete CI failures.
2. Configure persistent Android signing, verify target devices, and assess
   Windows distribution signing and macOS signing access.
3. Complete clean-machine install/upgrade/playback, casting, screen-reader and
   TV focus checks; refresh screenshots and review a release draft.
4. Continue search work from `docs/INDEXER_SEARCH_PLAN_2026.md`: release
   preferences, source health/rate budgets, duplicate alternatives and bounded
   completion checks. TMDB, queues, subtitles and store distribution remain
   backlog proposals, not implicit task scope.

At handoff, refresh current state/blockers and next steps only when changed.
Put detailed evidence in a dated review/handoff and add a short entry below.
Keep this guide focused; do not accumulate raw logs or duplicate the complete
upstream release history. Preserve unresolved engineering lessons.

## 9. References and history

- [v1.11 integrations candidate](docs/releases/v1.11.md)

- [v1.9 release notes](docs/releases/v1.9.md)
- [Release runbook](docs/RELEASING.md)
- [Android signing](docs/ANDROID_SIGNING.md)
- [Latest code review](docs/CODE_REVIEW_2026-10-12.md)
- [Earlier engine/release review](docs/CODE_REVIEW_2026-10-09.md)
- [UI/UX review](docs/UI_UX_REVIEW_2026-10-10.md)
- [Multi-indexer plan](docs/INDEXER_SEARCH_PLAN_2026.md)
- [Archived agent context](docs/history/AGENTS_LEGACY_2026-10-12.md)

**2026-10-12 - Fork workflow rewrite:** English communication and commits;
Treewizard's Windows/fork environment; proportionate verification; review,
packaging, CI and release practices; explicit evidence and access blockers.
Preserved technical invariants and archived the old guide intact. Updated
`CLAUDE.md` to reference this canonical file. Documentation checks only;
application test evidence above comes from the preceding release preparation.

**2026-10-16 - Search performance and icon repair:** Indexed Flutter result
deduplication while preserving first-source and size matching behavior; replaced
the black-surround launcher image with generated transparent platform icons and
a transparent Home asset. Icon generation now uses repository-relative paths.
Full gate passed: 266 Rust and 270 Flutter tests, with 8 screenshot skips.
Benchmark, image prompt, build evidence and platform limits:
[refinement notes](docs/REFINEMENT_2026-10-16.md).

**2026-10-16 - Windows installer:** Created setup/portable packages with the
existing background launch-time updater and corrected icon; verified hashes and
ZIP components. Added five startup-flow regressions; 21 focused update tests and
analysis passed. Installer is unsigned; lifecycle smoke refused an existing
installation. See [installer evidence](docs/WINDOWS_INSTALLER_2026-10-16.md).

**2026-10-16 - Integrations candidate:** Implemented and packaged opt-in MCP
control/client tools, metadata-provider plugins and official Codex managed
account sign-in. Setup and authentication boundaries are documented in
[INTEGRATIONS.md](docs/INTEGRATIONS.md); verification and platform limits are in
the dated integration handoff above. No live OAuth or inference was initiated.
