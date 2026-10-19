# Durable matches and richer titles - 1.22

Implemented over the existing uncommitted 1.17-1.21 work. User authorization:
use best judgment to implement the researched metadata improvements. Closing a
view/app is treated as preserving matches; Rematch remains a correction action.

## Durable identity and optional snapshots

Suggestion storage migrates on the next successful save from the legacy v1
cache to a single v2 envelope. It atomically stores lightweight title identities
separately from the most recent 100 artwork/metadata snapshots. Snapshot eviction
retains the chosen IMDb ID, canonical name, type and year. Reopening can refill
the snapshot by trusted ID without a title search. Corrections still invalidate
older automatic work. Legacy storage is preserved. Invalid storage blocks edits;
write failures retain the current in-memory match.

The identity collection has an explicit 5,000-entry/2 MiB combined storage bound;
it refuses new saves at capacity rather than silently forgetting prior matches.
This is not unlimited storage. Resume identities continue to use saved history
and the title library. No release identity or playback progress format changed.

## Title page

Cast is visible rather than buried in About. The first eight cast entries show
in wrapping cards, with Show more when needed. OMDb actor names work immediately;
configured TMDB can add role names and portraits. Retained OMDb fields include
director, writer, awards, release date and country. Details request full plots.

TMDB keywords appear as Topics & keywords, hidden behind Show topics because
provider tags can reveal plot details. They are not presented as curated themes.
Wikidata filming locations and story settings have distinct labels and a source
link; country of origin is a separate fact. Absent optional sections stay hidden.
No locations, themes, actor roles or review totals are generated or guessed.

Base title information and controls are available while optional lookups finish.
Provider errors do not block ordinary metadata or playback. Existing artwork
opt-in, public-CDN restrictions, image bounds and reduced-motion behavior remain.

## Sources and setup

Open **Settings > Artwork & ratings > Cast, topics & review context**.

- TMDB: paste its **API Read Access Token**, not its short API key. Credentials
  stay in secure storage. First lookup resolves the confirmed IMDb ID; details
  then combine credits, keywords and external IDs in one request. Both returned
  type and exact external ID are checked. Mapping snapshots last up to 90 days;
  cast/topic snapshots up to seven days. No per-actor biography requests occur.
- Wikidata: opt in to sending the identified IMDb title ID. A bounded SPARQL
  query reads P915 filming places separately from P840 narrative settings. It
  rejects ambiguous identity results. Location snapshots last up to seven days.
- Review context: choose an existing metadata-enabled **MCP & plugins** connection.
  The app calls metadata_details for the confirmed IMDb ID, verifies ID and type,
  and consumes a source score plus exact Count together. It retains the old
  observation when a new count or valid scale is missing. Cache: 24 hours.

Additional-source settings have explicit Save, a retry path for failed loading,
and an unsaved-draft guard. Removing a credential/selection stops requests to
that source. Public snapshots are kept separately from secure credentials.

The existing provider payload contract is extended compatibly:

```json
{"imdbID":"tt1234567","Title":"Example","Year":"2026","Type":"movie",
 "Ratings":[{"Source":"Rotten Tomatoes","Value":"95%","Count":240}]}
```

Count is a positive exact integer, or an exact comma-grouped numeric string.
For IMDb it means user votes; for RT and Metacritic it means critic reviews.
A provider must normalize its upstream contract accordingly; arbitrary fields
called votes are not automatically mapped to critic counts. The app validates
scales and numeric counts, but cannot establish licensing or the upstream
meaning of undocumented fields. Source-specific attribution is retained when
observations are replaced. Counts are never joined to an older different score.

Fabric access still requires paid approval and verified identifier/score
contracts. No licensed service or MDBList integration was enabled, no keys were
read from another app, and no live provider coverage is claimed. The implemented
MCP consumer can accept licensed data from a configured compatible bridge; a
Fabric bridge itself is not bundled. See the
[primary-source API research](METADATA_API_RESEARCH_2026-10-19.md).

## Efficiency and boundaries

Enrichment only runs for opened title pages, not every poster or actor. Identical
in-flight source requests coalesce; at most two source requests are admitted per
controller. No unbounded queue is created. Cache is limited to 100 entries and
4 MiB; responses to 2 MiB and 12 seconds, with redirects disabled. Successful
empty responses are cached for the source TTL. Transient failures have a five-
minute retry window; 429/503 Retry-After is retained within the bounded policy.
Cached absence/error windows survive reopening. Connections close with the
owning title view; late results cannot update a disposed widget.

TMDB attribution includes its logo and non-endorsement notice in the title About
section and metadata source settings. Asset provenance and licensing are in
[branding credits](../assets/branding/README.md).

## Verification

Ten new regressions cover settings draft/save behavior, desktop/narrow title
rendering, no requests before opt-in, trusted-ID matching, persisted data and
mapping reuse, negative caching, Retry-After across reopening, location semantics,
atomic score/count replacement, snapshot eviction and large-text layout.
Fixtures are fictional examples, not live provider data.

Screenshots:

- [Desktop title](screenshots/enrichment-title-1440-flutter.png)
- [Narrow title](screenshots/enrichment-title-360-flutter.png)
- [Source settings](screenshots/enrichment-settings-flutter.png)

Fresh ordered gate passed: 266 serial Rust tests, Clippy, Flutter analysis,
native host build and 383 Flutter tests with 9 opt-in screenshot skips, followed
by whitespace checks. Ten new regression cases passed. Final preview rendering
also passed all ten cases. Desktop/narrow screenshots were visually inspected.
Ignored logs use dist/audit/enrichment-*.


## Windows preview artifact

The normal Flutter Windows build reached linking but could not replace the open
1.21 executable (LNK1104). That app was left running. The same generated Release
project was built and installed by CMake into a separate preview directory;
temporary output/install overrides were then removed from the generated cache.
The standalone native Release preview build passed. Source code and global
Flutter SDK configuration were not changed for this workaround.

- App: `dist/preview-1.22/zanzibarr.exe`
- Verified Windows resource version: **1.22.0+23**
- Executable SHA256: `79E7D4BF1D12DF097E38EDDB22A7D835685F67EA9EEDAC4D8A8B5A4D7392977B`
- Flutter AOT library, assets (including TMDB attribution), native engine/plugin
  DLLs and Rust DLL present. Keep the full preview folder together.
- Build logs: `enrichment-windows-build.log` records the initial lock failure;
  `enrichment-preview-configure/build/restore.log` records the successful
  separate-folder build and restoration. All are under ignored dist/audit/.

Unsigned, uncommitted, not installed or published; no installer created. Native
1.22 rendered UI, live metadata credentials/coverage and device playback were
not verified. The ordinary build/windows runner still contains the open 1.21
executable; use the explicit 1.22 preview path above.


## Installer packaging completed

User subsequently requested an installer. Setup and portable ZIP were generated
from the verified 1.22 bundle, with app-local x64 CRT, native DLLs, integration
bridge, guides and TMDB/license attribution. Inno Setup 6.7.3 was bootstrapped
with its required Authenticode publisher check. Compiler completed successfully.

Artifacts under `dist/windows/v1.22/`:

| File | SHA256 |
| --- | --- |
| zanzibarr-windows-x64-setup.exe | bc3d55985bbddfa7478d05edb636adbc636ba67e6653a99c68b73929fb119af2 |
| zanzibarr-windows-x64.zip | 16d3d63caa1684a53c005a27cddd9b3a3c16ea145295fc1f1a0fcde39d2b6a09 |

SHA256SUMS verified; ZIP CRC and 58 entries checked. Required components,
including app-local CRT and attribution notices, were verified. The packaged
executable matches the preview hash above and reports 1.22.0+23; setup reports
1.22.0. Source commit is 0f2cd4d2d204324d56f235b02e555314f6a4c35b.

Lifecycle smoke stopped at its existing-installation guard: "An installed copy
exists; use a fresh user/VM for the smoke test". No existing installation was
changed. Packages are unsigned, not installed or publicly published. Fresh-user
installation/upgrade/playback remains unverified. Logs use the ignored
`dist/audit/installer-1.22-*` prefix. Earlier no-installer statements describe the
preview-build stage and are superseded by this packaging result.
