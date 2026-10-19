# Film-card navigation, trailers and icon refinement

Candidate **1.24.0+25**, continuing 1.23.

## Interaction

AI recommendation and playlist cards now open a dedicated information route when
clicked, including poster/title/background; Details & trailer makes that action
explicit for keyboard/remote users. Search and playlist controls remain separate.
Repeated taps cannot push duplicate routes. Identification starts inside the route;
if background identification is already running, the page listens for its result.
Back restores the discovery/playlist screen. Find releases on the details page
returns the canonical selection through the existing search callback.

Existing title pages remain usable from cached metadata when refresh fails.
Retry stays available. Unidentified suggestions offer setup/retry/rematch without
accepting an AI-supplied IMDb ID or trailer URL.

## Trailer source and embedded playback

The existing verified IMDb-to-TMDB mapping and external-ID check gate trailer data.
Videos are appended to the same TMDB detail request as credits and keywords, with
no additional per-title request. Cache key v2 refreshes older snapshots once;
normal bounded persistence, absence/retry windows and secure credentials remain.
Only official YouTube Trailer/Teaser records with valid 11-character keys qualify.
Trailers outrank teasers; English is preferred within each type. No clips, reviews,
fan uploads, arbitrary URLs, scraping or AI-provided video IDs are used.

Title pages show source attribution and a Load trailer button. No platform view or
YouTube connection is created before that action. Standard YouTube controls remain
visible, without autoplay. The embed uses youtube-nocookie.com, an app-identity
Referer, at least 200 pixels height and a responsive 16:9 viewport. It never
extracts or proxies video streams. Only the selected embed is allowed as main-frame
navigation; popup windows and browser permissions are denied. Close removes the
webview; application backgrounding pauses playback. A timeout/load error offers
retry or explicit external viewing. Setup returns to refresh trailer discovery.

flutter_inappwebview 6.1.5 supplies native embedded webviews, including Windows
WebView2. Windows checks for its Runtime before creating a view and uses a writable
application-support data directory. Linux uses external viewing. Other platforms
are supported by the dependency but remain unverified here. The embedded player
may be blocked by a video owner or region; external viewing is always available.

Primary references:
- [TMDB append-to-response](https://developer.themoviedb.org/docs/append-to-response)
- [Flutter InAppWebView setup](https://inappwebview.dev/docs/intro/)
- [YouTube embedded-player identity, sizing and playback requirements](https://developers.google.com/youtube/terms/required-minimum-functionality)

## Logo refinement

The previous sun touched the inner diagonal border at small sizes. The revised
asset lowers it into clear sky, with a visible gap from the triangle, a warm disc,
subtle halo and simple water reflection. Removed diagonal rays and kept the palms,
sailboat, navy tile and coral triangle. Inspected the source and 256-pixel icon.
Generated platform sizes and Windows ICO from the checked-in source using the
existing repository script; iOS remains opaque as required by that pipeline.

Built-in imagegen edit, source `assets/zanzibarr-icon.png`; final source remains at
that path and Home uses `assets/zanzibarr-icon-256.png`. Prompt: preserve the navy
rounded tile, coral outlined play triangle, palms/sailboat; move sun down/left with
clear sky between its halo and the diagonal, remove long rays, add restrained warm
disc/reflection, crisp small-size silhouettes, no text or new objects, true
transparency outside the tile. Full generated source was copied into the repo;
platform images come from `python tools/generate_icons.py`.

## Verification

Fresh ordered gate passed: 270 serial Rust tests, Clippy with warnings denied,
Flutter analysis, native host build and 393 Flutter tests (9 screenshot skips),
plus whitespace checks. Five added regressions cover trusted trailer selection,
verified/cached lookup, click-to-load/error/close handling at narrow large text,
identification already in progress, and card-versus-search navigation.
Windows build/package evidence follows when complete. Logs: ignored
`dist/audit/trailer-*`. Live configured TMDB and native trailer playback are not
claimed until separately exercised. No release is signed or published.


Additional rendered verification: 34 preview checks passed with refreshed Home,
resume, title and AI discovery screenshots. Inspected actual desktop recommendation
and title widgets, plus the generated 256-pixel icon. These are widget renders,
not native video playback proof.

Windows build tooling uses a local NuGet 6.14.0 executable fetched from Microsoft's
NuGet distribution endpoint; its Microsoft Authenticode signature was valid.
The plugin pins WebView2 SDK 1.0.2792.45, WIL 1.0.231216.1 and nlohmann/json 3.11.2.
Required third-party license/notice files are retained in `assets/licenses` and
included by the Windows packaging script, together with TMDB attribution.


Windows release build passed in 445.3 seconds, executable resource version
1.24.0+25. Native flutter_inappwebview plugin and WebView2Loader DLL are included.
The dependency emitted CMP0175 and C4244/C4458 warnings; the build completed
successfully without weakening project checks or modifying vendored code.


## Packaged candidate

Preview: `dist/preview-1.24/zanzibarr.exe` (keep its complete directory).
Unsigned setup/portable ZIP: `dist/windows/v1.24`. Packaged source fd10fb3;
application implementation 64f97e8, with packaging/notices and screenshots in
40246e0/fd10fb3. BUILD-INFO retains the full SHA. No app source changed during build.

| Artifact | SHA256 |
| --- | --- |
| zanzibarr-windows-x64-setup.exe | 33ee018b0d9e580e7048a1f1002dd2f45a18b76262bca31af5ac738c95c71d2c |
| zanzibarr-windows-x64.zip | f00b340b45f37f422f584e023706e0995ce25c2705d9ac771a52f43599354077 |

Verified SHA256SUMS, ZIP CRC/74 entries, native webview and loader, CRT, media/AOT
components and notices. Packaged executable/plugin equal the preview binaries.
Installer lifecycle smoke stopped at its existing-installation guard:
"An installed copy exists; use a fresh user/VM for the smoke test". No existing
installation was replaced. Unsigned, not installed or published. Live configured
TMDB, native embedded video playback, clean-user installation and other devices
remain unverified. Logs: `dist/audit/trailer-*`.
