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
