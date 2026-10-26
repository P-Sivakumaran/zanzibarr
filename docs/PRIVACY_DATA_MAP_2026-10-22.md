# Privacy data map and implementation decisions

Reviewed 22 October 2026 against `d8f4ac0` and preserved working files. Internal
assessment, not a compliance certificate. Read with the
[legal/regulatory assessment](LEGAL_REGULATORY_ASSESSMENT_2026-10-22.md).
The operator, domicile, distribution territories and confidential contact remain
unconfirmed. Australia is an assessment assumption, not a selected legal forum.

## Verified client behavior

| Flow | Information / destination | Retention and controls supported by code |
| --- | --- | --- |
| Provider / indexer configuration | Hosts, NNTP account, API keys and source IDs in OS-backed secure storage; authorized requests go directly to the configured source. | Persistent until changed/removed; not a 24-hour session. Sources independently see IPs, searches/article requests and credentials needed for that source. `lib/settings/{provider_settings,indexer_settings}.dart`, Rust search/HTTP/NNTP. |
| Playback state | Titles, paths, entry IDs, episode/title matches, source IDs/URLs, positions, timestamps and favorites. A source URL can contain an API key. | Secure-storage history is bounded to 25 records with eviction; per-entry removal does not delete files. Adult playback uses shared history. `lib/player/playback_history.dart`. |
| Library / playlists / tracking | Canonical metadata, selected identities, saved recommendations, playlists and tracked shows. | Stored locally with entry/size limits; not automatically erased on exit. Separate removal controls. `lib/metadata/title_library.dart`, `title_resolver.dart`, `lib/chat/film_playlist.dart`, `lib/player/watchlist.dart`, `lib/adult/adult_catalog.dart`. |
| Metadata / artwork | Title queries/identifiers to configured OMDb/TMDB/Wikidata/MCP providers; public image requests reveal requested image and IP to its host. Identification can be automatic after configuration. | Persistent metadata caches have freshness windows, entry/size limits and retry windows; expiry is not an immediate-deletion guarantee. Artwork memory cache is bounded and cleared when artwork is disabled. `lib/metadata/metadata_enrichment.dart`, `metadata_service.dart`, `artwork.dart`. |
| AI / research | Explicit prompt plus at most ten recent exchanges, bounded by the chat context size; research shares bounded context with its provider and can derive search queries. | Client chat/research is in memory, while saved playlists persist. Provider records differ. Stop cannot retract issued calls. Codex requests ephemeral threads but the external CLI/account has its own files and policy. `lib/chat/{film_chat,api_film_chat,film_research}.dart`, `lib/integrations/codex_account.dart`. |
| Trailers / webviews | YouTube requests after Load trailer; browser cookies/storage/resources depend on the provider. Google research suggestions use a restricted view. | Windows user-data profiles persist in app support folders; closing a view does not clear them. No comprehensive browser-profile wipe UI was found. `lib/metadata/trailer_panel.dart`, `lib/chat/research_suggestions.dart`. |
| Updates | Automatic GitHub latest-release check at Home startup; installer/download requests after user action. | No history/title payload in the reviewed update check; GitHub can observe request/IP/timing. No dedicated startup-check opt-out exists. `lib/main.dart`, `lib/update/update_service.dart`, `windows_update.dart`. |
| Casting / MCP | LAN device discovery and selected media to a cast target; opt-in local bearer clients receive permitted library/playback fields. External tools receive authorized arguments. | Cast capability is per session; endpoints are separate. Redacting paths does not make titles/identifiers anonymous. Assistant/provider retention is independent. `lib/cast/`, `lib/integrations/`, Rust server. |
| Diagnostics / media files | Typed local Doctor/native event traces; explicit copy/share. NZBs, temporary archive/media files and chosen downloads live outside secure key-value storage. | Traces are bounded and not auto-uploaded. Copies, explicit downloads, OS logs/backups and crash leftovers can persist. Debug probe can print track labels. Do not promise secure erase or that all files are encrypted. `lib/player/playback_diagnostics.dart`, `player_screen.dart`, native telemetry/download modules. |
| Experimental hosted catalog | Optional source requests and persistent saved/recent/collection data, plus provider player browser state, if that WIP is enabled in a build. | `lib/catalog/` remains unfinished/uncommitted at this baseline. It is not silently certified by these pages. Windows has a separate persistent hosted-player profile. |
| Support / repository | Identity, messages and attachments only when someone contacts/contributes to the project; host also processes access data. | Actual private channel, access, retention, deletion and incident arrangements are unconfirmed. Public posts can be copied/indexed. No blanket 24-hour deletion claim. |

No first-party membership/payment backend, central library sync, advertising SDK
or automatic first-party analytics/crash-upload pipeline was identified in the
reviewed client. This is a bounded source observation, not proof that every OS,
native dependency, CLI or external provider is free of telemetry. Network reach
and local persistence mean “no data is collected” would be misleading.

## Applicable privacy issues

1. **Australian coverage must be established.** The small-business exemption
   has exceptions and is not interchangeable with “free/open-source/personal
   project.” Determine who possesses or controls each record, including support
   correspondence. The APPs do not automatically apply to every local record
   merely because software stores it. [OAIC small-business scope](https://www.oaic.gov.au/privacy/privacy-guidance-for-organisations-and-government-agencies/organisations/small-business).
2. **An honest layered notice is preferable to a copied policy.** Where APP 1
   applies, cover kinds of information, collection/storage, purposes, access and
   correction, complaints, and overseas disclosure. APP 5 notices and actual
   consent controls can be needed in addition to a policy. The current hub is an
   offline summary linked to full drafts, with an English fallback disclosure.
   [OAIC policy guide](https://www.oaic.gov.au/privacy/privacy-guidance-for-organisations-and-government-agencies/more-guidance/guide-to-developing-an-app-privacy-policy),
   [APP 1](https://www.oaic.gov.au/privacy/australian-privacy-principles/australian-privacy-principles-guidelines/chapter-1-app-1-open-and-transparent-management-of-personal-information).
3. **Sensitive interests deserve stronger controls.** Linked viewing/search
   data could reveal sensitive information; it is not automatically anonymous
   because there is no first-party username. OAIC identifies sexual orientation
   or practices as sensitive information; do not infer those characteristics
   from a title as established fact. Assess necessary collection, explicit
   consent where required and safe shared-device behavior. Do not add identity
   document/biometric collection casually for age checks.
   [OAIC personal/sensitive information](https://www.oaic.gov.au/privacy/your-privacy-rights/your-personal-information/what-is-personal-information),
   [APP 3](https://www.oaic.gov.au/privacy/australian-privacy-principles/australian-privacy-principles-guidelines/chapter-3-app-3-collection-of-solicited-personal-information).
4. **Security and deletion are operations, not clauses.** For covered records,
   APP 11 requires reasonable protection and destruction/de-identification when
   no longer needed, subject to exceptions. Establish separate retention for
   support, backups, browser profiles and credentials. Uninstall is not proof of
   erasure; a future all-data reset must be explicit and must not delete chosen
   media silently. [APP 11](https://www.oaic.gov.au/privacy/australian-privacy-principles/australian-privacy-principles-guidelines/chapter-11-app-11-security-of-personal-information).
5. **Breach response requires a real contact and process.** If covered by the
   NDB scheme, eligible breaches likely to cause serious harm can require
   assessment/notification. Do not promise a universal timetable or notify the
   user of imaginary incidents. Private support channels and an incident owner
   must be chosen. Australia's serious-invasion privacy tort commenced on
   10 June 2025; do not assume an APP exemption resolves every privacy risk.
   [OAIC NDB guidance](https://www.oaic.gov.au/privacy/notifiable-data-breaches/preventing-preparing-for-and-responding-to-data-breaches/data-breach-preparation-and-response/part-4-notifiable-data-breach-ndb-scheme),
   [privacy tort](https://www.oaic.gov.au/privacy/your-privacy-rights/more-privacy-rights/statutory-tort-for-serious-invasions-of-privacy).
6. **Overseas use requires a role/scope assessment.** Direct-to-provider
   requests do not establish who is controller/processor for every activity.
   Confirm actual recipients/countries and APP 8 obligations where applicable.
   GDPR scope can extend to offering services to or monitoring people in the EU;
   simple global repository availability is not the entire legal test. If in
   scope, assess legal bases, sensitive-data conditions, notices, data rights,
   transfers and any representative/processor requirements. Do not manufacture
   a GDPR-compliant badge or worldwide compliance statement.
   [APP 8](https://www.oaic.gov.au/privacy/australian-privacy-principles/australian-privacy-principles-guidelines/chapter-8-app-8-cross-border-disclosure-of-personal-information),
   [EDPB territorial-scope guidance](https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-32018-territorial-scope-gdpr-article-3-version_en).

## Independent provider policies

Google's Gemini terms distinguish unpaid/paid data use, human review and
regional exceptions; a free API key is not a confidentiality promise. Provider
settings, model/endpoint and separate contractual arrangements can affect
retention. Do not hard-code a universal “30 days” across AI routes. The Codex
consumer account route and commercial API routes are different relationships.
Gemini additionally has adult/client-audience, professional/business-purpose
and regional Paid Services restrictions; verify product fit separately from
privacy or free-quota eligibility. The EEA/Swiss/UK data-use exception does not
waive the terms' regional Paid Services requirement for API clients.
[Gemini API terms](https://ai.google.dev/gemini-api/terms),
[Anthropic API retention](https://platform.claude.com/docs/en/manage-claude/api-and-data-retention),
[OpenAI privacy and regional policies](https://openai.com/policies/privacy-policy/).

GitHub and YouTube/browser providers have their own logs, cookies, account data
and rights processes. A privacy-enhanced embed does not erase normal network
disclosure. Link users to the relevant independent notices and preserve actual
load/permission controls rather than claiming the application accepts the
provider's terms for them.
[GitHub privacy](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement),
[Google privacy](https://policies.google.com/privacy).

## Implementation and remaining decisions

- `assets/legal/{terms,privacy}.json` are single-source, versioned draft texts.
  `lib/settings/legal_screen.dart` makes them available offline through
  Settings → Terms & privacy, with contents navigation and registered Flutter
  package notices, TMDB attribution and user-selected provider-policy links.
  Readable generated copies live at `docs/legal/{TERMS,PRIVACY}_DRAFT.md`; run
  `python tools/export_legal_documents.py --check` to verify they match the assets.
  No acceptance tracking, new data collection, automatic provider calls
  or destructive reset was added.
- Publisher identity, private legal/privacy/abuse contact and distribution
  targets remain required owner input. Do not substitute an upstream address,
  NZBgeek email, personal details from memory, invented entity or dormant inbox.
- Confirm a practical complaint/request workflow, support-retention schedule,
  actual recipient countries, incident response and applicable legal grounds.
- Resolve root software permissions and native binary licences and assess adult
  integration/platform/provider obligations in the companion legal report.
- Keep public drafts marked as drafts; owner decisions and qualified legal
  review are needed before adopting them as final terms or claiming compliance.
  No publication, release, installation or interruption of the active player
  is part of this change.
