# Windows trailer player configuration error

Candidate **1.25.0+26**, fixing 1.24. Source baseline: 1c9a734.

## Reproduction and cause

Built an isolated native Flutter/WebView2 probe using the same URL, headers,
settings and navigation filter as the app, with YouTube's documented API example
video M7lc1UVf-VE. No OMDb/TMDB credentials, library data or existing browser profile
were used. Two runs returned:

```json
{"referrer":"","origin":"https://www.youtube-nocookie.com","error":"Video player configuration error","player":true,"state":-1,"title":"YouTube"}
```

The WebView2 Runtime was installed (155.0.4283.62). Adding the origin query
parameter did not help; disabling the navigation filter did not help. Navigation
with an actual browser referrer, after initial navigation had completed, removed
the error and reached cued state 5. This distinguished the browser navigation
context from an HTTP Referer override. The original probe was red-capable and
ran unattended in about 20 seconds after its one-time build.

## Correction

Windows creates the webview without an initial direct URL request, then uses
WebView2's internal Page.navigate API with the selected trailer URL, the stable
installed app identity as referrer and strictOriginWhenCrossOrigin policy.
Other native platforms retain the documented HTTP Referer path. A shared
navigateTrailer function owns this distinction; network details are sanitized
before propagating navigation failure to the existing retry UI. Initial blank
page completion no longer cancels the actual trailer's loading timeout.

No remote debugging endpoint is enabled in the application. Diagnostic probes
used a loopback endpoint only for their owned browser process and shut it down
with the probe. No video streams are extracted, proxied or bypassed. Existing
manual load, no-autoplay, popup/permission restrictions and external fallback stay.

## Native proof

Two runs through the corrected production navigation helper returned the app
referrer, no error and cued state 5. A further muted, gesture-authorized native
playback check reported:

```json
{"referrer":"https://com.zanzibarr.zanzibarr/","error":"","state":1,"time":4.007251,"width":1280,"height":720}
```

This exercises the shipped Windows webview/plugin path and actual video decoding,
not a simulated player. It proves the tested YouTube API example works on this
host; it does not prove every trailer, regional availability, clean installation
or other devices. Video-owner restrictions remain subject to YouTube.

Three offline regressions cover browser-navigation identity, sanitized navigation
failure and unchanged headers elsewhere. The opt-in native regression lives in
integration_test/trailer_native_test.dart, using isolated data and a public API
example; it asserts the referrer, player error state and advancing decoded video.
The normal offline suite never opens YouTube. Live tests need WebView2/network.

Native command for a future Windows debug integration run:

```powershell
flutter test integration_test/trailer_native_test.dart -d windows --dart-define=LIVE_TRAILER_TEST=true --dart-define=TRAILER_AUDIT_DIR=C:/absolute/worktree/dist/audit/trailer-live
```

Create the audit directory first. The native release probe used this same helper;
the integration-test command above is retained for repeatability but was not run
here because release-mode Flutter Driver is unsupported. Diagnostic source,
JSON and logs are retained under ignored dist/audit/trailer-* as audit evidence.

The missing native-player seam in the previous widget-only verification allowed
this bug through. The new helper and opt-in native test check the browser identity
and decoding boundary rather than merely rendering a placeholder player.

References:
- [YouTube embedded-player identity requirements](https://developers.google.com/youtube/terms/required-minimum-functionality)
- [YouTube API example and error reference](https://developers.google.com/youtube/iframe_api_reference)
- [Chromium Page.navigate](https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-navigate)

Fresh ordered gate passed: 270 Rust serial tests, Clippy with warnings denied,
Flutter analysis, native host build, 396 Flutter tests (9 skips), whitespace.
Eight focused trailer tests passed, including the three new navigation regressions.
Windows build and packaging evidence follows below.
