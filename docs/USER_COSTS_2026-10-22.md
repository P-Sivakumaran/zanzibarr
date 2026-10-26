# Zanzibarr user costs

Checked 22 October 2026. Personal, non-commercial use; prices are USD before tax, currency conversion, broadband and storage costs. Provider prices, quotas and availability can change. Existing compatible accounts can be reused.

## Playback and metadata

| Service | Needed for | Cost and qualification |
| --- | --- | --- |
| Zanzibarr | The application | No application subscription or licence charge. |
| Usenet provider | Fetching media from Usenet | Paid account required for Usenet playback. As one example, [Newshosting advertises Unlimited from $12.95/month](https://www.newshosting.com/usenet-plans/). Confirm the billing term, introductory period and renewal price at checkout. |
| Newznab-compatible indexer | Integrated release search | Separate API-enabled membership may be required. Allow **$15–30/year** for budgeting; this is an estimate, not a verified current quotation. Check the selected indexer's API quota and checkout price. Not needed when bringing your own NZBs. A Usenet provider's bundled search is not necessarily a compatible indexer API. |
| OMDb | Title facts, available IMDb/RT/Metacritic scores and episode listings | [Free API key: 1,000 requests/day](https://www.omdbapi.com/apikey.aspx?__EVENTTARGET=freeAcct). Higher quota is optional. The separate paid Poster API is not required. |
| TMDB | Artwork, cast, trailers and episode stills/runtime | [Free for non-commercial use with attribution](https://developer.themoviedb.org/docs/faq); register for an API read token. |
| Wikidata | Optional filming/narrative locations | [Free public data access](https://www.wikidata.org/wiki/Wikidata:Data_access). Public endpoint limits apply. |
| Additional metadata/MCP provider | Specialist catalogs or missing review counts | Optional, provider-dependent pricing and access. Not included with OMDb/TMDB. Obtain a quote for the selected provider rather than assuming a universal subscription. |

Separate IMDb, Rotten Tomatoes and Metacritic subscriptions are not required for the existing OMDb-based display. Paying for a metadata quota does not guarantee missing critic review counts. Local-file playback does not require Usenet or an indexer. The app does not require a VPN, YouTube Premium, Plex Pass or a separate paid downloader.

## Optional AI: choose one route

| Route implemented in the app | Billing |
| --- | --- |
| ChatGPT account through Codex | [ChatGPT Plus is $20/month and includes Codex CLI access](https://learn.chatgpt.com/docs/pricing), subject to subscription limits. Existing eligible subscribers need no separate OpenAI API purchase for this route. Do not assume desktop-only Free/Go access covers this CLI integration. Live web research is currently disabled for this route in Zanzibarr. |
| Claude API key | App default `claude-sonnet-4-6`: [$3 per million input tokens and $15 per million output tokens](https://platform.claude.com/docs/en/about-claude/pricing). API billing is separate from Claude chat subscriptions; Pro/Max is not required. |
| Gemini API key / registered Desktop OAuth | App default `gemini-3.8-flash`: [eligible ordinary inference has a free tier](https://ai.google.dev/gemini-api/docs/pricing). Paid pricing through 31 December 2026 is $0.75/million input and $3.75/million output tokens, including thinking output. Listed rates become $1.50/$7.50 on 1 January 2027. A consumer Google AI subscription is not the app's API billing route. |

### Live internet research

Pricing does not establish permission to use a service. The reviewed
[Gemini API terms](https://ai.google.dev/gemini-api/terms) require adult users,
restrict under-18-directed/likely-accessed clients and specify professional or
business rather than consumer use. Clients made available in the EEA,
Switzerland or UK require Paid Services. Confirm product/use eligibility before
relying on free quotas; BYO credentials do not waive these conditions.

This is opt-in for Claude/Gemini. The app makes a research request followed by a film-card formatting request, so budget for both calls and their context.

- **Claude:** [web search costs $10/1,000 searches](https://platform.claude.com/docs/en/about-claude/pricing), plus model tokens. With the app's maximum three searches per research request, search fees can reach $0.03 per researched reply, before token charges.
- **Gemini:** [Search grounding requires the paid tier](https://ai.google.dev/gemini-api/docs/pricing). The listed shared allowance is 5,000 Search requests/month across Gemini 3+ models, then $14/1,000. A model request may generate multiple billable search queries; one app reply is not necessarily one search. Paid model-token charges still apply during the Search allowance.

## Illustrative monthly budget

These are planning calculations, not checkout quotes or spending caps. They assume the advertised $12.95 provider rate remains applicable and an indexer costing $15–30/year.

| Setup | Monthly equivalent |
| --- | --- |
| Playback + indexer + free metadata, no AI | **$14.20–15.45** |
| Same, plus a new ChatGPT Plus subscription | **$34.20–35.45** |
| Existing compatible Usenet/indexer accounts, free metadata | **$0 additional application/metadata cost** |

For 100 ordinary AI replies/month, assuming 5,000 input and 1,000 output tokens per reply, Claude is approximately **$3**; paid Gemini is approximately **$0.75** at its current temporary rate, or $0 within eligible ordinary-inference free quotas.

For 100 researched replies, assuming 10,000 total input and 2,000 total output tokens per reply across both calls, Claude is approximately **$7–9** including one to three searches per reply. Paid Gemini is approximately **$1.50** with Search queries inside the eligible shared allowance, or **$2.90** if the allowance is exhausted and each reply generates one search query. Longer history, search results, thinking and more searches increase these examples. These figures are assumptions, not measured Zanzibarr bills.

Use provider billing alerts/limits where available. Start with free metadata and one AI route; there is no feature requirement to subscribe to all AI services.
