# Metadata and library implementation - 19 October 2026

Candidate: **1.18.0+19**, on `kepler/fix-zanzibar-icon`, with the existing
uncommitted 1.17 chat/keyboard work preserved. No commit, push or publication.

## Interface and source

Reviewed the real Figma file `rTvTd3yopeT26JEmVneFYU` through metadata,
design-context and screenshot tools. Home uses Minimalist's layout and spacing
with Cinematic's quiet dark surfaces; the coral brand, icon and animated
wordmark remain. Material controls reuse the app's Flutter themes and focus
indicators. Provider imagery stays dynamic. Fictional Figma artwork is used
only in opt-in Flutter previews, never attached to actual releases.

- [Home preview](screenshots/metadata-home-flutter.png)
- [Title preview](screenshots/metadata-title-flutter.png)
- [Library preview](screenshots/metadata-library-flutter.png)

Preview titles, dates and ratings are test data, not live provider results.

Home, indexer metadata search, AI title matching and the library share the new
full title page. Local title saves are bounded to 300 entries and serialize
writes through a shared store. Storage failures retain the visible saved state
and surface a retry. Series tracking and playback history remain their existing
stores; Resume uses the saved release path/entry key and original recovery flow.

OMDb's existing explicit HTTPS requests supply posters and selected-season
catalogs. The [official OMDb documentation](https://www.omdbapi.com/) records
season/episode queries and totalSeasons. We do not use its separate patron-only
Poster API. Requests retain the existing 15-second, 1-MiB, coalescing and
100-entry/six-hour cache limits. Cached title fetch timestamps and provider
names survive library saves. Optional metadata plugins accept old fields and
can implement `metadata_season` with OMDb-compatible Season/Episodes objects.

Artwork is separately opt-in, default off, using a persisted boolean. Only
HTTPS URLs on approved Amazon/IMDb/TMDB image hosts are accepted; credentials,
query strings, explicit ports and redirects are refused. Downloads are bounded
to four active and 32 pending requests, 15 seconds and 5 MiB; source images are
limited to 8 megapixels and decoded to at most 500px wide. The thumbnail-byte
cache has a 20-MiB/60-entry/six-hour bound. Flutter's own image cache remains
separately bounded by its framework defaults. There is no disk artwork cache.
Disabled/cleared images invalidate pending cache insertions and keep text/actions
usable. Loading failures never expose response bodies or credential URLs.

Season lists are explicit provider data, not inferred next-integer episodes.
Episode rows merge exact IMDb/season/episode history, hide spoiler titles by
default, and distinguish future air dates from unchecked release availability.
The older local Up next suggestions remain accessible as local search hints;
they are not authoritative season catalogs.

Language preferences are independent from the app locale. ISO aliases and region
subtags are normalised against existing native locale names. Audio/subtitle
preferences choose only matching detected tracks; missing preferences preserve
player defaults, and manual/external choices stop later automatic selection.
The media_kit track model does not expose reliable forced/SDH flags: existing
track titles are preserved and no accessibility marker is invented. App text
uses existing translations with English fallback for new copy; OMDb text is not
translated. Region flags and ordered multi-language preferences are not added.

## Verification

Fresh ordered gate: 266 Rust tests passed; Clippy passed; Flutter analysis
reported no issues; native host build passed; 351 Flutter tests passed with
9 opt-in screenshot skips. Release input validation for v1.18 passed. Logs
are under ignored `dist/audit/metadata-*.log`.

The new regressions cover exact episode-search identity, future-episode action
gating, specials/deduplication, old plugin fields, save failures, the full-library
limit, 360px/200% text/RTL layouts, known-release Resume, image URL/redirect/body
limits, four-request concurrency, language aliases and preference persistence.
Compatibility checks retain history recovery, favorites and D-pad navigation.
The preview harness separately renders actual Flutter widgets with the provided
Figma source artwork; those screenshots use fictional sample metadata.

Windows release build passed (128.5 seconds), with executable version
`1.18.0+19`. Bundle: `build/windows/x64/runner/Release/`; launch
`zanzibarr.exe` from that folder with its DLLs and data retained. Executable
SHA256: `3e43ab2599e46269f11407e1e51c5b9aaffb354020540a7834ea430de01d77a6`.
This is an unsigned local build; existing dist/windows installer packages were
not replaced. No installer was created or installed in this turn.

The opt-in preview test passed separately and refreshed the Home, title and
library PNGs linked above. The supplied image is retained under
`test/fixtures/figma/` with provenance and regeneration instructions. Native
Windows rendering is not inferred from these widget previews.

Release inputs and final whitespace checks passed.

No live OMDb/plugin calls, indexer checks, model requests, installer lifecycle,
physical TV/phone playback or Windows rendered-native accessibility audit has
been performed for this candidate. Device behavior is not established by
widget previews or a host build.
