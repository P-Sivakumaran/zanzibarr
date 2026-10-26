# API contract follow-up - 2026-10-21

Documentation-only follow-up for the authorized personal, non-commercial app.
No catalog, extraction, image, video or embed requests were made; no credentials,
accounts or purchases were used. Only this report changed.

## pAPI response and identity

The official example response is an envelope with `count`, nullable `next` and
`previous`, and `results` (not `data`). Records contain `name` and `slug`.
The example contains no `id`, UUID or `aliases` field, and does not establish
slug immutability. Do not invent a stable numeric identity or cross-provider
match from a name. A provider-plus-slug key is provisional, not a documented
permanent identity guarantee.

`images` is an array that can be empty; populated entries contain `image_link`
and `image`. Documented URL examples use `cdni.pornpics.com` and
`soulfulwater.pythonanywhere.com`. These are example hosts, not proof of a
complete trusted-host list or permission to fetch arbitrary URLs. Preserve
optional values, validate URL schemes/origins and avoid automatic media access.
[Official example response](https://docs.papi.rest/guide/example-response).

The known GET `/pornstars/` endpoint and RapidAPI-key headers remain performer
metadata capabilities; the official introduction describes video/filmography
links as future plans. No direct-media capability was verified.
[Introduction](https://docs.papi.rest/),
[Quick start](https://docs.papi.rest/guide/getting-started).

## RapidAPI: route inventory is not a complete contract

The supplied developer listing's embedded public page metadata exposes POST
`/search` and `/video` route names, alongside other advertised operations.
No public OpenAPI/request-body/response-field/authentication contract sufficient
for a safe adapter was verified in this bounded follow-up. Route names alone
do not establish accepted parameters, returned media formats, expiry, pagination
or upstream reuse rights. No actual API call was made.

Keep the existing classification: third-party seller/extraction claims, not
verified official source-platform integration. Public selectable plans and
current quotas remain unverified. Do not fabricate a base host or payload from
common RapidAPI conventions. Personal non-commercial use does not fill these
technical contract gaps.
[Provided developer listing](https://rapidapi.com/mixerboxmada/api/porn-xnxx-api).

## Eporner: validation limits from documented examples

The documented search envelope has `count`, `start`, `per_page`, `page`,
`time_ms`, `total_count`, `total_pages` and `videos`. Video examples contain
`id`, `title`, `keywords`, `views`, `rate`, `url`, `added`, `length_sec`,
`length_min`, `embed`, `default_thumb` and `thumbs`; thumbnails include
`size`, `width`, `height`, `src`.

The ID reference specifies a case-sensitive 11-character string; examples are
alphanumeric. Restricting its alphabet to ASCII letters/digits remains a
conservative adapter policy. The API's thumbnail examples use
`static-ca-cdn.eporner.com`; do not infer all regional CDN hosts are permitted.

`rate` is explicitly documented as a float from 0.00 to 5.00. Label it as the
provider's own five-point rating, not IMDb/RT/Metacritic. `embed` is a web-player URL,
not a native MP4/HLS URL. No live records or player were opened.
[Official API v2 documentation](https://www.eporner.com/api/v2/).

## Implementation consequences

Use documentation-backed parsers with optional fields and bounded pagination.
Keep namespaced provider identities separate from display names, metadata
snapshots and playback capabilities. Do not turn incomplete contract research
into an implementation that silently guesses routes, rating scales, credentials
or stream URLs. This report adds no mandatory per-title matching step.
