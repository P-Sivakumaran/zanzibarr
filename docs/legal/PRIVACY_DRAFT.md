# Privacy notice

**Draft for review — 2026-10-22.draft1**

This notice describes the reviewed local application. Publisher identity, private privacy contact, distribution territories and support retention still need confirmation before publication as a final policy.

> Generated review copy from [JSON source](../../assets/legal/privacy.json). Edit that source and run `python tools/export_legal_documents.py` to refresh both documents.

Viewing state and credentials are primarily stored on your device. Network services still receive requests when used, and GitHub receives an update check at startup. Optional AI sends your prompt and recent conversation. Embedded players can create their own cookies and local browser data. There is no incognito guarantee or automatic deletion after 24 hours.

## 1. Scope and responsibility

This notice covers Treewizard's Zanzibarr fork and describes the reviewed local client's behavior. The legal publisher/controller and a private contact address have not been confirmed. It is not a policy issued on behalf of an indexer, Usenet provider, AI company or other independent service.

The reviewed client has no first-party membership, payment service or central viewing-history synchronization backend. No first-party advertising or automatic analytics/crash-report upload pipeline was identified in the reviewed application code. This is not a promise that your operating system, external software or providers collect no data.

## 2. Information stored on your device

Local settings include provider hosts and account credentials, indexer addresses and API keys, optional metadata and AI credentials, OAuth tokens, integration permissions and bearer tokens. They use operating-system-backed secure storage through the app's storage layer where supported. Local software such as Codex also manages its own account files and credentials.

Viewing records can include titles, local NZB/media paths, selected entries, source identities and download URLs, title/episode matches, timestamps, playback positions, duration and favorites. Saved libraries, tracked shows, playlists, corrections, language choices and playback preferences also persist locally. Source URLs may themselves contain credentials. Local storage and backups must be protected accordingly.

A separate adult catalogue does not isolate all viewing state. Adult playback can use shared history. Titles, searches and viewing patterns can reveal sensitive interests or imply personal characteristics; avoid sharing them unnecessarily, especially from a shared device.

## 3. Playback, search and metadata requests

Your configured indexers receive search terms, structured title/episode identifiers, pagination and NZB download requests with the credentials needed for that source. Your Usenet provider receives connection/account information and article requests needed to retrieve the selected content. Services can see your IP address and connection timing and apply their own logging and retention rules.

When configured, OMDb, TMDB, Wikidata and selected metadata plugins receive the title queries or identifiers needed for matching, ratings, artwork, cast, episodes and other requested details. Identification or enrichment may run automatically for displayed titles after access is configured, not only when you manually search. Optional image loading contacts the relevant image host/CDN, which can see the requested image and network information.

If enabled in your build, adult metadata sources receive the searches and source credentials needed for their API. Experimental hosted-video or performer integrations, where present, send their own search/title/performer requests to the selected provider. These features have separate provider terms and are not private proxies.

## 4. Optional AI and live internet research

When you send a film-chat message, the selected AI service receives your prompt and bounded recent conversation. The current client includes up to ten recent exchanges within its context limit. It does not automatically add your complete viewing history, library, provider passwords or media files to film-chat requests. Information you type yourself is still sent, so do not include credentials or confidential or sensitive personal information.

Live research is a separate, off-by-default choice for supported providers. It sends prompt/context to the research provider, which may derive search queries and use search services before the structured recommendation request. Already issued requests cannot be withdrawn by cancelling the reply. Providers determine their own retention, training, human-review and processing arrangements; free and paid API terms can differ.

In particular, Google's unpaid Gemini API terms can permit use of inputs/outputs to improve products and human review, with regional exceptions. Read the applicable provider's current terms rather than assuming all AI requests are confidential or have zero retention. Provider age, use-purpose and regional eligibility restrictions also apply independently of privacy settings. Local conversation/research state is not the same as provider-side records. Saved recommendation playlists persist separately from chat.

## 5. Embedded players, browser data and external links

Loading an embedded trailer connects to YouTube/Google. Optional provider-owned players connect to their providers when loaded. Embedded pages may request media and other resources and use cookies, cache, identifiers or local browser storage subject to their settings and policies. A privacy-enhanced hostname is not a guarantee of anonymous playback.

On Windows, dedicated WebView2 user-data folders can persist browser data for trailers, research suggestions and optional hosted players. Closing a view or disabling a feature does not necessarily erase these folders. The app does not currently provide a single comprehensive browser-data reset control. Links opened externally use your browser and its existing cookies and account state.

## 6. Updates, casting and assistant access

The Home screen checks the fork's latest release on GitHub at startup, and you can request another check. GitHub and download infrastructure receive your IP address, request timing and normal connection information. The reviewed update request does not include your library or viewing history. The current app has no dedicated switch to disable the startup check.

Casting can advertise/discover devices on your local network and serve selected media through a session-token-protected LAN address. The target device receives playback and media data; its manufacturer or apps may apply their own policies. Keep the network and session token secure.

Local MCP is opt-in, loopback-bound and bearer-authenticated. An authorized client can obtain the library/playback fields and perform the actions allowed by your settings. Returned titles, progress and identifiers can be personal information even when paths and source URLs are removed. External MCP tools and plugins receive the arguments you send or authorize; the assistant/provider may store resulting information. Sharing a bearer token shares authority.

## 7. Files, caches, diagnostics and retention

History, favorites, saved titles, tracked shows, playlists, matches and settings do not have a universal time-based expiry. They remain until removed through the relevant controls, overwritten/evicted by bounded storage, or removed through platform data-management procedures. History is currently capped at 25 records; saved items can still be evicted when limits are reached.

Metadata caches have entry/size limits and source-specific freshness/retry windows. An expired entry is not necessarily erased at the moment it expires. Optional artwork has a bounded memory cache; turning artwork off clears that cache, not every stored metadata record or browser cache.

Streaming and archive processing can create temporary files. Explicit downloads and opened local files can remain in locations you choose; removing a history or playlist entry does not delete the underlying media/NZB file. Normal cleanup can fail after a crash, and secure-storage/OS/browser backups can outlive an uninstall.

Playback Doctor and native traces are bounded local observations; their report schema excludes titles, paths, URLs, credentials, media and article identifiers. Reports are not automatically uploaded. Copying or sending a report is your separate action. Optional debug modes, external components and OS crash/diagnostic records can contain additional technical details; inspect shared material. Closing the app does not erase anything you previously copied or sent.

## 8. What the maintainer may receive

Normal local use does not give the maintainer remote access to your saved library or credentials. If you contact the project, submit a contribution or send diagnostics, the maintainer and the communication platform can receive your account/contact details, message and attachments. Public posts can be copied, indexed or retained by others.

Support-contact channels, access controls, retention periods and deletion procedures need to be confirmed before a final policy is published. No claim is made that support correspondence is deleted within 24 hours. Do not send API keys, authentication tokens, private source URLs, copyrighted media, illegal content or unnecessary identity documents.

## 9. Your controls and requests

Use the relevant library, history, playlist, watchlist and settings controls to remove saved entries, clear credentials where supported, disconnect accounts and disable optional services. Revoke credentials or sessions with the issuing provider as well when appropriate. Removing a local record does not retract earlier requests, delete a provider's records or erase your own downloaded files.

There is currently no one-button erasure of all app, secure-storage, Codex, browser-profile, download and backup data. Operating-system app-data controls and provider account controls may be needed. Check their effects before deleting files or reinstalling; the app cannot guarantee that uninstalling removes secure-storage items or backups.

A final private contact channel is still required for requests about personal information actually held by the maintainer, including access, correction, deletion and privacy complaints. Rights and response requirements depend on the law that applies. For independent providers' records, use their own request channels. If Australian privacy law applies, the OAIC may provide an external complaint route after the applicable process.

## 10. Processing locations, children and changes

Configured providers, GitHub, AI services, content hosts and communication platforms may process data overseas, including in the United States and other locations described in their policies. No Australia-only storage guarantee is made. The publisher must confirm the actual recipients, relevant countries and any required transfer arrangements before finalizing the policy for its distribution model.

Adult features are for adults only; the application does not currently collect identity documents to verify age. That is not a claim that an age declaration meets applicable age-assurance law. If the service becomes directed at children or adds age verification, cloud accounts, payments, analytics or synchronization, reassess the data flows and explain the changes before collection.

This notice is versioned and available offline. It does not claim worldwide legal compliance or waive your statutory rights. Mandatory notices, legal grounds, contacts and safeguards must be finalized for the publisher's actual circumstances.
