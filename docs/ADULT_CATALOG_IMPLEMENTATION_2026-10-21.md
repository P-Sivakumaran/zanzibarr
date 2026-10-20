# Adult catalog implementation - 2026-10-21

## Using the feature

Open **Home > Adult library** or **Settings > Adult library & sources**.
Enable the catalog, expand Source connections and enter your own ThePornDB token
and/or StashDB API key. Save source settings before searching. Keys are saved
in OS secure storage; do not paste them into chat or diagnostic reports.

- ThePornDB supports scene or movie searches. StashDB supports scene searches.
- Open a result to inspect its title, studio, release date and performer names.
  Save match keeps its provider identity and metadata across app restarts.
- Use the saved title's menu > Rematch to choose a corrected catalog record.
  The previous record remains until the replacement is successfully saved.
- Find releases opens an explicit category-6000 Newznab text search. Editing the
  query keeps that category scope. Existing indexer profiles, source recovery,
  stable profile routing and download/playback controls are reused.
- Catalog artwork is separately opt-in and only displayed in this library.
  Supported ThePornDB hosts are cdn.theporndb.net and thumb.theporndb.net;
  unsupported hosts, signed-query URLs and StashDB image origins are not loaded.
- IAFD reference opens externally only when a valid HTTPS IAFD URL was supplied
  by the metadata source. It does not fetch or scrape IAFD records.

Source access references: [ThePornDB API](https://api.theporndb.net/docs) and
[stash-box authentication](https://github.com/stashapp/stash-box#api).
New screen text currently uses an English fallback.

## Boundaries and data handling

This is the first adult catalog integration, not a claim of full IAFD coverage.
There is no verified official IAFD API contract, direct IAFD lookup, local Stash
adapter, fingerprint submission, provider browsing feed, adult AI generation,
remote trailer loading or automatic adult release/history matching. Catalog
search returns at most 20 results per explicit request; refine the query for
other matches. Performer names are supplied catalog facts, not separate profile
pages. Ratings and review counts are not invented or copied from mainstream
providers. Durations are omitted because the TPDB schema did not establish units.

Saved adult metadata lives separately from mainstream title matches and the AI
suggestion library. Playback, downloads and viewing history remain shared with
the rest of the app; this is not a private viewing mode. Removing a saved match
does not delete media, provider credentials or playback history. Disabling the
catalog hides its contents and stops catalog use, retaining saved records and
source settings for later use.

Adult identities are provider + kind + canonical ID, never fabricated IMDb IDs.
The existing string-valued Rust search DTO accepts an adult kind with no IMDb,
TVDB or episode fields; no bridge shape/signature change was required. Each
adult request sends t=search, q and cat=6000. Indexers can differ in category
coverage, availability and source restrictions; live coverage remains unverified.

Catalog requests use fixed HTTPS origins, bearer/API-key headers, no redirects,
15-second abort deadlines and a 2 MiB body limit. Only one request per screen's
client runs at a time. HTTP 429 establishes a bounded retry delay; there is no
unattended refresh. Provider error bodies and exception details are not shown.
The library serializes mutations, caps saved records at 300, refuses corrupt
stored data and preserves previous data on failed writes. Settings protect
unsaved drafts and do not present editable defaults after load failure.

Artwork reuses the bounded loader through a per-instance URI validator. The
mainstream shared loader keeps its existing allowlist and preferences. Adult
artwork uses its own opt-in and cache, cleared when the screen closes. No live
adult catalog records or media were fetched during implementation or testing.

## Verification

Candidate version: **1.26.0+27**. Fresh ordered application gate passed:
271 Rust tests (serial), Clippy with warnings denied, Flutter analysis, host
native build, 406 Flutter tests with 9 existing opt-in screenshot skips, and
whitespace checks. All 23 focused adult/search checks passed separately.
Release inputs passed `python tools/validate_release.py v1.26`.

An initial formatting command touched unrelated Rust files; each was proved to
match rustfmt(HEAD) and restored. They have no remaining content changes.

Evidence is recorded under ignored dist/audit/adult-*.log. Focused tests cover
synthetic catalog records, REST and GraphQL wire shapes, identity separation,
reopen/rematch persistence, corrupt storage, failed writes, sanitized failures,
rate limiting, response bounds, safe URLs, disabled defaults and category scope
retained after query edits. Provider accounts, live indexer coverage and native
adult media playback require separate user-configured checks.

See [provider research](ADULT_METADATA_RESEARCH_2026-10-21.md) for contracts,
primary references, unknowns and follow-up adapters.
