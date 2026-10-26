# Tech stack: primary-source deployment and maintenance review

Reviewed 2026-10-26. This supporting review compares the current working-tree dependency contracts with official documentation and upstream projects. It is static research, not a security scan, build, playback benchmark, licence opinion or device certification. No dependencies were changed. Online documentation can describe newer releases than this checkout.

## Observed versions and decisions

| Layer | Repository evidence | Assessment |
| --- | --- | --- |
| Flutter / Dart | Workflows pin Flutter 3.44.6; pubspec requires Dart ^3.12.2 | Keep the framework; validate upgrades deliberately against native plugins and devices. |
| Rust bridge | Dart and Rust exactly 2.12.0 | Keep generator/runtime aligned; retain generated-code checks and native-library identity checks. |
| Playback | media_kit 1.2.6, media_kit_video 2.0.1, media_kit_libs_video 1.0.7 | Suitable wide-format playback abstraction, but package versions do not identify all native decoder bytes. |
| Native media packages | Windows 1.0.11; Android path override 1.3.8; macOS path override 1.1.4; iOS 1.1.4; Linux 1.2.1 | Treat each platform as a distinct runtime distribution with separate provenance and playback evidence. |
| Browser | flutter_inappwebview 6.1.5; Windows implementation 0.6.0 | Appropriate optional trailer surface; an additional browser engine and data store, not part of core NNTP playback. |
| Secrets | flutter_secure_storage 10.3.1; Windows implementation 4.1.0 | Appropriate for credentials. Platform key lifecycle and backup behavior still need explicit handling. |

Values above come from pubspec.yaml, pubspec.lock, rust/Cargo.toml and .github/workflows in the reviewed working tree. They are not statements about latest releases.

## Flutter and TV: keep the shared UI, narrow support claims

The current Flutter supported-platform document describes Flutter 3.47, not this repository's 3.44.6. It distinguishes supported platforms from those tested on every commit. Its newer OS floors cannot be copied into this app's support claims without inspecting the historical matrix and effective plugin/native deployment targets. The package README's older OS claims do not override the framework and every native dependency. [Flutter platform support](https://docs.flutter.dev/reference/supported-platforms)

Android TV needs explicit remote navigation, initial/visible focus, predictable Back behavior and testing that every visible action is reachable. A phone UI compiling for Android does not establish TV usability. Keep common data/domain services, but budget for TV-specific interaction acceptance tests and actual remotes. This is an architecture inference from Android's interaction contract, not a request to rewrite Flutter in Compose. [Android TV navigation](https://developer.android.com/training/tv/get-started/navigation)

Performance decisions should use profile/release measurements on target devices. Separate Flutter frame timings from native decoder load, buffering and NNTP/archive timing; a smooth widget benchmark cannot establish seek or decoder performance. [Flutter profiling](https://docs.flutter.dev/perf/ui-performance)

## FRB: useful boundary with explicit lifecycle ownership

The pinned bridge has an upstream 2.12.0 release. Current quickstart documentation includes a Native Assets integration backend requiring at least 2.13.0-beta.2; that is not an available drop-in assumption for this pinned build. Keep the existing builder until an isolated migration proves packaging parity. The documentation also requires regenerating glue when exported Rust APIs change. [FRB 2.12 release](https://github.com/fzyzcjy/flutter_rust_bridge/releases/tag/v2.12.0), [FRB quickstart](https://cjycode.com/flutter_rust_bridge/quickstart)

Engineering implication: Rust should own fetch/decode/archive resources and cancellation; Dart should own presentation and user intent. A Future completing or timing out is not evidence that a child native task stopped. Keep explicit session identities, cancellation tokens, bounded queues and stale-result checks. This recommendation derives from the app's asynchronous/native boundaries; this review does not claim FRB itself provides or lacks automatic cancellation for every call mode.

## Native media: the highest maintenance and provenance burden

media_kit intentionally separates control, rendering and native-library packages. Its cross-platform codec and acceleration features make it a strong fit for this application. Those advertised capabilities remain dependent on actual native builds, drivers and codecs. [media_kit upstream](https://github.com/media-kit/media-kit)

Confirmed repository gap: vendor/media_kit_libs_android_video/android/build.gradle:62 obtains four JARs from envermeister/libmpv-android-video-build release v1.1.7-dv.5 with URL.openStream() at line 77, trusts existing cached files at line 73, and checks no expected digest or signature. The comment at line 61 explicitly records removal of MD5 verification. The Dart lockfile records this override as a local path dependency; it does not authenticate the separately fetched native payloads. This is a supply-chain verification gap, not proof the binaries are malicious. Pin independently reviewed SHA-256 values, preserve source/build provenance and inventory each embedded SO. A checksum alone still does not establish publisher authenticity.

The macOS override packages /opt/homebrew/lib/libmpv.2.dylib and dependencies using tools/bundle_mpv_framework.py:24 and line 119. That makes the developer's installed native dependency graph part of the release input. Capture exact source revisions, build flags, architectures, effective minimum OS, linked dylibs, hashes and licences in the candidate manifest. Preserve known Dolby Vision and archive callback fixes when replacing builds; do not trade verified compatibility for a generic dependency cleanup.

mpv's manual describes auto-safe as an alias of auto. The Android-versus-other-platform selection at lib/player/player_screen.dart:414 has a comment at line 409 suggesting different decoder behavior. Verify the actual shipped mpv version before relying on that explanation. Measure active hwdec-current and dropped frames rather than the requested setting alone. [mpv hardware decoding documentation](https://mpv.io/manual/stable/)

Android's native page-size requirement concerns all packaged native libraries, including third-party prebuilts. New AGP/NDK versions alone cannot fix old embedded ELF alignment or runtime assumptions. Inspect every ABI and run an actual 16 KB device/emulator test before claiming compatibility. No compatibility failure was reproduced here. [Android 16 KB compatibility](https://developer.android.com/guide/practices/page-sizes)

The wrapper's licence does not settle native-library redistribution obligations. mpv is GPL by default with an LGPL-compatible build path subject to its stated conditions; FFmpeg's resulting licence depends on enabled components. Record the actual configure flags and source obligations for the binaries shipped. Noncommercial distribution does not determine those build facts. Obtain appropriate legal review rather than inferring compliance from a package README. [mpv copyright](https://raw.githubusercontent.com/mpv-player/mpv/master/Copyright), [FFmpeg licence](https://raw.githubusercontent.com/FFmpeg/FFmpeg/master/LICENSE.md)

## Browser: optional capability and independently serviced runtime

InAppWebView documents Windows runtime detection and a writable custom user-data directory. Linux is absent from this widget's supported-platform list. Preserve the app's external fallback instead of assuming browser-plugin parity. [InAppWebView deployment notes](https://inappwebview.dev/docs/webview/in-app-webview/)

WebView2 Evergreen receives runtime updates independently of the app; Fixed Version shifts servicing to the app distributor and adds more than 250 MB. Existing environments can continue using the old engine until recreated or the app restarts. Prefer Evergreen with availability checks, bounded navigation/origin rules and fallback; periodically test forward compatibility. An installed Edge browser is not the production WebView2 deployment contract. These are deployment recommendations, not evidence the current trailer code is vulnerable. [Microsoft WebView2 distribution](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution)

## Secrets: keep the plugin, test lifecycle and isolate bulk state

Secure-storage upstream documents Android 10.x cipher migration and warns that Android backup restore can fail to unwrap keys; it instructs disabling backup or excluding its shared preferences. This checkout's application element at android/app/src/main/AndroidManifest.xml:20 does not explicitly declare allowBackup, dataExtractionRules or fullBackupContent. Inspect the merged release manifest and define an intentional backup policy; this source observation does not prove a credential disclosure. Linux needs libsecret at build/runtime. [flutter_secure_storage upstream](https://github.com/juliansteenbakker/flutter_secure_storage#disabling-auto-backup)

The locally resolved Windows 4.1.0 package README describes AES-GCM-encrypted support-directory files with keys in Windows Credential Manager. Edition key prefixes and support directories help isolate app state, but do not provide a hostile-local-user sandbox or independently encrypted viewing profile. Device authentication likewise is not age assurance. Keep credentials here; evaluate transactional storage separately for growing library/history caches, with corruption recovery and schema migrations. The latter is an architectural recommendation, not a measured secure-storage performance defect.

## Priorities supported by this review

1. Inventory native runtime bytes and build flags; authenticate Android downloads and audit macOS provenance.
2. Define Android backup policy and validate 16 KB native compatibility.
3. Run a narrow physical playback/seek/HDR/audio/remote matrix before widening platform claims.
4. Keep Flutter, Rust, FRB and media_kit; avoid a framework rewrite without a reproduced limitation and comparative prototype.
5. Keep browser, AI and metadata failures outside the playback-critical path. Maintain explicit per-platform deployment and servicing responsibilities.

No CVE applicability, package abandonment, authenticated provider compatibility or latest-version upgrade necessity was established by this research.
