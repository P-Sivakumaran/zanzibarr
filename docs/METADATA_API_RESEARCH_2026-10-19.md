# Metadata API research - 2026-10-19

Research and proposed implementation sequence, not a new provider integration.
Public documentation and the MDBList OpenAPI schema were inspected. No new
credentials, paid calls, provider accounts or live inference were used.

## Recommended direction

Use the existing OMDb response more fully first, add TMDB for structured cast,
artwork and keywords, and use Wikidata only as an optional source of referenced
filming/narrative locations. For exact critic totals, evaluate MDBList with a
small authenticated contract test before promising coverage. Fabric Origin has
the clearest documented critic score/count fields, but requires commercial
access arrangements. None guarantees every title has every field.

Keep the user's chosen title identity durable across closing/reopening. The
current suggestion matches already persist, but their 100-title/1 MiB metadata
cache can evict old entries. A future identity store should retain deliberate
corrections separately from evictable artwork/ratings snapshots. Resume title
identity already persists through history and the title library. This paragraph
is a code-inspection finding and recommendation; no persistence change was made
in this research pass. Sixteen focused existing metadata/history/persistence
checks passed in the parent session; no new application gate is claimed here.

## What each source can add

| Source | Useful additions | Access and gaps | Recommendation |
| --- | --- | --- | --- |
| OMDb, existing | Actors, synopsis, ratings, runtime, genre, languages; retain further detail fields such as Director, Writer, Awards, Country and Released | API key; optional fields can be absent; no documented guaranteed critic-total contract | Use existing detail response before another request |
| TMDB | Structured cast/characters, crew, person images, posters/backdrops, keywords, localized metadata | API credential; attribution required; keywords are tags rather than a curated themes taxonomy; no RT/Metacritic critic totals | Preferred next metadata provider |
| MDBList | Ratings from multiple sources, stable-ID lookup, optional keywords/reviews, batching | Key or OAuth; critic-count meaning not specified in current public response schema | Promising low-cost evaluation, not yet a verified exact-count solution |
| Wikidata | Main subject, filming location, narrative location, linked place coordinates where present | CC0 structured data; community coverage varies | Optional enrichment with explicit source links |
| IMDb licensed data | Credits/roles, keywords, ratings/votes; licensed bulk title schema includes locations | AWS Data Exchange subscription; product entitlement and pricing must be checked | Consider if detailed location coverage justifies licensing |
| Fabric Origin | Documented RT critic summary/count and Metacritic critic review count, consensus/review material | Subscription key; RT developer approval and paid core solution; pricing by sales | Clearest documented licensed critic-count route |
| TVmaze | TV cast/characters, seasons, episodes and images; lookup by IMDb ID | Public API, CC BY-SA attribution/share-alike conditions; no film catalog or RT totals | Useful TV fallback, not needed alongside TMDB initially |

### OMDb: cheap gaps before extra APIs

The app currently retains an actors string and displays it inside About this
title. That is not a structured full cast with character names/photos. Existing
responses already parsed by the app can be extended to retain optional director,
writer, awards, country and release-date fields; these are optional, not a new
availability promise. Use `plot=full` when opening a full title page rather than
issuing separate calls for summary fields. OMDb documents IMDb-ID lookup,
movie/series/episode type and year constraints. Its dedicated high-resolution
Poster API is patron-only. The site declares CC BY-NC 4.0 content licensing.
Country must be labelled production/origin country, not filming location.
[OMDb documentation](https://www.omdbapi.com/),
[OMDb schema](https://www.omdbapi.com/swagger.json).

### TMDB: cast, artwork and theme-like keywords

Resolve a confirmed IMDb ID with `/3/find/{external_id}?external_source=imdb_id`,
validate the movie/TV result, then cache the TMDB mapping. Fetch movie details
with `append_to_response=credits,keywords,images`; this is two initial requests
including identity resolution, then one combined detail request after mapping.
TV has corresponding credits/images/keywords routes and aggregate credits when
roles across episodes matter. The movie credits endpoint supplies cast/crew;
images include posters, backdrops and logos. Display a short ordered cast row,
with expansion for more names, and source keywords under "Topics and keywords"
rather than asserting they are definitive critical themes.
[Finding data](https://developer.themoviedb.org/docs/finding-data),
[Append to response](https://developer.themoviedb.org/docs/append-to-response),
[Movie credits](https://developer.themoviedb.org/reference/movie-credits),
[Movie keywords](https://developer.themoviedb.org/reference/movie-keywords),
[Movie images](https://developer.themoviedb.org/reference/movie-images).

TMDB's developer API is free for non-commercial use with attribution; commercial
use requires contacting sales. Include the approved TMDB logo and required
non-endorsement notice in About/Credits. Configure an API key/read-access token
securely. Respect 429 responses: TMDB documents an approximate, changeable upper
limit around 40 requests/second, not a guaranteed allowance.
[TMDB FAQ](https://developer.themoviedb.org/docs/faq),
[Rate limiting](https://developer.themoviedb.org/docs/rate-limiting).

### MDBList: exact-count conclusion

The current official Swagger UI loads **`https://api.mdblist.com/schema/`**.
That OpenAPI document was retrieved successfully with JSON Accept negotiation.
`GET /{media_provider}/{media_type}/{media_id}/` supports IMDb/TMDB and other IDs;
its `ratings` response is only typed as `array<object>`. The public schema does
**not** define rating-row `source`, `value`, `score` or `votes` semantics. Likewise,
`POST /rating/{media_type}/{return_rating}` documents a batch lookup but leaves
rating row objects unstructured. A field called `votes` must not automatically
be displayed as "critic reviews". Its type, population and meaning need a
provider-confirmed contract and authenticated fixtures. Missing/null values must
remain missing, never zero or an estimated critic count.
[Official API UI](https://api.mdblist.com/docs/),
[Official OpenAPI schema](https://api.mdblist.com/schema/).

The batch route permits 10 IDs for regular users, 100 for supporters. The free
tier documents 1,000 requests/day; the published supporter table lists 10,000,
25,000, 100,000 and 250,000/day at 1, 2, 3 and 5 euro tiers. All tiers also have
1,000 reads/300 writes per five minutes, shared per account, and 429 Retry-After.
API-key and bearer authentication are documented. Do not confuse MDBList's own
blended `score` with an individual source rating. Public pages inspected do not
settle all redistribution/branding rights or a guaranteed RT/Metacritic
critic-count SLA; confirm those before distribution.
[Plans and API limits](https://docs.mdblist.com/docs/api),
[MDBList score definition](https://docs.mdblist.com/docs/score).

### Documented licensed critic-count alternative: Fabric Origin

Fabric's Metacritic movie response explicitly separates
`Product.Metascore.Score` + `Product.Metascore.ReviewCount` from
`Product.Userscore.Score` + `Product.Userscore.RatingCount`. Its TV endpoint also
accepts SeasonNumber: keep season scores separate from whole-show scores. RT
responses distinguish `CriticSummary.Score.Value/Count` from
`FanSummary.Score.Value/Count`; use the former for critic approval/count context.
These are documented schemas, not evidence of coverage for every title.
[Metacritic endpoint/schema](https://developer.origin.fabricdata.com/origin/apis-all/metacritic-api-docs/metacritic),
[RT endpoint/schema](https://developer.origin.fabricdata.com/origin/apis-all/rotten-tomatoes-api-docs/rottentomatoes).

These endpoints use Origin entertainment IDs, so IMDb-to-Origin matching must
be established and persisted before enrichment. Origin requires a subscription
key, intended for server-to-server access. Its RT documentation requires a paid
core solution, developer approval, terms acceptance and branding compliance.
No fixed public price was verified. Trial access is limited and does not by
itself establish RT entitlement. RT's own help desk directs API/data-feed users
to a business proposal process. No free self-service direct RT/Metacritic API
was verified; this is not a claim that licensed access is unavailable.
[Origin getting started/authentication](https://developer.origin.fabricdata.com/origin),
[RT access requirements](https://developer.origin.fabricdata.com/origin/apis-all/rotten-tomatoes-api-docs),
[Metacritic access requirements](https://developer.origin.fabricdata.com/origin/apis-all/metacritic-api-docs),
[RT official integration guidance](https://www.rottentomatoes.com/help_desk).

### Locations and subjects: preserve distinctions

Wikidata explicitly distinguishes **P915 filming location**, **P840 narrative
location**, and **P921 main subject**. Match titles by IMDb ID (P345) before
reading claims. A film may have none of these populated. Include the source
entity/reference, suppress empty sections and offer correction links. Coordinates
for a named place can enrich a location map only when supplied by that place's
entity; do not infer filming coordinates from production country. Wikidata
structured data is CC0; its access guidance recommends descriptive User-Agent,
bounded requests, caching and respecting Retry-After.
[Filming location](https://www.wikidata.org/wiki/Property:P915),
[Narrative location](https://www.wikidata.org/wiki/Property:P840),
[Main subject](https://www.wikidata.org/wiki/Property:P921),
[Data access and licensing](https://www.wikidata.org/wiki/Wikidata:Data_access).

IMDb's licensed Title Essential bulk schema explicitly includes `locations`
with `place`, `scenes` and interest votes, plus categorized keywords and roles.
Its API examples verify credits, keywords and IMDb rating/vote queries. This
research did not verify a corresponding public filming-location GraphQL field;
do not assume the bulk field implies an API entitlement. IMDb's free
non-commercial datasets are not interchangeable with the paid licensed schema.
[Licensed bulk schema](https://data.imdb.com/documentation/bulk-data-documentation/creating-tables-DDL/),
[IMDb API examples](https://data.imdb.com/documentation/api-documentation/sample-queries/title-name/),
[IMDb API access](https://data.imdb.com/documentation/api-documentation/).

TVmaze is a possible TV-only alternative with exact IMDb-ID lookup, cast,
seasons and images. Its public API documents CC BY-SA, caching and rate limits.
It cannot supply film metadata or missing RT/Metacritic critic totals.
[TVmaze API](https://www.tvmaze.com/api).

## Efficient gap-filling plan (proposed, not implemented)

1. Preserve explicit chosen title IDs separately from bounded enrichment caches.
   Cache provider mappings by canonical IMDb ID plus media kind and, where
   needed, season. A rematch invalidates old mappings and late jobs.
2. Retain optional fields already delivered by OMDb. Request full plots on title
   pages. Surface cast/creator information without requiring another match.
3. Add one optional TMDB connection for cast, artwork and keywords. Coalesce
   duplicate work and fetch only visible titles/expanded playlists; avoid
   per-actor biography calls until a person is opened.
4. Track gaps per provider and field. Cache absent fields with an expiry so every
   reopen does not retry them. Suggested starting policy: 24 hours for absent
   critic totals, 7 days for cast/keywords/locations, subject to provider terms.
   Store transient errors separately with exponential backoff/Retry-After.
5. Store a rating as one atomic observation: source, provider, raw score, scale,
   count, count kind, entity scope, source URL, fetched-at timestamp. Replace
   score/count together from the same response. Never attach today's count from
   one provider to yesterday's OMDb score. Keep critic reviews, audience ratings
   and user votes separate; preserve grouped/lower-bound totals as such.
6. Trial MDBList against a small representative set only after configured
   access is available. Verify source identities, exact count semantics, missing
   data, source URLs and permitted display. Use batching only when its response
   contract supplies the needed count; batching a score-only endpoint cannot
   fill critic-count gaps. If that contract cannot be established, evaluate
   Fabric licensing rather than scraping undocumented private endpoints.
7. Add Wikidata locations lazily on title detail pages, retain claim provenance
   and keep filming locations, narrative setting and country distinct. Curated
   themes are editorial interpretation; label AI-inferred themes separately if
   that feature is later commissioned.

No provider has been enabled by this research. New access credentials and,
for licensed services, subscription/redistribution approval are the remaining
external prerequisites. Exact RT/Metacritic count coverage remains unverified
until an authenticated provider response is checked against its source title.

Verification evidence: `dist/audit/metadata-research-persistence.log` records
16 passing focused tests, including restored manual matches, cached correction
refresh by trusted identity, and history identity/progress preservation. These
are automated storage/controller checks, not a live application restart test.
Documentation whitespace check passed. The application remains 1.21.0+22.


## Fabric adapter contract follow-up

The documented automatic lookup route is
`GET https://api.origin.fabricdata.com/Entertainment/Search/`, with
`ExternalId`, `ExternalIdType`, `ProgramTypes`, `Includes`, `Take` and `Skip`.
The response shape is `Total` plus `Hits[].Source`, containing `Id`
(e.g. `Movie/123`), `ProgramType`, `Title`, `Year` and
`ExternalIds: [{Name, Id}]`. The public reference does not verify the exact
IMDb spelling for `ExternalIdType` or `ExternalIds.Name`; these must be
confirmed from provider fixtures or support, not guessed. Require one exact
external-ID/kind match and retain the full Origin ID before calling ratings.
Do not silently fall back to a title-only match. The separate Match endpoint's
`Success=true` can still mean a low-confidence title/year-only score.
[Search contract](https://developer.origin.fabricdata.com/origin/apis-all/entertainment-api-docs/entertainment),
[Matching caveat](https://developer.origin.fabricdata.com/origin/apis-all/entertainment-api-docs/metadata-match-guide).

Use the documented `Ocp-Apim-Subscription-Key` request header, never a shared
subscription key embedded in a distributed app. Fabric describes this access as
server-to-server. Exact RT routes are `GET /RottenTomatoes/Movie?MovieId=123`
and `GET /RottenTomatoes/Show?ShowId=123` on `api.origin.fabricdata.com`.
`CriticSummary.Score.Value` and `Count` are strings; the published model does
not define their units, numeric formatting or grouping. Verify an authenticated
example/provider contract before converting a bare score string to a percentage
or treating a grouped count as exact. The documented structure is sufficient to
prepare an adapter boundary, not to claim a live verified integration.
[Authentication](https://developer.origin.fabricdata.com/origin),
[RT routes](https://developer.origin.fabricdata.com/origin/apis-all/rotten-tomatoes-api-docs/rottentomatoes),
[RT models](https://developer.origin.fabricdata.com/origin/apis-all/rotten-tomatoes-api-docs/models).
