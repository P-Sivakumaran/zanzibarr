# Series episode navigation and release choice

Candidate: **1.30.0+31**, based on `3080da6` plus recorded working changes.

## Critical UI findings and changes

| Finding | Impact | Change |
| --- | --- | --- |
| Episodes followed trailers, cast and miscellaneous details | Watching a series required scrolling past secondary information | Episodes now follow the series header; Browse episodes scrolls and focuses the season selector |
| An expanding season-chip row and extra search dialog | Too much navigation before reaching an episode | One season selector, automatic initial season loading, direct episode search |
| Names hidden by a per-visit spoiler switch | Unnecessary uncertainty and repeated setup | Names default visible; independent persistent names, stills and summary controls live in Settings |
| Plain episode rows | Weak orientation and hierarchy | Numbered 16:9 episode graphics, optional verified TMDB stills, runtime/date/progress, one primary resume/play action |
| Skip-shaped buttons meant frame stepping | Expected next/previous episode behaviour was absent | Explicit episode transport beside Play; frame stepping remains in Advanced settings |
| Extra controls crowded narrow layouts | Small-screen/large-text overflow | Separate transport row on narrow players; stacked episode cards and wrapping actions |

## Behaviour and boundaries

Settings → **Series & playback** contains the opt-in automatic release choice,
sustained Usenet Mbps budget, preferred resolution cap and display preferences.
The user supplies the connection budget; this is not an automatic network speed
measurement or a claim about current NNTP throughput. Forty percent headroom is
reserved. Selection considers only the currently loaded first search page.

Automatic selection requires a single exact episode, known file size/runtime,
recognized resolution and an AVC encode. Packs, multi-episode files, samples,
conflicting identities and uncertain codecs remain manual choices. Resolution is
capped; equal-resolution matches prefer a heuristic bitrate/size balance rather
than the largest file. Low-bitrate sample-like candidates are excluded. This is
an estimate, not verification of encode quality, missing segments or hardware
decoder support. A visible explanation accompanies the choice; uncertainty shows
the release list without an automatic download.

Player Previous/Next pauses local playback, saves the exact release checkpoint,
resolves actual catalog neighbours (including season boundaries), searches and
chooses/downloads the NZB. Cancelling or failing the lookup restores the original
playback state. A successful handoff rechecks canonical identity, saves again,
stops the old player/native session and replaces the route. Playheads are not
copied between releases. Episode identity and an OMDb key are required for player
catalog navigation; unavailable dates/catalog membership stop navigation with an
explanation. Specials stay separate. Casting and unidentified/local-file playback
do not expose episode transport. This feature does not silently advance at EOF.

Episode stills/runtime use the existing configured TMDB token and bounded image
loader. A verified IMDb-to-series mapping precedes one lazy season request;
responses are bounded, persistently cached and matched by season/episode numbers.
No per-episode request fan-out, AI artwork lookup or guessed still URLs. Existing
artwork opt-in remains effective. Missing images use numbered graphics. Plot
summaries remain hidden by default. TMDB attribution accompanies supplied images.

Provider contracts checked against the official [season details](https://developer.themoviedb.org/reference/tv-season-details)
and [external-ID lookup](https://developer.themoviedb.org/docs/finding-data)
documentation. Optional secure-settings reads now have cancellable deadlines so
an unavailable settings backend cannot leave the episode catalog waiting forever.

## Verification

Focused tests cover preference persistence/failures, connection/size ranking,
wrong IDs and episode numbers, packs, missing runtime, season boundaries, specials,
unaired episodes, cached verified stills, cancellation, automatic/manual search
handoff and 360/390 px players at 200% text. Desktop and narrow widget previews
are inspected under `dist/audit/series-episodes-*.png`.

The fresh ordered working-tree gate passed: 280 Rust tests, Clippy with warnings
denied, clean Flutter analysis (including the isolated release entrypoint), host
native build, 510 Flutter tests (10 optional skips), and whitespace validation.
The focused suite passed 52 tests with one existing screenshot skip; two final
font-loaded previews passed separately after the episode section moved upward.
Logs are in ignored `dist/audit/series130-*.log`.

Windows release build passed in 101.4 seconds with resource version 1.30.0+31.
Unsigned setup (30,046,075 bytes) and portable ZIP (39,443,118 bytes) are in
`dist/windows/v1.30`. SHA-256, installer header, ZIP CRC and all 64 bundle file
hashes passed, including AOT code, native/CRT/WebView runtimes, notices and guides.
Installer signature status is NotSigned. Lifecycle smoke stopped at the existing
installation guard; the installed copy remains intact. No clean-user installation,
live provider transition, commit, push or publication is claimed.

The isolated source inventory records 875 file hashes in
`dist/candidates/v1.30/SOURCE.json`, using the filtered
`dist/entrypoints/v1.30/main.dart` and explicit build version overrides. Root
pubspec version and unfinished hosted-catalog work are preserved/excluded. The
baseline Settings route includes the new Series & playback entry. Prior v1.28
and v1.29 candidates remain unchanged. Existing CMake plugin developer warnings
were retained; they did not fail the build. Live provider
catalogues, NNTP playback transitions, TV remotes, casting and clean-user installs
require separate validation; synthetic tests do not establish physical playback.
