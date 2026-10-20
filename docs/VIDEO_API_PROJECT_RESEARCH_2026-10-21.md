# Video API and project research - 2026-10-21

## Decision

For **search followed by actual playback**, connect to an existing video server,
not another metadata database. **Stash is the shortest fit for a user-managed
scene library; Jellyfin is the strongest general film/TV solution.** XBVR is a
specialist VR-library option. PeerTube provides instance-hosted/federated video
publishing. None supplies an entitlement-independent hosted commercial catalog.
A metadata title, poster or source-page URL is not a playable video.

This is research, not installation or a completed connector. No catalog records,
explicit imagery/video, account credentials or remote media were fetched.
GitHub API metadata, releases, documentation and source were inspected; source
contracts below still require a test against the user's configured server.

## Current maintenance and licence evidence

Latest-release and commit dates were obtained directly from GitHub's repository,
`releases/latest` and `commits?per_page=1` APIs on this date. None of the listed
repositories was marked archived. Dates demonstrate recent maintenance, not
proof every upstream scraper or server feature works.

| Project | Latest release (UTC) | Latest default-branch commit inspected | Licence/status |
| --- | --- | --- | --- |
| [Stash](https://github.com/stashapp/stash/releases/tag/v0.31.1) | v0.31.1, 2026-04-13 | [bdee3c83](https://github.com/stashapp/stash/commit/bdee3c83d33d802765332967f09db756e2877bcc), 2026-10-07 | AGPL-3.0 reported by GitHub |
| [XBVR](https://github.com/xbapps/xbvr/releases/tag/0.4.40) | 0.4.40, 2026-09-14 | [dc8c9f04](https://github.com/xbapps/xbvr/commit/dc8c9f04396cc9e6dde1b0f4600713673c3586ce), 2026-09-14 | No licence identified by GitHub or LICENSE/COPYING file in inspected tree; do not assume reuse permission |
| [Jellyfin](https://github.com/jellyfin/jellyfin/releases/tag/v12.2) | v12.2, 2026-10-05 | [08c2ba6e](https://github.com/jellyfin/jellyfin/commit/08c2ba6e0b6499122822f1c5b18bc426104538b4), 2026-10-17 | GPL-2.0 reported by GitHub; review LICENSE before code reuse |
| [PeerTube](https://github.com/Chocobozzz/PeerTube/releases/tag/v8.3.1) | v8.3.1, 2026-09-28 | [1e499b13](https://github.com/Chocobozzz/PeerTube/commit/1e499b13d1ef16d1be2b2707b3e09f750764c43f), 2026-10-16 | AGPL-3.0 reported by GitHub |
| [Fladder](https://github.com/DonutWare/Fladder/releases/tag/v0.11.1) | v0.11.1, 2026-09-08 | [de7b5a2a](https://github.com/DonutWare/Fladder/commit/de7b5a2a23f16f5f3bb164ec0baedf50941e4808), 2026-10-18 | GPL-3.0 reported by GitHub; existing Flutter Jellyfin client |
| [Prowlarr](https://github.com/Prowlarr/Prowlarr/releases/tag/v2.6.5.5623) | v2.6.5.5623, 2026-09-16 | [26a605e4](https://github.com/Prowlarr/Prowlarr/commit/26a605e41f6156b959bc8f3ae5db4bec252106c5), 2026-10-18 | GPL-3.0 reported by GitHub; indexer manager, not a video server |

Server-software licences do not license the user's media, provider metadata or
third-party artwork. Prefer independent HTTP adapters over copying server/client
implementation code; review obligations if code is reused or redistributed.

## Comparison for Zanzibarr

| Option | What can be searched | What can actually play | Setup and fit |
| --- | --- | --- | --- |
| Stash | Configured local library: scenes, performers, studios, tags, groups | Indexed files through direct/converted server streams | Run/configure own server and library; strongest scene-library fit |
| Jellyfin | Configured film/TV/video libraries and user-visible items | Direct play, remux or transcoding according to client profile | Own server/account and files; strongest general-purpose playback integration |
| XBVR (`xbapps/xbvr`) | Matched VR library and scene metadata | Accessible local matched files through DMS/player APIs | Own server/files; VR projection requires dedicated renderer or external headset player |
| PeerTube | Videos known to chosen instance, subject to federation/search policy | Authorized instance-hosted video files/HLS | Choose/run instance; publisher/platform model rather than personal-library matching |
| Prowlarr | Configured indexers, using Newznab/Torznab APIs | No video stream; returns releases/NZBs/torrents | Useful indexer adapter for existing Usenet engine, not a replacement player |

## Stash: minimal implementable search-to-play contract

Endpoint: user-configured `<base>/graphql`, default
`http://localhost:9999/graphql`; send `ApiKey: <key>` and JSON POST.
The official [API documentation](https://docs.stashapp.cc/api/) documents both.
Use `findScenes(filter: {q: $query, page: 1, per_page: 20})` and request only
`count`, `scenes {id title date studio {id name} performers {id name}}` for a
list. Detail can use `findScene(id: $id)`. Local Stash's schema differs from
remote StashDB/stash-box.
[Query schema](https://github.com/stashapp/stash/blob/bdee3c83d33d802765332967f09db756e2877bcc/graphql/schema/schema.graphql).

At Play time, request `sceneStreams(id: $id) {url mime_type label}` or
`findScene(id: $id) {sceneStreams {url mime_type label}}`. Select a supported
returned stream; do not construct an undocumented path or treat the source
website URL as media. Stream alternatives can include direct, MP4, WebM, HLS
and DASH depending on media/configuration.
[Stream schema](https://github.com/stashapp/stash/blob/bdee3c83d33d802765332967f09db756e2877bcc/graphql/schema/types/scene.graphql),
[Stream choices implementation](https://github.com/stashapp/stash/blob/bdee3c83d33d802765332967f09db756e2877bcc/internal/manager/scene.go).

The inspected resolver generates signed stream-prefix parameters when configured
credentials exist; otherwise an API key can be included in the returned stream
URL. Preserve the returned URL and expiry behavior, fetch it just before Play,
and never log or permanently save it. Some preview/image paths rely on cookie
authentication, so stream success does not prove image access.
[Scene resolver](https://github.com/stashapp/stash/blob/bdee3c83d33d802765332967f09db756e2877bcc/internal/api/resolver_model_scene.go),
[Signed request authentication](https://github.com/stashapp/stash/blob/bdee3c83d33d802765332967f09db756e2877bcc/internal/api/authentication.go).

Existing local Stash is needed for this connector. StashDB itself is a metadata
service, not a video host; a working StashDB key cannot produce local-library
video URLs. Source development behavior must be verified against the deployed
server version, especially signed URL and user-session differences.

## Jellyfin: robust general library and playback

Use configured base URL including any path prefix. Authenticate a user with
`POST /Users/AuthenticateByName`, obtain `AccessToken` and user identity, and
send a modern `Authorization: MediaBrowser Client="Zanzibarr", Device="...",
DeviceId="...", Version="...", Token="..."` header. Do not assume legacy
X-Emby headers or old query-key spellings remain enabled.
[Authentication controller](https://github.com/jellyfin/jellyfin/blob/08c2ba6e0b6499122822f1c5b18bc426104538b4/Jellyfin.Api/Controllers/UserController.cs),
[Header parser](https://github.com/jellyfin/jellyfin/blob/08c2ba6e0b6499122822f1c5b18bc426104538b4/Jellyfin.Server.Implementations/Security/AuthorizationContext.cs).

Search: `GET /Items?SearchTerm=Example&Recursive=true&IncludeItemTypes=Movie,Episode&Limit=20&StartIndex=0`
with user context. At Play use `POST /Items/{itemId}/PlaybackInfo` with an honest
DeviceProfile/audio/subtitle/bitrate selection. Response includes `MediaSources`
and `PlaySessionId`; use the negotiated media source and any `TranscodingUrl`
rather than assuming the item path is streamable. Static streaming is exposed
under `/Videos/{itemId}/stream[.{container}]`, subject to access and source
selection.
[Items controller](https://github.com/jellyfin/jellyfin/blob/08c2ba6e0b6499122822f1c5b18bc426104538b4/Jellyfin.Api/Controllers/ItemsController.cs),
[Playback negotiation](https://github.com/jellyfin/jellyfin/blob/08c2ba6e0b6499122822f1c5b18bc426104538b4/Jellyfin.Api/Controllers/MediaInfoController.cs),
[Video stream controller](https://github.com/jellyfin/jellyfin/blob/08c2ba6e0b6499122822f1c5b18bc426104538b4/Jellyfin.Api/Controllers/VideosController.cs).

A complete client reports `/Sessions/Playing`, `/Sessions/Playing/Progress`
and `/Sessions/Playing/Stopped`, preserving source/session IDs and ticks, and
cleans up transcoding work. Native libmpv can support many formats but must not
claim every platform supports every profile.
[Session controller](https://github.com/jellyfin/jellyfin/blob/08c2ba6e0b6499122822f1c5b18bc426104538b4/Jellyfin.Api/Controllers/PlaystateController.cs),
[Codec/transcoding guidance](https://jellyfin.org/docs/general/clients/codec-support/).

[Fladder's Flutter/media_kit dependencies](https://github.com/DonutWare/Fladder/blob/de7b5a2a23f16f5f3bb164ec0baedf50941e4808/pubspec.yaml)
are concrete evidence that the stack is feasible, not drop-in source permission
or proof our app already implements sessions correctly. Local and remote
Jellyfin work over HTTP(S); remote access needs deliberate server configuration.
[Networking](https://jellyfin.org/docs/general/post-install/networking/).

## XBVR: specialist alternative and caveats

Actual repository: **[xbapps/xbvr](https://github.com/xbapps/xbvr)**. Its README
documents user video folders, native/Docker deployment, DLNA and DeoVR/HereSphere
interfaces. It does not supply the user's video files. Local default port 9999
can conflict with Stash's default; setup must distinguish the servers.
[README](https://github.com/xbapps/xbvr/blob/dc8c9f04396cc9e6dde1b0f4600713673c3586ce/README.md).

Verified source routes include `/api/scene/search?q=...`,
`POST /api/scene/list`, `GET /api/scene/{scene-id}` and
`GET /api/dms/file/{file-id}`. The DMS handler serves the matched accessible
file, while player-facing APIs produce file links and VR metadata.
[Scene routes](https://github.com/xbapps/xbvr/blob/dc8c9f04396cc9e6dde1b0f4600713673c3586ce/pkg/api/scenes.go),
[DMS routes](https://github.com/xbapps/xbvr/blob/dc8c9f04396cc9e6dde1b0f4600713673c3586ce/pkg/api/dms.go).

Configured UI Basic authentication wraps `/ui/`; that alone is not evidence
all API/file/websocket routes are protected. Keep a connector on a trusted
network with explicitly verified transport/access controls. The server source
and player APIs use separate authentication behavior. No general-purpose
public bearer-auth contract was verified.
[Server route/auth wiring](https://github.com/xbapps/xbvr/blob/dc8c9f04396cc9e6dde1b0f4600713673c3586ce/pkg/server/server.go),
[DeoVR adapter](https://github.com/xbapps/xbvr/blob/dc8c9f04396cc9e6dde1b0f4600713673c3586ce/pkg/api/deovr.go).

Do not implement a flat Flutter video window and call it correct VR playback.
Projection, stereoscopic layout and headset interaction need dedicated support;
external DeoVR/HereSphere handoff is a practical specialist route. Scraper
maintenance is independent of serving already-indexed local files.

## PeerTube: real hosted-video API, different product scope

Official source OpenAPI documents `GET /api/v1/search/videos?search=Example`
with `start`/`count` pagination and instance-controlled search/federation policy.
`GET /api/v1/videos/{id}` returns VideoDetails, including direct `files[].fileUrl`
and `streamingPlaylists[].playlistUrl` where available. Select supported HTTP/HLS
output; native Flutter does not need to implement browser WebTorrent merely to
play those authorized HTTP variants.
[Official OpenAPI](https://github.com/Chocobozzz/PeerTube/blob/1e499b13d1ef16d1be2b2707b3e09f750764c43f/support/doc/api/openapi.yaml),
[Video detail handler](https://github.com/Chocobozzz/PeerTube/blob/1e499b13d1ef16d1be2b2707b3e09f750764c43f/server/core/controllers/api/videos/index.ts).

Public videos can be readable without login. Private/restricted content requires
the instance's authorization. OAuth setup uses `/api/v1/oauth-clients/local`
and `/api/v1/users/token`; requests carry `Authorization: Bearer ...` and token
refresh/expiry must be handled. Software/federation does not grant access to
all videos globally. Never turn a remote URL search into an unannounced import
or claim a provider's private playback is publicly available. This is a larger
scope change than connecting a personal Stash/Jellyfin server.

## Prowlarr: useful indexer adapter, no streaming

Prowlarr exposes Newznab-compatible routes `/{id}/api` and
`/api/v1/indexer/{id}/newznab` for configured indexers.
[Primary controller](https://github.com/Prowlarr/Prowlarr/blob/26a605e41f6156b959bc8f3ae5db4bec252106c5/src/Prowlarr.Api.V1/Indexers/NewznabController.cs).
Root code inspection indicates Zanzibarr preserves indexer base paths ending in
`/api`, so an existing Prowlarr `/{id}/api` endpoint is a plausible compatible
configuration. This is an inference, not a live integration result. A running
user instance, API key and working underlying indexer accounts are needed.
It still returns release records/NZBs rather than media streams; playback stays
with the existing bounded Usenet engine.

## Current probes and remaining evidence

Parent-session checks on this date, separate from this background research:
TPDB Swagger/OpenAPI returned HTTP 200 and current scene/movie routes remain
present. StashDB `query {__typename}` returned HTTP 200/data; the app's search
query passed server validation with its resolver skipped, so no catalog results
were fetched. Default local Stash `localhost:9999` connection failed: there is
no verified local video server at that address. These checks do **not** verify
account permissions, real matching, metadata completeness or playback. No
software installation or new server was started.

The reported connection failures therefore need endpoint/auth/configuration
traces rather than assuming an entire provider is defunct. Search availability,
metadata access, source-video availability and playback negotiation are separate
checks.

## Setup audit of the shipped 1.26 build

The prior implementation was schema/fixture tested, not demonstrated with live
provider accounts. That is insufficient evidence for a working onboarding flow.
Code inspection at `bdfd70a` confirms the adult screen has key fields but no
account-setup links or independent connection test. All search errors become
short sanitized messages; this protects credentials but does not distinguish
all account, contract and server failures for the user. These are confirmed
setup/diagnostic gaps, not a reproduced cause of this user's specific failure.
The exact failed service, error and failure stage were requested; no answer was
available during this research. No credentials were read or reset.

Further root-session network checks on 2026-10-21 Australia/Sydney:

| Probe | Observation | What it proves |
| --- | --- | --- |
| TPDB current OpenAPI | HTTP 200, v3.24.757, scene/movie GET routes | Public contract is available |
| TPDB Swagger | HTTP 200 | Documentation endpoint is reachable |
| TPDB search without authentication | HTTP 401; no response body read | Search route responds and requires authentication |
| TPDB registration HEAD | HTTP 200 | Registration route exists, not successful activation |
| TPDB API-token settings HEAD | Redirect to login, then HTTP 200 | A signed-in account is required; token issuance not tested |
| StashDB registration HEAD | HTTP 200 | Registration route exists, not a tested invitation/account |
| StashDB query validation | HTTP 200, zero errors; scene resolver skipped | App query fields/arguments match deployed schema |
| Optional loopback Stash | Connection unavailable on port 9999 | No server verified at the default address |

Reproduce the safe public checks with
`python tools/probe_metadata_apis.py --local-stash`. The script does not accept
keys or fetch catalog records/media. Its JSON scope explicitly excludes
registration, authenticated search and playback. The fresh report is retained
under ignored `dist/audit/metadata-api-preflight-2026-10-21.json`.

The [official StashDB onboarding guide](https://guidelines.stashdb.org/docs/faq_getting-started/stashdb/accessing-stashdb/)
requires an invitation and email activation, followed by obtaining the account's
API key. Link to its maintained guide rather than shipping an expiring invite.
The [provider's own Namer configuration](https://github.com/ThePornDatabase/namer/blob/main/namer/namer.cfg.default)
points at the current TPDB registration domain. Historical reports about the
old metadataapi.net shutdown are not proof the current service is defunct:
[Whisparr's March 2024 migration fix](https://github.com/Whisparr/Whisparr/pull/167)
changed the old domain and closed that historical shutdown issue. This does not
establish present account eligibility or successful signup for this user.

IAFD remains an unverified direct API option. No current official access
contract was established in the earlier [metadata research](ADULT_METADATA_RESEARCH_2026-10-21.md).
A GitHub scraper implementation is not a stable, documented provider API.

## Other hosted video options and existing metadata sources

For non-adult open/licensed video, Internet Archive publishes an item metadata
API with a file list and stable `/download/{identifier}/{filename}` URLs.
This is an actual file-hosting path, unlike a ratings database. A connector
would need search, item/file selection, access/licence checks, supported media
formats and bounded redirect/range handling; item availability alone does not
establish rights or playable formats.
[Metadata read API](https://archive.org/developers/md-read.html),
[item files and archival URLs](https://archive.org/developers/items.html),
[metadata fields](https://archive.org/developers/metadata-schema/index.html).
No live Archive item/media playback was tested here.

YouTube has an official Data API for search and an IFrame Player API for
embedded playback. Use embeddable-video results and the official player; search
does not yield a stable direct MP4 URL for libmpv. API quota, owner embedding
restrictions and regional/access conditions still apply. This fits trailers and
authorized public videos, not a general feature-film streaming entitlement.
[Search reference](https://developers.google.com/youtube/v3/docs/search/list),
[IFrame player](https://developers.google.com/youtube/iframe_api_reference).

TMDB remains a data/image provider. Its FAQ describes API keys and attribution,
and its legal notice restricts use of its data/images with pornographic content;
keep its mainstream enrichment separate from any adult catalog integration.
[Official FAQ](https://developer.themoviedb.org/docs/faq).
OMDb and other ratings/catalog APIs likewise must not be represented as sources
of playable full videos unless a separate verified media contract exists.

## Concrete implementation sequence

1. Add a first **Stash library connector**: configured base URL/key, diagnostics,
   bounded search, details, Play-time stream resolution and optional persisted
   source identity. Test with a user-owned neutral video fixture.
2. Add Jellyfin after the playback abstraction supports authenticated media and
   server sessions. Keep direct/remux/transcode decisions provider-specific.
3. Preserve the existing NZB workflow and optional Prowlarr configuration.
   Keep TPDB/StashDB labels honest as metadata sources.
4. Consider XBVR only for a requested headset workflow; keep PeerTube as a
   separate publishing/federation connector rather than bloating initial scope.

A new source must resolve to an ephemeral playback descriptor containing URL,
required headers, source identity and cleanup/session behavior. The current
player accepts NZB/local-file inputs and opens Media(url) without source HTTP
headers; simply adding a search screen or persisting a token-bearing URL does
not complete playback. History/casting must never expose provider credentials.
Use bounded requests, origin checks, sanitized errors, cancellation and a real
seek/close/expired-token verification before calling a connector complete.

## Verification of this research change

All 45 external primary-source links in this report returned HTTP 200 during
link checking. The public probe passed for TPDB documentation and the deployed
StashDB contract; optional default local Stash remained unavailable. Positive,
negative and malformed-response checks of the probe passed. Python compilation
and `git diff --check` passed. No application source changed, so the full native
application gate and installer build were not rerun. Earlier 1.26 test results
are not evidence of live account setup or any connector proposed here.
