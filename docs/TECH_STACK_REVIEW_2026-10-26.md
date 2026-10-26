# Zanzibarr: critical technology-stack evaluation

Review date: 26 October 2026. Repository: P-Sivakumaran/zanzibarr. Base revision: `d8f4ac05e72db7df9cfcd97e1c39c97363c14b1f`, **including current modified and untracked application sources**. Reviewed-input SHA-256 hashes are recorded in ignored `dist/audit/tech-stack-2026-10-26/source-evidence.json`. This review does not certify any GitHub release or deployed installation.

Implementation follow-up: [remediation and verification ledger](STACK_REMEDIATION_2026-10-26.md), including subsequent advisory scans and targeted dependency updates. The findings below describe the reviewed baseline.

## Executive judgement

**Retain Flutter + Rust + media_kit/libmpv. Improve ownership, provenance and verification around them.** The core division fits seekable Usenet playback: Rust owns protocol/segment/archive work; libmpv owns media decoding; Flutter owns interaction. Passing encoded video through Dart or replacing this with a browser-first player would discard useful properties without addressing the main failures.

The stack is capable, but the maintenance obligations exceed a simple Flutter application. It includes Dart, Rust/Tokio, C++ unrar, libmpv/FFmpeg/libplacebo, platform GPU drivers, WebView2/WebKit/Android WebView, platform credential stores, native build tools and several packaging ecosystems. More feature providers increase contract work without increasing confidence in that foundation.

The most consequential observed gaps are unverified Android native downloads, unbounded pre-authentication HTTP connections, growing playback coordination inside widget state, limited transactional persistence and incomplete release trust/device evidence. These are reasons for targeted engineering, not a wholesale rewrite.

## Evidence and limits

This was source/configuration inspection, bundle-size measurement and primary-source research. No new application gate, device playback benchmark, dependency vulnerability scan, exploit attempt, clean install or live API authentication was run for this review. The preceding implementation gate recorded 284 Rust and 535 Flutter tests, 10 Flutter skips, analysis, Clippy and native build passing. Those are earlier results, not new review measurements. Tests and packaging checks cannot establish runtime decoder support or remote-control usability.

Excluding generated FRB and localization Dart files, the working tree has approximately 36,738 lines across 111 Dart files and 19,291 lines across 28 Rust files. These figures include unfinished hosted-catalogue code and Rust in-file tests; they measure scope, not quality. `player_screen.dart` is 4,077 lines, `main.dart` 2,561 and native `api/streaming.rs` 1,888. Their responsibilities and lifecycle coupling matter more than their lengths.

## Stack decisions

| Layer | Assessment | Decision |
|---|---|---|
| Flutter/Dart | Suitable shared desktop/mobile UI; TV focus, large text and native integration require explicit work. A shared toolkit does not prove platform parity. | Keep; extract application state from widgets. |
| Rust/Tokio | Appropriate for bounded NNTP concurrency, segment decoding, byte-range service and cancellation. Existing `RangeSource` is a useful testable seam. | Keep; consolidate session ownership and resource budgets. |
| flutter_rust_bridge 2.12.0 | A reasonable typed control plane; matching runtime/generator versions and generated-code discipline are valuable. | Keep. Prefer session commands/events rather than additional global handles or media-byte DTOs. |
| media_kit 1.2.6 / libmpv | Broad codec/subtitle capability matches the product better than a web player. Hardware acceleration and HDR depend on the actual native build and device. | Keep; inventory and validate the exact native payload per platform. |
| C++ unrar and archive modules | Real functionality with FFI, malformed-input and disk/CPU exposure. Rust cannot make foreign decoder code memory safe. | Keep known patches; expand adversarial fixtures and consider a desktop worker if measured failures warrant isolation. |
| Embedded WebViews | Appropriate for user-loaded trailers, but introduce runtime servicing, origin, cookie/profile and lifecycle obligations. | Contain to optional views; retain external fallback. |
| Secure storage | Appropriate for tokens and credentials; existing edition namespaces are useful. Less suitable as the long-term queryable library engine. | Retain for secrets; evaluate an encrypted transactional library store. |
| MCP/AI/metadata adapters | Useful optional workflows; already contain bounded requests, explicit permissions and cancellation work. | Keep optional, with no authority inferred from discovery or model output. |
| Packaging | Existing platform candidates and source manifests improve traceability. Mutable tools/native payloads and missing signing keep release trust incomplete. | Harden before widening support claims. |

Resolved Dart versions above come from `pubspec.lock`, not merely caret constraints. Rust dependencies are locked, but CI uses the moving `stable` toolchain. The installed Android CLI is a development tool; installing it does not validate the Android app or its native dependencies.

## Prioritized findings

### 1. High: Android native media downloads are not content-authenticated

**Observed:** `vendor/media_kit_libs_android_video/android/build.gradle:62` downloads four ABI JARs from `envermeister/libmpv-android-video-build` release `v1.1.7-dv.5` using `new URL(...).openStream()`. Existing files are reused and no expected digest or signature is checked. The path override in `pubspec.lock` does not authenticate these secondary downloads. HTTPS and a fixed release label are not content pins.

**Consequence:** fresh builds and cached builds can consume different native binaries under the same app dependency lock. The app also inherits the servicing and provenance obligations of that external fork. This is a confirmed verification gap, not evidence of compromise or a known vulnerable version.

**Remedy:** obtain independently reviewed SHA-256 values, verify both newly downloaded and cached JARs, fail closed, record upstream source/build recipe and native versions, and inventory every packaged SO. Keep the Dolby Vision and `libc++_shared` fixes until replacement compatibility is demonstrated. Raw URL downloads need explicit verification; Gradle dependency metadata alone may not cover them. [Gradle verification guidance](https://docs.gradle.org/current/userguide/dependency_verification.html).

### 2. High: the local/cast server lacks admission bounds before authentication

**Observed:** `rust/src/engine/server.rs:83` creates a `JoinSet`; each accepted socket spawns a task without a connection permit. `read_head` at line 243 awaits reads without a deadline; token validation follows header reading. `rust/src/api/streaming.rs:936` attempts to bind the LAN listener during normal streaming when entropy is available, rather than waiting for a cast command.

**Trigger/impact:** many idle or slowly completing connections can retain tasks/sockets before the correct cast token is required. A 16 KiB header limit bounds bytes per connection, not connection count or elapsed time. Scope is the local/LAN listener, not an assumed public internet service. No exhaustion attack was executed.

**Remedy:** cap accepted connections, bound header-read time, apply stalled-write/idle policies compatible with long media reads, and consider creating the LAN listener only for explicitly active casting. Preserve abort-and-drain shutdown. Test idle unauthorized clients, overload, cancellation and a normal player/cast seek concurrently. Do not impose a short total duration on legitimate movie streams.

### 3. Medium-high: playback lifecycle ownership is spread across too many layers

**Observed:** `lib/player/player_screen.dart:127` owns native startup, player subscriptions, history, subtitle/zoom drains, recovery, timers, casting and MCP attachment. Its disposal path at lines 1524/1596 drains several independent queues and timeouts. `rust/src/api/streaming.rs:35` and line 49 hold a global runtime and active stream. Recent edition authentication introduces another lifecycle owner.

**Consequence:** a new route, relock or next-episode transition must preserve ordering across multiple owners. The recently fixed repeated initialization and late-authentication bugs demonstrate this class of coordination cost, but are not still-open findings. Large widgets alone do not prove poor performance.

**Remedy:** introduce one application-level playback-session module with explicit states, a session identity, cancellation, bounded events and idempotent close. Keep the Rust decoder/transport implementation native; give Dart a small interface for prepare/play/pause/seek/recover/close. Widget disposal should detach a view rather than independently orchestrate every native resource. Refactor incrementally behind existing adapters and regressions; no mass state-management-framework migration is needed. Tokio documents cancellation plus waiting for task completion as distinct shutdown concerns. [Tokio shutdown](https://tokio.rs/tokio/topics/shutdown).

### 4. Medium: credential settings have no atomic record update

**Observed:** `lib/settings/provider_settings.dart:61` writes host, port, username, password and connection count as separate awaited operations. `load` reads them independently. A failure or process termination partway through save can leave a mixture of old and new settings. Concurrent loads can also observe an intermediate combination. No injected platform-storage failure was run during this review.

**Remedy:** store one versioned credential-bearing settings envelope through secure storage, with serialized writes, validation and recoverable migration. Retain the old keys until the new record is verified. A single record reduces partial field updates; do not promise transactional guarantees beyond those of the underlying OS storage.

### 5. Medium: library persistence is approaching the limits of JSON-in-secure-storage

**Observed:** history and watchlist use serialized read/modify/write JSON blobs (`playback_history.dart:166`, `watchlist.dart:91`). Their process-local queues correctly prevent overlapping writes in this process. History has a 25-record budget, while Player periodically persists progress every five seconds. This is small today; there is no measured storage bottleneck in this review.

**Consequence:** canonical identities, release variants, episodes, playlists and future sync/deletion semantics need more than independent blob updates. Corrupt JSON is treated as empty by these loaders, which can mask the distinction between a new library and damaged state. In-memory queues do not supply cross-process transactions.

**Remedy:** define one library repository interface before choosing a database package. SQLite is a strong candidate for migrations, queries and atomic multi-record updates. Preserve edition isolation and protect sensitive viewing history: plain SQLite is not encryption. If encryption is required, select a maintained encryption solution, protect its key with OS secure storage, and test backup/recovery. Keep secrets out of ordinary library tables. Do not migrate the whole app just to remove small preference blobs. [SQLite application format](https://www.sqlite.org/appfileformat.html), [atomic commits](https://www.sqlite.org/atomiccommit.html).

### 6. Medium: custom HTTP protocol maintenance remains expensive

**Observed:** `rust/src/engine/http.rs` now uses `url::Url`, rejects malformed/userinfo input, enforces downgrade/destination rules and sanitizes errors. Earlier criticisms that it simply strips userinfo or lacks a URL parser are stale. It still implements its own HTTP/1.1 client with fresh connections and `Connection: close`.

**Recommendation:** evaluate a maintained client for outbound indexer requests, retaining the existing exact-origin credential and post-DNS/redirect policy. Reusable clients can pool connections; that does not establish a measured speedup here. A naive client replacement with default redirects or proxy behavior could regress security. Keep custom media range semantics where required; replacing the outbound client does not require replacing the entire streaming server. [reqwest client pooling](https://docs.rs/reqwest/latest/reqwest/struct.Client.html), [redirect policy](https://docs.rs/reqwest/latest/reqwest/redirect/).

### 7. High for public promotion: build consistency is ahead of publisher trust

**Observed:** the Legacy updater validates fork/tag URLs and hashes, but obtains installer and hash from the same release domain (`lib/update/windows_update.dart:44`). Publisher-verification PowerShell exists separately; the updater does not invoke it. New editions intentionally disable updates until independent channels exist. Toolchain/action references include `rust-toolchain@stable`, `windows-latest`, Android's latest runner NDK and action version tags. These are mutable inputs, despite locked packages and source SHA resolution.

**Remedy:** integrate real publisher identity and a separately trusted signed manifest, edition/platform binding, rollback policy and key rotation. Pin reviewed Actions SHAs and an explicit supported Rust/NDK combination; record SDK/native tool versions and produce per-platform SBOM/provenance. Schedule reviewed updates so pinning does not become neglect. These changes complement, rather than replace, artifact hashes. [GitHub immutable Action references](https://docs.github.com/en/actions/reference/security/secure-use).

### 8. Medium: edition preparation is a useful guardrail, not a finished modular architecture

**Observed:** `tools/prepare_edition.py` prunes source inputs, uses a reviewed Clean import allowlist, rewrites identities and substitutes Restricted routes in staged source. Native/Dart checks and final bundle audits are valuable. However, text replacement of `main.dart` and settings routes remains sensitive to source shape. Clean currently has no usable catalogue or playback.

**Remedy:** move route/provider registration to explicit edition composition modules, then reduce source rewriting to generated, validated build metadata/platform configuration. Preserve build-time exclusion and artifact audits. Do not trade actual exclusion for a hidden runtime toggle. The current shared process/native C ABI is an application access control mechanism, not a sandbox against hostile same-user native code; Windows device authentication is not proof of age.

### 9. Medium: platform support and test evidence remain asymmetric

**Observed:** shared verification runs on Windows; packaging workflows cover other targets, and independent candidate preparation already exists. The combined Legacy publication workflow still depends on all four platforms. Existing integration tests include native trailer, Dolby Vision and keychain paths, but their presence is not evidence of recent device execution. Published support should follow executed evidence.

**Remedy:** maintain a matrix of built/tested/device-validated/published states. Add representative real start/seek/resume/cast checks, Android TV D-pad/back lifecycle and Windows clean-user upgrades. Add malformed archive/range/parser fuzzing and cancellation stress fixtures; scan dependencies and native inventories without representing scanner silence as proof of safety. Finish independently promotable publication, rather than blocking a desktop fix on unavailable unrelated signing.

The source Android manifest also lacks an explicit secure-storage backup policy, and native 16 KiB page-size compatibility has not been established for the bundled prebuilts. These are required verification tasks, not demonstrated disclosure or compatibility failures. The supporting research gives exact upstream guidance. The current mpv manual also describes `auto` and `auto-safe` as aliases, so the decoder-selection comment should not be treated as performance evidence without checking the shipped version.

Documentation has drifted: README identifies a 1.25 candidate while the working pubspec is 1.27 and separate historical candidate artifacts exist. Use the artifact source manifest as authority, and generate release-status documentation from that state rather than relying on copied candidate summaries.

## Performance evaluation

The recently audited Restricted Windows directory is approximately **91.3 MiB uncompressed**. Its largest files are libmpv 28.4 MiB, Flutter engine 20.3 MiB, AOT app 10.9 MiB and Rust DLL 5.2 MiB. These are bundle sizes, not RAM consumption, startup time or compressed installer size. An Electron/Tauri rewrite cannot be justified from these figures.

The segment cache in `rust/src/engine/nntp_source.rs:59` is FIFO and capped by segment count. Different segment sizes and multiple archive-volume sources mean that this is not a single process-wide byte budget. Prefetch is currently a fixed depth (8 for normal media, 4 for archive sources). That is a profiling opportunity, not a demonstrated leak. Seek-heavy workloads may benefit from a byte-budgeted cache or changed replacement policy, but first measure cache hits, resident bytes and cancelled work. Existing stream-owned cancellation is worth preserving.

Collect local median/p95 startup-to-first-frame, seek latency, rebuffer time, native queue depth, decoded-cache bytes, temporary-disk high-water mark and dropped/decoded frames. Separate plain media, STORE archives, compressed/encrypted archives and repair paths. Compressed distant seeks may be constrained by sequential archive work rather than network speed. Do not promise instant seeks in every archive format or add aggressive prefetch that consumes the entire release. Profile Dart frame time and image decoding independently of native throughput.

## Technology alternatives and sequencing

- **Electron:** adds a Chromium/Node application runtime while native NNTP/archives and libmpv integration still need solving. It could help a web-specialist team, but no evidence here justifies migration cost.
- **Tauri/web UI + Rust:** retains Rust, but trades Flutter's shared UI for WebView/runtime variance. Native libmpv rendering and TV/mobile interactions require a prototype, not an assumed drop-in improvement.
- **Qt/C++:** strong desktop/media option; a rewrite would grow C++ ownership and discard current Flutter tests/features. No demonstrated benefit outweighs that cost here.
- **Platform-native media players:** useful for a deliberately smaller supported codec set. They would need a proven container/HDR/subtitle compatibility matrix before replacing libmpv.
- **Server-first/cloud backend:** unnecessary for a local-first player, adds hosting, privacy and availability obligations. Keep optional metadata/AI unavailable without impairing the core player.

Recommended order: (1) authenticate Android native artifacts and bound pre-authentication sockets; (2) establish native inventory, signed promotion and real-device baselines; (3) extract playback-session ownership and atomically persist settings; (4) introduce a durable library repository when implementing the richer identity model; (5) finish explicit edition composition and trusted Clean content; (6) only then expand optional integrations or supported platforms. Each stage needs its own regression and acceptance evidence. This review does not authorize or perform a rewrite, upgrade, install or release.

See [primary-source research](TECH_STACK_PRIMARY_SOURCES_2026-10-26.md) for framework/runtime contracts, Android backup/16 KiB native-library checks and the distinction between current documentation and actual bundled binaries.
