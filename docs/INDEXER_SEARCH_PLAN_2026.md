# Multi-indexer search — development plan (2026)

## Why

At the start of this plan, zanzibarr supported exactly one Newznab-compatible indexer
(`IndexerSettings` in `lib/settings/indexer_settings.dart` holds a single
`baseUrl`/`apiKey` pair). That's a real limitation: no indexer has full
retention/catalog coverage, free-tier accounts hit daily API-hit caps fast
(see rate limits below), and a single indexer going down or rate-limiting
you kills search entirely. Best-in-class Usenet search in 2026 means
querying several indexers at once and merging the results — the same
problem NZBHydra2 solves for the `*arr` ecosystem.

This doc is a living plan: update it as phases land or scope changes.

## Implementation status — 11 October 2026

Phases 1–5 are implemented locally. Phase 4 includes optional OMDb title
lookup and manual IMDb/TVDB search. Release search still works without a
metadata API key. No release or tag has been created.

- Profiles support add/edit/delete, enable/disable, and ordering. Up/down
  buttons keep ordering accessible to keyboards and TV remotes. Settings
  and search both expose enable/disable controls.
- Profiles are stored as one versioned JSON value inside OS secure storage,
  rather than separate per-profile keys. This makes each profile-list save
  a single storage write. Legacy single-indexer values migrate only after
  the new value is written successfully. Corrupt stored profiles surface a
  load failure instead of silently becoming an empty list.
- Save validates URL and API-key fields. The existing optional caps test is
  retained, allowing users to save configuration while an indexer is offline.
  Save failures keep the dialog and draft open; Cancel/Back protect edits.
- Native search fans out concurrently with per-request HTTP timeouts.
  Partial failures show a warning; complete failure offers retry. Failed
  sources retain their cursor so subsequent requests can retry them.
- Each source advances by its own raw result count, before deduplication.
  Exhausted sources are skipped. A deduplicated merged count is never used
  as an indexer offset. Missing totals continue until an empty source page.
- Results carry a stable profile ID separately from the display name, so
  duplicate nicknames cannot route a download to another profile's API key.
- Deduplication prefers the first profile in the saved order, independent
  of response timing. The native title/size rule is also applied across
  displayed pages for common release-name separators. Multi-source totals
  are omitted because the unique count is unknown until all pages arrive;
  a single source can still report its total.
- Presets implemented: NZBFinder, NZBgeek, nzb.su, NZBPlanet, DrunkenSlug,
  and Custom. These prefill configuration; they are not live availability
  checks or recommendations. nzb.life was not added.
- Movie and TV info opens an explicit title/IMDb lookup. Selecting the
  correct title/year opens details with synopsis and source-labelled IMDb,
  Rotten Tomatoes and Metacritic scores when supplied by OMDb. Missing
  scores are absent; scales are preserved. Release filenames provide only
  lookup hints, never an automatically trusted identity.
- The optional personal OMDb key uses OS secure storage. Failed saves retain
  the draft; Cancel/Back confirm discarding edits. Requests use HTTPS with
  redirects disabled, a 15-second bound and a 1 MiB response limit. Metadata
  is cached only in memory (six hours, at most 100 entries), with concurrent
  identical requests coalesced and cache cleared when credentials change.
- OMDb settings includes a live Test API key action for the unsaved draft.
  Tests bypass the lookup cache and never save credentials. The outlined
  field accepts a key rather than a URL, trims outer whitespace, supports
  show/hide, and resets status after edits. Success, rejected credentials,
  quota exhaustion and connection/response failure have explicit messages.
- Precise release search also accepts IDs manually without OMDb. Native
  requests use `t=movie` / `t=tvsearch` only with advertised ID parameters.
  IMDb IDs lose the `tt` prefix for Newznab while retaining leading zeroes.
  TV episode search requires a season. Unsupported ID/episode parameters or
  failed capability discovery use the full title/year/episode text instead.
  Pagination retains the confirmed identity; editing the query clears it.

Regression coverage includes legacy migration, corrupt storage, profile
ordering/presets, failed-save draft recovery, D-pad traversal, duplicate
display names, stale responses after toggling, complete/partial failures,
and native per-source pagination after cross-indexer deduplication.
Metadata coverage includes explicit-request privacy, cache/coalescing,
credential isolation, malformed/oversized responses, safe errors, source
ratings, title hints, large text, failed-save drafts, capability fallback,
and preserving/clearing identity across pagination/query edits.
Live OMDb, indexer and physical TV checks remain outstanding.

Verification: **265 Rust tests + 216 Flutter tests passed**, 8 existing
opt-in screenshot tests skipped; Clippy with warnings denied, Flutter
analysis, and host native build passed. FRB and localization bindings were
regenerated. Existing branding/background changes were preserved.

## What's already there (don't rebuild this)

`rust/src/engine/newznab.rs` is already indexer-agnostic and well-tested:

- `parse_caps` — `?t=caps` discovery (search/tvsearch/movie support + params)
- `parse_search_response` — RSS parsing into `SearchItem`
- `ReleaseInfo::parse` + `badges()` — release-name → quality badges
  (2160p/HEVC/DV/HDR10+/TrueHD/Atmos/group), already indexer-independent
- `dedup_items` — cross-result dedup by normalized title + size-within-1%,
  already written with multiple indexers in mind, already unit tested

The original gap was in the plumbing above this layer:
`IndexerConfigDto` (`rust/src/api/search.rs`) and `IndexerSettings`
(`lib/settings/indexer_settings.dart`) both hard-assume exactly one
indexer. `newznab_search` takes one `IndexerConfigDto`, not a list.

## Research summary

**Newznab protocol capabilities beyond free-text search:**
`t=tvsearch` accepts `tvdbid`/`tvmazeid`/`season`/`ep`;
`t=movie` accepts `imdbid`. ID-based search is meaningfully more precise
than free-text `t=search&q=`. Spec detail worth
encoding in validation: `ep` without `season` is a protocol violation
(error code 201) — don't let the UI construct that request.
[Torznab/Newznab spec](https://torznab.github.io/spec-1.3-draft/external/newznab/api.html),
[Newznab API docs](https://newznab.readthedocs.io/en/latest/misc/api.html)

**Indexer presets:** NZBFinder, NZBgeek, nzb.su, NZBPlanet and DrunkenSlug
prefill a name and base URL; the user supplies their own API key. Custom
profiles support other compatible indexers, including local aggregators.
Presets make no claim about current signup availability, pricing, retention,
coverage or reliability. Check account terms directly with each provider.

**NZBHydra2** (the reference implementation for this exact problem) —
worth deliberately *not* copying in full. Its feature set: parallel
fan-out query, aggregation+dedup, media-ID translation per indexer,
per-indexer stats/observability, RSS feed output, Torznab proxy endpoint
for other apps to consume. zanzibarr is a direct-consumption streaming
client, not a server other tools point at — the RSS-output and
Torznab-proxy pieces are explicitly **not goals** here. The fan-out +
dedup + ID translation pieces are.
[NZBHydra2 overview](https://nzbhydra.com/blog/nzbhydra2-indexer-aggregator/)

## Phased plan

### Phase 1 — Multi-indexer configuration
- `IndexerSettings` → `IndexerProfile { id, nickname, baseUrl, apiKey, enabled }`,
  stored as `List<IndexerProfile>` in `IndexerSettingsStore` (still OS
  secure storage; key per profile `id`, plus an ordered id-list key).
- One-time migration: existing single `indexer.baseUrl`/`indexer.apiKey`
  becomes profile 0 on first read, old keys cleared after migration.
- Settings UI (`lib/settings/settings_screen.dart`): replace the single
  indexer form with a reorderable list (add / edit / remove / enable
  toggle per profile), each still going through the existing
  `newznab_check_caps` validation flow before saving.

### Phase 2 — Parallel fan-out search + merge
- Rust: new `newznab_search_many(configs: Vec<IndexerConfigDto>, query, limit, offset) -> SearchPageDto`.
  Fan out concurrently (tokio `join_all`), **per-indexer timeout and error
  isolation** — one dead/rate-limited indexer must not fail the whole
  search, just drop silently from results with a surfaced warning.
- Add `source_indexer: String` to `SearchItemDto` so the UI can badge
  results and dedup can prefer e.g. the larger/more-seeded copy when two
  indexers disagree on size.
- Run `dedup_items` (already exists) across the merged set before
  returning.
- `lib/search/search_screen.dart`: call the new many-indexer function
  instead of the single-indexer one; same result list shape otherwise.

### Phase 3 — Known-indexer presets
- Built-in picker (name + base URL prefilled) for the list above when
  adding a profile in Phase 1's UI — user pastes only the API key, no
  URL-typing/copy-paste errors. "Custom" option keeps today's free-form
  URL+key entry for anything not presets.

### Phase 4 — Structured/ID-based search (implemented locally)
- Add `t=tvsearch`/`t=movie` paths using `tvdbid`/`imdbid`/`season`/`ep`
  when the app has that metadata, falling back to free-text `t=search`
  otherwise. Enforce the `ep`-requires-`season` rule client-side.
- OMDb provides optional title search and IMDb identity/detail lookup;
  TVDB IDs remain manual. TV episode/season fields refer to the confirmed
  series. No inferred cross-service ID translation is performed.
- Available ratings are informational, never release-quality or completion
  scores. No posters, rating logos, scraping, or background catalog sync.
- Sources: [OMDb API](https://www.omdbapi.com/) and
  [Newznab API](https://newznab.readthedocs.io/en/latest/misc/api.html).
  A future direct Rotten Tomatoes integration must use its
  [licensing process](https://www.rottentomatoes.com/help_desk/licensing?mobile-app=true&theme=wiki);
  no direct RT API access is implemented here. TMDB discovery and external-ID
  mapping remain a separate follow-up with explicit attribution and key setup.

### Phase 5 — UX polish
- Per-result source badge (which indexer) in the search result list.
- Partial-failure messaging: "3 of 4 indexers responded" instead of
  silent gaps.
- Quick per-indexer enable/disable from the search screen itself, not
  just buried in settings.

### Next indexing improvements (proposed, in order)

1. **Release preferences:** filters for resolution, codec, HDR, audio and
   size using the existing parsed badges; distinguish unknown attributes
   from confirmed mismatches. Add language only when reliable metadata is
   available. Explain why a release ranks higher without mixing film ratings
   into technical playback suitability.
2. **Indexer health and budgets:** show per-source response latency and
   last failure, respect explicit rate-limit responses, add cooldowns and
   user-triggered retry. Keep credentials and raw remote errors out of stats.
3. **Duplicate alternatives:** retain alternative sources behind a release
   so a failed NZB fetch can offer another source. Preserve stable profile
   identity and ask before changing a selected release.
4. **Completion pre-check:** an explicit, bounded NNTP STAT sample before
   playback. Show sample coverage and uncertainty; a sample is not proof the
   entire release is complete. No automatic full-release fetching.
5. **Discovery:** optional TMDB browsing and verified external-ID mapping,
   then local saved searches. Keep automated monitoring/grabbing out of scope.

## Explicit non-goals

- Not building a standalone aggregator server (no Torznab-proxy endpoint,
  no RSS output) — zanzibarr stays a direct client, not infrastructure
  other `*arr` tools point at.
- Not adding Sonarr/Radarr-style automation (monitored shows, auto-grab
  on release) — out of scope for a manual-search streaming client.

## Security/privacy (carries over from existing conventions)

Same rule as today's single-indexer code: API keys live in OS secure
storage only, never logged, never in `Debug` output, error strings never
contain the key-bearing URL. Multi-indexer doesn't relax this — if
anything, more keys in flight means the existing discipline matters more.
