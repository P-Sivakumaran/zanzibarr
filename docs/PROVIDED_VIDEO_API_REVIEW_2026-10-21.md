# Review of the four supplied video API links - 2026-10-21

Developer-documentation review only. No catalog search, account creation,
subscription purchase, images, video, embeds or stream-extraction endpoint calls
were made. Current documentation availability is not proof of live playback.

## Classification and impact on the earlier research

| Supplied link | Verified purpose | Playback conclusion |
| --- | --- | --- |
| [Eporner API v2](https://www.eporner.com/api/v2/) | Provider-run catalog API and embedding integration | Documented embed route; native MP4/HLS contract not established |
| [pAPI](https://www.papi.rest/) | Performer information API | Current docs do not supply video search/playback |
| [RapidAPI listing](https://rapidapi.com/mixerboxmada/api/porn-xnxx-api) | Seller describes a third-party search/extraction wrapper | Seller advertises media links; access rights, reliability and playback unverified |
| [Reddit discussion](https://www.reddit.com/r/webdev/comments/1f0w4sj/looking_for_a_api_on_porn_videos/) | Developer discussion and suggestions | Leads only, no API contract or permission evidence |

The earlier Stash/Jellyfin recommendation covers personal media libraries.
These links instead ask about provider-hosted catalogs. That is a different
integration category: a provider-owned embed API can be relevant without a
self-hosted library. A database, embedded web player and native stream URL
should remain separate source capabilities in the application.

## Eporner: official catalog/embed API

Official documentation describes paginated search, ID lookup and removed-ID
methods. Responses include an `embed` URL, not a documented direct MP4/HLS
playback contract. No key parameter, current request quota or SLA was verified.
This supports an official catalog/embed classification, not a promise that
libmpv can play the returned URL. No documented-method catalog request was run.
[Provider documentation](https://www.eporner.com/api/v2/).

The [terms](https://www.eporner.com/terms/) distinguish permitted documented
public API use from other automated access. They separately describe a limited
personal, non-commercial website embedding grant, prominent link-back and
unaltered player requirements. Native Flutter/WebView embedding permission is
not established by that wording; implementation fit needs confirmation.
Referrer, device or territorial restrictions must not be bypassed. This is not
a blanket assertion that documented API use requires written permission.

## pAPI: real performer endpoint, future video plans

The official introduction explicitly limits current data to performer details
via `/pornstars/`; filmographies and streaming/video links are listed as plans.
The landing page uses the same future tense. It therefore cannot currently be
selected as a documented video-search/playback provider.
[Official introduction](https://docs.papi.rest/),
[Landing page](https://www.papi.rest/).

The quick-start documents a GET endpoint at
`https://papi-pornstarsapi.p.rapidapi.com/pornstars/`, with `x-rapidapi-host`
and `x-rapidapi-key` request headers. Endpoint documentation supports
case-insensitive `name` matching, ordering and `page_size` up to 100. No live
request was made and no reusable cross-provider performer-ID contract was
verified. These are metadata lookup capabilities, not video capabilities.
[Quick start](https://docs.papi.rest/guide/getting-started),
[Endpoint documentation](https://docs.papi.rest/endpoints/pornstars).

The landing page's broad statement about access to all data does not specify
requests per minute, billing allowance or a service-level commitment. No
current public subscription price, exact quota, update cadence or redistribution
licence was established. A 2022 footer is not proof the service is defunct,
and a reachable documentation site is not proof the authenticated API works.

## RapidAPI: distinguish seller claims from verified service behavior

The rendered text retrieved by the web tool exposed only the listing title;
the pricing route exposed no readable plan details. A fresh normal HTTP fetch
of the developer listing did expose its embedded public metadata: owner display
**Mixer Box**, profile slug **mixerboxmada**, listing status **ACTIVE**, pricing
classification **FREEMIUM** and last-updated timestamp
**2026-09-09 21:13:28 UTC**. These are marketplace listing attributes, not an
independent health check or proof of recent backend maintenance.
[Supplied developer listing](https://rapidapi.com/mixerboxmada/api/porn-xnxx-api).

The seller's description calls the product a scraper and advertises keyword
search with pagination and extracted media links. That classifies the advertised
product as a third-party wrapper; official affiliation with the source platform
was not verified. No extraction request or playback test was performed.

Exact endpoint schemas, currently selectable public plan prices/quotas,
authentication details for this particular listing, source-site permission,
media-link expiry and permitted embedding/native reuse remain unverified.
Standard marketplace key conventions alone do not
establish this product's contract. Do not promise reliable native playback or
purchase a plan based only on the listing's availability label.
[Pricing page inspected](https://rapidapi.com/mixerboxmada/api/porn-xnxx-api/pricing).

## Reddit: useful context, not evidence of present API access

The discussion asks for thumbnails, metadata and embed links. Replies suggest
affiliate programs, scraping and third-party providers; some promote their own
services. These are suggestions and historical anecdotes, not current service
contracts, endorsements or proof of upstream permission. No linked catalog or
media requests were followed from the thread.
[User-supplied discussion](https://www.reddit.com/r/webdev/comments/1f0w4sj/looking_for_a_api_on_porn_videos/).

## Result for Zanzibarr

The supplied links justify correcting the earlier framing: official hosted
catalog/embed APIs and personal-library streaming servers are distinct options.
pAPI adds performer data rather than playback. The RapidAPI listing makes
untested extraction claims and needs a verified contractual/technical basis.
An embed URL must never be opened as though it were a native media file.

Before implementation, document the selected provider's allowed application
use, source identity, result schema, available playback capability and failure
states. A contract test should distinguish catalog access,
embedding restrictions, expired/removed items and native stream compatibility.
No new provider has been enabled and no application files changed in this pass.
