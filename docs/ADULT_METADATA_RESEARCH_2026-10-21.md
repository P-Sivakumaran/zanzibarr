# Adult metadata provider research - 2026-10-21

Scope: technical metadata integration for films/scenes, performers, studios,
provider IDs and correction persistence. Only documentation, schemas and source
code were inspected. No live catalog records, explicit media, account creation,
credential use, fingerprint submissions or site-restriction bypasses occurred.
Examples below use synthetic text and are not catalog recommendations.

## Practical decision

1. **ThePornDB REST** is the most direct new provider: public OpenAPI, separate
   scene/movie routes and performer/site resources. Prepare a read-only adapter
   behind configured access, preserving source IDs rather than forcing IMDb IDs.
2. **StashDB stash-box GraphQL** is a useful second source for scenes, performers,
   studios and fingerprint matching. Its schema differs from local Stash.
3. **Local Stash** can later connect an existing user-managed library and its
   confirmed source mappings; it is not a hosted replacement metadata catalog.
4. **IAFD** remains an external reference/access discussion, not a verified API
   integration. The current official access/terms contract could not be read.

These are implementation recommendations. This document does not claim a live
provider integration, catalog coverage or permission to redistribute records.

## IAFD: what is and is not verified

The official [home](https://www.iafd.com/),
[FAQ](https://www.iafd.com/faq.asp) and
[copyright/terms endpoint](https://www.iafd.com/copyright.asp) could not be read
by the research tools. A normal HTTP request to the copyright endpoint received
a JavaScript/cookie anti-bot challenge. Work stopped at that boundary.

**No official IAFD API, authentication scheme, quota, stable-ID contract or
current permitted reuse terms were verified.** This is not evidence that no API
or licensed access exists. Do not infer API permission from another tool's HTML
scraper or from an old URL format. Do not rely on unrelated "IAFD" organizations
found in searches. Obtain an official access/reuse contract before implementing
IAFD fetching; retain a supplied IAFD reference URL only as a source link.

## ThePornDB: verified REST/OpenAPI contract

Primary references: [official Swagger UI](https://api.theporndb.net/docs),
[official OpenAPI document](https://api.theporndb.net/specs?openapi.json).
The public document retrieved on this date reports **v3.24.757**. Its schema has
no `servers` entry; the UI is on `api.theporndb.net`, and the provider's own
[plugin constants](https://github.com/ThePornDatabase/Jellyfin.Plugin.ThePornDB/blob/3ab15ffb4a0f85d76bc6d2c3ea9753c323f1ba8a/Jellyfin.Plugin.ThePornDB/Consts.cs)
confirm **`https://api.theporndb.net`** as the API base.

Authentication is `Authorization: Bearer <token>`; OpenAPI names this security
scheme `sanctum`, an API-key header named `Authorization`. No shared key should
be bundled in the app. Read-only access is sufficient for a metadata reader.

| Purpose | GET route | Successful response |
| --- | --- | --- |
| Search scenes | `/scenes` | `{data: [SceneResource], meta: Meta}` |
| Search movies | `/movies` | Same shape |
| Scene details | `/scenes/{identifier}` | `{data: SceneResource}` |
| Movie details | `/movies/{identifier}` | Same shape |
| Performer search/details | `/performers?q=...`, `/performers/{identifier}` | Array plus meta / single data resource |
| Site/studio search/details | `/sites?q=...`, `/sites/{identifier}` | Array plus meta / single data resource |

`Identifier` explicitly permits slug, id or UUID. Persist the returned canonical
`id` and the resource kind; do not use a mutable slug as the sole identity.
Search supports `q`, `title`, filename-oriented `parse`, `year`, `date`, `url`,
`external_id`, site/studio constraints and performer constraints. `external_id`
is a provider/source filter, **not a documented IMDb-ID equivalent**.
`per_page` has minimum 1, maximum 100; `page` selects a page. `Meta` contains
`total`, `per_page`, `current_page`, `last` (not `last_page`). These route/field
claims derive from the official OpenAPI document linked above.

### Minimal display and identity fields

`SceneResource` covers both kinds: `id`, `_id`, `title`, `type`, `slug`,
`external_id`, `date`, `url`, `duration`, `sku`, `site_id`, `site`, `performers`,
`directors`, `created`, `last_updated`. `scenes` contains attached scene resources
for a movie; `movies` contains memberships for a scene. `links` is a nullable
map of source name to nullable URL; an IAFD link can be absent. Performers have
`id`, `name`, `slug`, nullable `aliases`; sites have numeric `id`, `uuid`, `name`,
`url`, and a parent site. Keep provider identities separate from source-site
identifiers. This is a subset of the schema, not a promise every value is present.

The schema's `duration` is numeric but does not document its unit. The `rating`
field is not documented as a Rotten Tomatoes/Metacritic score. Do not relabel
it as a critic score or invent review totals. Media-bearing fields exist but
were not fetched; a metadata-only client can ignore them.

### Limits and side effects

No numerical service quota, price, redistribution licence or retry-header
contract was verified in the inspected OpenAPI. The provider-owned plugin
[HTTP client](https://github.com/ThePornDatabase/Jellyfin.Plugin.ThePornDB/blob/3ab15ffb4a0f85d76bc6d2c3ea9753c323f1ba8a/Jellyfin.Plugin.ThePornDB/Helpers/Utils/HTTP.cs)
throttles itself to 120 requests/minute; that is client behavior, **not** proof
of the service's current allowance. Start substantially lower, cache results and
respect 429/Retry-After. The detail routes expose `add_to_collection`; omit it
for metadata reads. Never call collection, suggestion or hash-submission writes
as part of identification.

## StashDB and stash-box: exact GraphQL boundary

The official Stash [instance directory](https://docs.stashapp.cc/metadata-sources/stash-box-instances/)
lists **`https://stashdb.org/graphql`**. It also lists ThePornDB's separate
`https://theporndb.net/graphql` implementation and notes it is proprietary;
do not assume that endpoint has perfect schema parity with stash-box.

The upstream [stash-box README](https://github.com/stashapp/stash-box/blob/c69ab88efb1906dafa4bc6afefb9fa41daed5334/README.md)
documents an **`ApiKey` request header**. The user supplies their instance key;
read operations require the READ role. Public schema/source inspection does not
prove access to the deployed StashDB service or establish its current quota.

Source snapshot inspected: stash-box `c69ab88efb1906dafa4bc6afefb9fa41daed5334`.
The [root schema](https://github.com/stashapp/stash-box/blob/c69ab88efb1906dafa4bc6afefb9fa41daed5334/graphql/schema/schema.graphql)
provides `searchScene(term: String!, limit: Int): [Scene!]!`,
`findScene(id: ID!): Scene`, and
`queryScenes(input: SceneQueryInput!): QueryScenesResultType!`.
The latter returns `count` and `scenes`; page defaults to 1 and per_page to 25,
with no maximum declared in this schema. Set a client bound such as 10 and a
hard maximum number of pages; do not imply a server guarantee.

Neutral minimum search query, with variables `{ "term": "Example Studio 2026-01-01", "limit": 10 }`:

```graphql
query Search($term: String!, $limit: Int!) {
  searchScene(term: $term, limit: $limit) {
    id title release_date duration code deleted
    studio { id name }
    performers { as performer { id name disambiguation aliases } }
  }
}
```

For details, replace the search field with `findScene(id: $id)` and declare
`$id: ID!`; keep the same selection. GraphQL responses are wrapped in `data`,
and an `errors` array must be handled even when HTTP status is 200. Names are
not unique identities. `performers` is a list of **PerformerAppearance wrappers**,
not direct performer objects; `as` preserves the credited alias.
[Scene schema](https://github.com/stashapp/stash-box/blob/c69ab88efb1906dafa4bc6afefb9fa41daed5334/graphql/schema/types/scene.graphql),
[Performer schema](https://github.com/stashapp/stash-box/blob/c69ab88efb1906dafa4bc6afefb9fa41daed5334/graphql/schema/types/performer.graphql).

Scene fields also include `director`, `urls`, tags, fingerprints and timestamps.
Use `release_date` rather than deprecated `date`. `findPerformer(id)` and
`findStudio(id/name)` plus paginated queries support separate entity views;
studios include parent/child relationships.
[Studio schema](https://github.com/stashapp/stash-box/blob/c69ab88efb1906dafa4bc6afefb9fa41daed5334/graphql/schema/types/studio.graphql).

Fingerprints can match a scene using MD5, OSHASH or PHASH, but are not necessary
for the first adapter. No hashes were generated/submitted. The official
[matching guide](https://docs.stashapp.cc/guides/scraping-scenes-via-stash-box/)
distinguishes potentially inaccurate automatic identification from verification,
and documents submitting fingerprints as a separate action. Zanzibarr should
preserve that separation and not read an entire remote stream merely to hash it.

## Local Stash is a separate connector

Official [Stash API documentation](https://docs.stashapp.cc/api/) specifies
`http://localhost:9999/graphql` by default and the **`ApiKey` header**. An existing
user-configured instance may use another host/port; use its explicit endpoint
and HTTPS for remote credentials. Query only the metadata requested; local file
paths and playback/history fields are unnecessary for a title catalog reader.

The inspected local Stash snapshot is
`bdee3c83d33d802765332967f09db756e2877bcc`. Its
[root schema](https://github.com/stashapp/stash/blob/bdee3c83d33d802765332967f09db756e2877bcc/graphql/schema/schema.graphql)
uses `findScenes(scene_filter, ids, filter)` rather than stash-box's `searchScene`.
`findScene(id, checksum)` and `findSceneByHash(input)` exist; movie methods are
deprecated in favor of `findGroup`/`findGroups`. Its scene performers are direct
performer objects, and `stash_ids` retains external identity mappings.
[Local scene schema](https://github.com/stashapp/stash/blob/bdee3c83d33d802765332967f09db756e2877bcc/graphql/schema/types/scene.graphql).

A `StashID` combines **`endpoint` + `stash_id` + `updated_at`**. Preserve the
endpoint namespace: identical strings from different databases are not the same
entity. Local `rating100` is a local 1-100 rating, not a professional critic
aggregate. The source default `max_requests_per_minute: 240` for outgoing
stash-box access is a local client configuration, not a StashDB service quota.
[Stash-box mapping/config schema](https://github.com/stashapp/stash/blob/bdee3c83d33d802765332967f09db756e2877bcc/graphql/schema/types/stash-box.graphql).

## Suggested application contract and verification

- Add namespaced identities `{provider, endpoint, kind, id}`. Use kinds scene,
  movie, performer and studio; preserve movie/scene membership. Keep automatic
  candidates separate from chosen corrections and persist the latter across
  reopening independently of artwork/metadata cache eviction.
- Keep metadata access optional and explicitly configured. Use a read-only
  allowlist of operations, secure-store tokens, redact request bodies/URLs in
  logs and keep provider keys out of source and error text.
- Prefer direct provider ID/source URL to title matching. For filename hints,
  use date, studio and credited performers to disambiguate; never accept the
  first fuzzy result or merge people by name alone. Expose optional Rematch.
- Fetch visible results only, coalesce identical jobs, cap responses/timeouts,
  use a small request queue, negative-cache empty results and back off on 429.
  Treat missing metadata honestly. Cache provider fields with provenance.
- For this first integration, use non-graphic text fields; do not automatically
  request previews, trailers or artwork as a side effect of a provider test.
  Do not send titles, filenames or hashes to another provider without its
  metadata connection being enabled.
- Verify adapters against synthetic fixtures for list/detail wrappers, empty
  fields, wrong kinds, aliases, ambiguity, deleted scenes, malformed JSON,
  GraphQL errors, expired tokens, 429, stale results and persisted rematching.
  A later authenticated contract check should request only selected non-graphic
  fields and must not be presented as completed by this research.

Current external prerequisites: user-configured provider access and confirmation
of permitted use/redistribution and real account limits. IAFD's official API and
current terms remain unverified. No application files changed in this research.


## Artwork schema and release-category follow-up

No images were requested. If artwork display is enabled during implementation,
ThePornDB's `SceneResource.image`, `back_image`, `poster_image` and `poster` are
nullable strings. `posters` and `background` each expose nullable `full`, `large`,
`medium`, `small` strings. Official OpenAPI examples reference
`cdn.theporndb.net` and `thumb.theporndb.net`; this is evidence of first-party
asset hosts, not a guarantee that they are exhaustive or that arbitrary
third-party URLs should be trusted. Validate HTTPS URLs, redirects and response
bounds. `media` references `MediaResource {id, url, size, order}`.
[Official TPDB schema](https://api.theporndb.net/specs?openapi.json).

Stash-box's `Image` has `id: ID!`, `url: String!`, `width: Int!`, `height: Int!`.
No asset host is fixed in that contract. Require a configured/trusted source
policy rather than assuming every stash-box image is on stashdb.org.
[Image schema](https://github.com/stashapp/stash-box/blob/c69ab88efb1906dafa4bc6afefb9fa41daed5334/graphql/schema/types/image.graphql).

Newznab's primary category table explicitly assigns **6000 to XXX**, with
6010-6070 subcategories. Use general `t=search` with `cat=6000` for release
handoff where the indexer's CAPS supports it. The standard `t=movie` ID filter
uses IMDb IDs, so a TPDB/StashDB UUID must never be sent as `imdbid`. Query text
can include a confirmed title, studio and date; retain the release's profile ID
and normal bounded pagination/retry behavior. Metadata matching and Usenet
release identity remain separate.
[Newznab API/category specification](https://newznab.readthedocs.io/en/latest/misc/api.html#predefined-categories).
