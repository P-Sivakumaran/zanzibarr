# Automatic metadata and rating context - 1.21

The user requested automatic artwork/ratings with optional rematching, and
correctly written scores with review totals for context. This supersedes the
mandatory matching flow in 1.19/1.20; prior uncommitted work is preserved.

## Automatic identification

Configured OMDb access now enriches recommendations after an AI reply, playlist
covers on load, expanded playlist entries, and the featured resume title.
Users do not have to confirm each ordinary title. Rematch title remains as a
correction action. A known provider identity is preferred. Otherwise the app
requires a unique exact normalized title, matching movie/series type and release
year when known. Search requests include year filtering. Ambiguous, partial or
wrong-identity results stay unresolved rather than acquiring an arbitrary poster.
Filename parsing supplies only search hints, not proof of identity.

Each resolver coalesces identical pending work, runs at most two automatic jobs
at once and holds at most 32 waiting jobs. Batch loops are bounded to 100 entries
and stop when their controller closes. The existing timeout, response-size,
image-host, decode and cache bounds remain. No metadata key means no requests;
metadata outages do not prevent search, playlists or Resume. Poster loading
still respects the separate image preference; an existing disabled choice is
not changed by this upgrade.

Resolved suggestion metadata is cached locally. Existing corrections refresh by
their trusted ID, retaining the user's choice. Cache refresh fills missing IMDb
vote context and refreshes older snapshots. Writes are serialized, and a manual
correction invalidates an older automatic result. The displayed canonical title
and release-search selection now use the resolved provider identity. Home opens
that title directly rather than asking for another match. Unresolved suggestions
retain their original editable query and never trust an ID from AI JSON.

Resume enrichment saves the public metadata and, for newly identified entries,
uses the existing exact-entry history mutation. Current playhead, inner-file
identity, favorites and source recovery remain protected. Returning from Settings
or Browse retries metadata setup without restarting the app. Episode filename
years are not treated as series premiere years.

## Score wording and counts

- Rotten Tomatoes: **95% positive**, **Based on 240 critic reviews**.
- IMDb: **8.2/10**, **Based on 123,456 votes**.
- Metacritic: **82/100**, **Based on 45 critic reviews**.

These are format examples, not live claims about a film. RT is the percentage of
positive critic reviews, not an average grade of 95/100. IMDb is a weighted user
rating; Metacritic is a weighted critic score. Numeric scales are validated
before showing a meter. Singular/plural wording, exact grouped counts, missing
counts and invalid scales are handled separately. Missing values do not become
zero, approximate "1.2M" strings do not become fabricated exact counts, and IMDb
votes never become critic-review totals. Motion still respects reduced motion.

MediaTitle now stores optional per-source ratingCounts. OMDb imdbVotes is parsed
for IMDb. A metadata provider can return a positive integer Count alongside a
Ratings row's Source/Value; it is persisted without changing older payloads.
Standard OMDb responses can omit RT/Metacritic review totals. In that case the UI
says Review count unavailable. No count is scraped, invented or inferred from
the percentage. Actual counts across every title require a provider supplying
those fields; this candidate does not bundle a licensed review-data service.

Primary references consulted:

- [Rotten Tomatoes score definition](https://www.rottentomatoes.com/about)
- [IMDb weighted user ratings](https://help.imdb.com/article/imdb/track-movies-tv/weighted-average-ratings/GWT2DSBYVT2F25SK)
- [Metacritic score definition](https://www.metacritic.com/about-us/)
- [OMDb parameters](https://www.omdbapi.com/)

## Verification and preview

Fresh ordered gate passed: 266 Rust tests (serial), Clippy, Flutter analysis,
native host build, 373 Flutter tests with 9 opt-in screenshot skips, and
whitespace checks. The 22 focused checks passed earlier; the complete gate also
includes the added cached-correction/search-identity regression. Preview refresh
passed separately: five resume/settings cases, five suggestion/playlist cases,
and the existing metadata Home/title/library render case.

Ten new regressions verify type/year filtering, request coalescing and the two-
job concurrency bound, no requests without a key, ambiguity/partial-result and
wrong-ID rejection, numeric-title and series episode release hints, manual corrections overriding
late automatic results, cached correction refresh/search identity, per-source
count persistence/validation, vote/review grammar, invalid-scale handling, and automatic retry after returning
from Settings with a newly configured key. Final Dart-only fixes were followed
by fresh analysis and the complete Flutter suite. Logs use the ignored
`dist/audit/auto-*` prefix. Preview fixtures are fictional and include synthetic
review counts solely to demonstrate layout and wording. No live provider or
model call, installer creation, installation or publication is performed.


Updated Flutter previews:

- [Resume and rating counts](screenshots/resume-1280-flutter.png)
- [Suggestions](screenshots/suggestions-artwork-flutter.png)
- [Playlists](screenshots/playlists-1440-flutter.png)

Final Windows release build passed in 102.6 seconds at **1.21.0+22**. Open
`build/windows/x64/runner/Release/zanzibarr.exe` directly to preview without
installing. Keep the entire Release directory together for its runtime DLLs.
The binary is unsigned; native rendering and live playback were not verified.
