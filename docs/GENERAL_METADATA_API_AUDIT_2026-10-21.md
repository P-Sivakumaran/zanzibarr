# General film/TV metadata API audit - 2026-10-21

Scope: existing OMDb, TMDB, Wikidata and official YouTube trailer embedding only.
Official public documentation was retrieved on this date. No credentials,
authenticated API requests or video/media requests were used. Documentation
availability establishes a published contract, not successful account setup,
current service uptime, data coverage or end-to-end playback.

Local source inspected at HEAD `3080da6d039c1b7ab2ff95fb15a94743ad245998`,
including the working tree. This audit changes documentation only and preserves
the concurrent application edits.

## Published availability and access

| Source | Official evidence | Implication for the implementation |
|---|---|---|
| OMDb | The [API documentation](https://www.omdbapi.com/) still publishes title/IMDb-ID lookup, search, series and episode support. HTTPS is supported. The [key form](https://www.omdbapi.com/apikey.aspx) offers a free key with 1,000 daily requests and warns of delivery delays, particularly Yahoo/Microsoft mail. | Retain the optional provider. The app uses HTTPS with the user's `apikey` in `metadata_service.dart`. A delayed key email or exhausted quota does not establish API retirement. Actual key delivery and authenticated lookup remain unverified. |
| TMDB | [Application authentication](https://developer.themoviedb.org/docs/authentication-application) documents both a v3 `api_key` and an API Read Access Token sent as `Authorization: Bearer ...`; the Bearer token works for v3/v4. Keys are requested through account settings. [Movie videos](https://developer.themoviedb.org/reference/movie-videos) and [TV videos](https://developer.themoviedb.org/reference/tv-series-videos) remain documented. | The app's `metadata_enrichment.dart` expects the Read Access Token, maps IMDb IDs through `/3/find`, then appends credits, keywords, external IDs and videos to title details. Do not paste a short v3 API key into a field expecting the Bearer token. Authenticated lookup/coverage remain unverified. |
| Wikidata | [Data access](https://www.wikidata.org/wiki/Wikidata:Data_access#Wikidata_Query_Service) publishes public GET/POST SPARQL access at `https://query.wikidata.org/sparql`; no user API key is specified for this read interface. | The app uses that endpoint for IMDb-ID matching and distinct filming/narrative place properties. Keep this optional. Public access does not guarantee that an individual title has the requested facts. No SPARQL result request was made in this audit. |
| YouTube embeds | [Embed documentation](https://developers.google.com/youtube/player_parameters) still documents player URLs and iframe embedding. This documented single-video embed method takes a video ID and does not specify a YouTube Data API key. | Existing TMDB-selected official trailer/teaser IDs and YouTube iframe playback remain a documented approach. No new YouTube search/Data API integration or key is implied. Embedding a particular video remains subject to its restrictions. |

OMDb's [main page](https://www.omdbapi.com/) labels its separate Poster API as
patron-only, identifies its content license as CC BY-NC 4.0, and disclaims IMDb
affiliation. This is not a direct IMDb or Rotten Tomatoes API. Metadata access
does not establish access to the separate high-resolution Poster API.

TMDB's [FAQ](https://developer.themoviedb.org/docs/faq) describes free
noncommercial access with attribution and a commercial licensing route. It
requires its approved logo and a notice that TMDB does not endorse/certify the
product, in an About/Credits section; this audit has not certified the app's
attribution UI. Its [rate-limit guidance](https://developer.themoviedb.org/docs/rate-limiting)
says the old 40-per-10-second limit was disabled, but variable upper limits and
HTTP 429 still apply. No SLA is promised in the FAQ.

## Wikidata migration: follow-up required, not removed today

The official [backend migration hub](https://www.wikidata.org/wiki/Wikidata:SPARQL_query_service/WDQS_backend_update)
describes migration from Blazegraph to QLever: its current timeline says pilot
testing, community access planned by November 1, and original endpoints remaining
available with possible degradation beginning February 2027. These are published
plans, not proof that the old endpoint has already stopped working. The hub says
clients will need new endpoints and may need query rewrites.

Plan an isolated migration check for the app's `SERVICE wikibase:label` query
against the documented v2 contract once available; changing only the hostname
would not prove compatibility. Do not remove Wikidata or claim its API is dead
on the evidence above. The [current user manual](https://www.mediawiki.org/wiki/Wikidata_Query_Service/User_Manual#Query_limits)
also documents time/concurrency limits, HTTP 429 with `Retry-After`, and possible
blocking for a noncompliant User-Agent. Those are access/runtime conditions,
distinct from endpoint retirement. The [data access guide](https://www.wikidata.org/wiki/Wikidata:Data_access)
identifies structured data as CC0 and recommends a useful identifying User-Agent.

## YouTube embed limitations

The [minimum functionality requirements](https://developers.google.com/youtube/terms/required-minimum-functionality#api-client-identity-and-credentials)
require HTTP Referer identification for embedded players, including WebViews,
and describe platform-specific ways to provide it. They recommend
`strict-origin-when-cross-origin`; an explicitly supplied identity should use
the installed/store app ID in an HTTPS URL. The local `trailer_navigation.dart`
uses `https://com.zanzibarr.zanzibarr/`, Windows `Page.navigate` with a navigation
referrer, and a Referer header on other platforms. This code inspection does not
verify the effective identity on every packaged platform.

The [iframe reference](https://developers.google.com/youtube/iframe_api_reference#onError)
documents error 153 for missing Referer/equivalent client identity, 100 for a
removed/private video, and 101/150 for an owner disabling embeds. It also explains
browser autoplay blocking. Thus an embed error does not alone establish that
the iframe API was withdrawn. Preserve a user-visible external watch fallback.

The [player parameters](https://developers.google.com/youtube/player_parameters)
require a minimum 200-by-200 viewport. Their actual deprecations include
`modestbranding` and the historical `listType=search` behavior; these do not
deprecate single-video iframe embedding. `rel=0` does not disable related videos
entirely. Existing `title_trailer.dart` uses `youtube-nocookie.com`, explicit
`autoplay=0`, valid 11-character IDs and TMDB's official Trailer/Teaser filter;
that provider label does not guarantee future YouTube availability or embed
permission.

## Conclusion and verification boundary

No reviewed official source establishes retirement of OMDb, TMDB or single-video
YouTube embedding. Wikidata has a concrete announced migration to track.
Retain the existing optional general providers while distinguishing configuration,
credentials, quotas, missing data and video restrictions in diagnosis.

Verification performed: official documentation retrieval, focused local source
inspection and documentation whitespace checks. Application tests, authenticated
provider calls and native/device playback were not run for this documentation-only
audit. Earlier playback evidence in repository handoffs is historical evidence,
not a new run here.
