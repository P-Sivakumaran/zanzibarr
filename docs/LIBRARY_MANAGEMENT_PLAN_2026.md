# Library management — development plan (2026)

## Why

zanzibarr today has exactly one persistence concept: `PlaybackHistoryEntry`
(`lib/player/playback_history.dart`) — a flat list of `{nzbPath, title,
position, duration, updatedAt}`. No favorites, no watchlist, no linkage
between episodes of the same show, no "track this and tell me when a new
episode lands." Every other Usenet-adjacent tool in this space (NzbDAV,
AIOStreams) has converged on some form of "keep wanted content mapped to
verified releases" and scheduled rechecks — that's the gap worth closing
here, scaled to a client that doesn't run a server or own a download queue.

This doc is a living plan: update it as phases land or scope changes.

## What's already there (reuse, don't rebuild)

- `lib/metadata/metadata_service.dart` + `metadata_screen.dart` — OMDb
  lookup, title/year disambiguation, IMDb ID resolution. This is the
  identity layer everything else hangs off.
- `lib/search/structured_search_dialog.dart` + `release_search_selection.dart`
  — `t=tvsearch`/`t=movie` with `tvdbid`/`imdbid`/season/episode, already
  wired through multi-indexer fan-out (`newznab_search_many`).
- `lib/player/playback_history.dart` — position/duration tracking, already
  used to render the Home screen's Continue Watching section.

The gap is entirely **above** these: history entries carry a free-text
title, not a stable media identity, so there's no way to group "S01E01" and
"S01E02" of the same show, or to ask "is there a new episode of this out
yet."

## Research summary

**Convergent pattern in adjacent tools:** NzbDAV's "watchtower" keeps
wanted movies/episodes mapped to verified releases and re-resolves when a
release disappears; AIOStreams runs scheduled rechecks to replace taken-down
releases. The common thread is *tracking intent separately from a single
download*, not a bigger download manager.
[NzbDAV](https://github.com/nzbdav-dev/nzbdav),
[AIOStreams usenet guide](https://docs.aiostreams.viren070.me/guides/usenet/)

**Continue Watching / Up Next UX:** Plex merged "Continue Watching" and "On
Deck" (next episode of a show you're mid-way through) into one consolidated,
most-recent-first row years ago; Jellyfin still keeps them separate and it's
a recurring complaint in their own issue tracker. The agreed-on pattern:
show resumable items first, then next-episode-of-a-show entries, skipping
any show that already has a resume entry in the row.
[Jellyfin grouping discussion](https://news.ycombinator.com/item?id=43063710),
[Jellyfin "merge Continue Watching and Up Next"](https://community.firecore.com/t/jellyfin-merge-continue-watching-and-up-next/39898)

## Phased plan

### Phase 1 — Persistent media identity (foundation)

Everything else depends on this. `PlaybackHistoryEntry` gains optional
`imdbId`, `season`, `episode` fields, populated from `ReleaseSearchSelection`
when a structured-search result was used to start playback (free-text
searches leave these null — no identity to attach, and that's fine, not
every release needs to be trackable). Entries with the same `imdbId` become
groupable without any new network calls.

### Phase 2 — Continue Watching / Up Next consolidation

Once Phase 1 exists, merge the Home screen's resume row with a "next
episode" row per the researched Plex pattern: resumable items first
(most-recent-first, as today), then — for shows with an `imdbId` and a
completed episode but no in-progress one — a lightweight "Up Next" entry.
No network call to compute this; it's inferred from existing history
entries (if S01E01 is watched and S01E02 isn't in history, offer "find
S01E02" which opens structured search prefilled, it doesn't auto-fetch).

### Phase 3 — Watchlist / show tracking

"Track this show" action on the metadata screen, stored as its own list
(`imdbId`, title, last-known watched season/episode). A manual "check for
new episodes" action re-runs structured multi-indexer search for the next
unwatched episode — **user-triggered, not background polling.** Several
indexers cap daily API hits hard (see `docs/INDEXER_SEARCH_PLAN_2026.md`'s
rate-limit research); silent background polling across every tracked show
would burn that budget fast and unpredictably. A manual "check now" (and
maybe a badge reminding the user it's been a while) keeps usage predictable
and consistent with how search already works in this app.

### Phase 4 — Resume durability (robustness, wears a library hat)

`PlaybackHistoryEntry.nzbPath` points at a **temp-cached NZB file**
(`newznab_download_nzb`'s output dir). If that cache is cleared or the app
restarts after the OS reclaims temp space, resume silently points at a
file that no longer exists. Fix: store the originating `source_id` +
`nzb_url` alongside the entry so resume can **re-download** the NZB on
demand instead of trusting a temp path to still be there. This is a real
correctness gap already present today, worth fixing regardless of which
other phases land.

### Phase 5 — Manual curation

Explicit favorite/bookmark (independent of watch progress — "I want this
again" vs "I'm partway through this"), remove-from-history, mark
watched/unwatched without needing to actually finish the file.

### Phase 6 (stretch, needs its own scoping pass) — Browse without searching

Newznab's `t=search` accepts category-only filters with no query string —
usable as a "recently added" / "trending" row for passive browsing instead
of always starting from a typed query. Flagged as a later, separately-scoped
phase specifically because of the rate-limit concern from Phase 3: an
always-visible "browse" row that silently refreshes would be the single
fastest way to blow through a free-tier indexer's daily hit cap. Needs an
explicit opt-in and manual/infrequent refresh model before it's worth
building, not a drop-in with Phase 1-5.

## Explicit non-goals

- **Not a download manager.** No Sonarr/Radarr-style automated grab queue,
  no SABnzbd-compatible API, no persistent on-disk media library. zanzibarr
  stays a direct-stream client — this plan is about *tracking intent and
  identity*, never about owning files.
- **Not background network activity.** Every network-touching action in
  this plan (recheck, browse-refresh) is user-triggered. No silent polling
  — matches the existing search model and avoids surprising indexer-quota
  consumption.

## Verification

Each phase should land with its own Flutter widget tests (this app's
existing convention — see `test/ux_flows_test.dart` for the pattern) plus,
for Phase 4 specifically, a regression test proving resume survives a
cleared temp-cache directory.
