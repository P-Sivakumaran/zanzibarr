# Interface refinement - 1.19

This pass follows the user's request for better button placement, wider content,
easier playlist access, artwork in recommendations and playlists, and useful
metadata visualization. It preserves the existing uncommitted 1.17/1.18 work.

## Organization

Home, title details and discovery now share a 1320px desktop content limit.
Home groups labelled Browse, My library, Playlists and Ask AI actions together.
Open NZB and indexer search sit side by side above 800px, with a stacked layout
on phones and at larger text sizes. The library also links directly to playlists.
The fixed Home toolbar retains its separate viewport space and visible focus.

Opening playlists starts on the saved collection tab without launching the AI
connection. Switching to Chat by tab, swipe or keyboard initializes the existing
connection flow. Reordering, renaming, deletion confirmation and optimistic
playlist persistence remain intact. Collection management actions align with
content rather than floating in the middle of an otherwise wide row.

## Artwork and metadata

Recommendations and playlist entries share poster cards. Collapsed playlists
show a cover from their first matched title. A separate, bounded cache preserves
up to 100 user-confirmed title matches without changing the playlist format.
Matching explicitly searches OMDb with the suggestion's media type, asks the user
to choose a result, and verifies the returned identity and type before saving.
AI-supplied IDs remain untrusted, and release search retains its existing flow.
Failed writes preserve the previous match. Corrupt saved data blocks replacement
until a successful retry; it is never silently overwritten.

Use **Metadata & artwork** in discovery's toolbar to configure OMDb and enable
**Load artwork**. Poster requests retain the existing approved-CDN policy,
bounded concurrency, timeout, decode and cache limits. Metadata matching and
image loading remain optional; existing playlists work without either.

Source-labelled rating meters show their original numeric scales (IMDb /10,
Rotten Tomatoes /100 and Metacritic /100). They animate for 450ms and immediately
show their final value when reduced motion is requested. Missing or invalid
scores do not acquire a fabricated meter. Playlist film/TV composition uses a
small proportion bar and visible counts; it does not claim viewing completion.
Scores from OMDb remain labelled as such, with no implied direct RT integration.

Poster fallbacks now scale into compact covers. The new checks also caught and
fixed an asynchronous return from the artwork preference setState callback.

## Rendered previews

Actual Flutter widget renders use the existing Figma fixture image and fictional
sample metadata. The account and inference responses are test doubles.

- [Desktop playlists](screenshots/playlists-1440-flutter.png)
- [Phone playlists at 140% text](screenshots/playlists-360-flutter.png)
- [Recommendations with matched artwork](screenshots/suggestions-artwork-flutter.png)
- [Home](screenshots/metadata-home-flutter.png)
- [Title](screenshots/metadata-title-flutter.png)

Regenerate the new previews with GENERATE_LAYOUT_SCREENSHOTS=1 and
`flutter test --no-pub test/suggestion_metadata_test.dart --update-goldens`.
Home/title/library previews use GENERATE_SCREENSHOTS=1 and the existing
metadata_library_test.dart preview case. These renders do not establish native
Windows or physical TV behavior.

## Verification

Fresh ordered gate: 266 Rust tests passed serially; Clippy and Flutter analysis
passed; the native host build passed; 356 Flutter tests passed with 9 opt-in
screenshot skips; `git diff --check` passed. The initial parallel Rust run had
three localhost fixture socket failures (Windows WouldBlock 10035); the serial
rerun passed without source changes. Logs are under ignored `dist/audit/layout-*`.
Release inputs for v1.19 validated successfully. The five focused metadata/UI
checks and the existing Home/title/library preview case passed separately with
screenshot generation enabled.

New regressions cover user-confirmed identity persistence, write failure recovery,
corrupt-cache protection, film/TV separation, reduced-motion final meter values,
poster reuse in saved lists and recommendations, 360px/140% text layout, and
playlist-to-chat navigation without initializing AI on the playlist route.
The existing full suite retains keyboard, D-pad, draft recovery and deletion
confirmation checks.

Live OMDb requests, actual AI inference, rendered native Windows UI, installer
lifecycle, physical playback and TV focus have not been verified in this pass.
No commits, push, installation or publication were performed.


Windows release build passed in 113.1 seconds at version 1.19.0+20. Bundle:
`build/windows/x64/runner/Release/`; launch `zanzibarr.exe` with its accompanying
DLLs and data retained. Executable SHA256: `728c13a545daa8b667b6b85c0d8e73acfbeaea635fc6187df499f2b689c8b070`.
Unsigned local build; the existing dist/windows installers were not replaced.
