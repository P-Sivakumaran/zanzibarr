# Claude and Gemini connections

Available in the **1.22.0+23** Windows candidate. Open **Settings → AI
connections**, or **AI connections** from film & TV chat. Model IDs are under
**Advanced model settings**. The Save action stays visible while scrolling;
Back protects unsaved changes with Keep editing / Discard changes.

## Claude API

1. Open Claude Console from the setup screen and create an API key.
2. Select **Claude API**, enter the key in the masked field and use Advanced model settings
   to change the model ID when needed. The initial model is `claude-sonnet-4-6`; enter another supported model
   if needed. API access, availability and quota belong to your Claude account.
3. Choose **Save and use this provider**, return to Discover films & TV and send a
   request. Saving alone does not validate the key or send a prompt.

This uses Claude API access. It does not use a Claude Pro/Max subscription.
[Anthropic authentication guidance](https://code.claude.com/docs/en/legal-and-compliance#authentication-and-credential-use).

## Gemini API key

1. Select **Gemini API → API key**. Open Google AI Studio from the screen.
2. Create an API key in your project and enter it in the masked field. The initial
   model is `gemini-3.8-flash`; the model ID is editable.
3. Save, return to Discover films & TV and send your request. API quota/charges apply
   to your project. Google AI Pro/Ultra subscription credentials are not used.

## Gemini Google sign-in

Google OAuth needs a client registered for this application. No shared client
ID or secret is bundled with Zanzibarr. The API-key option works independently.

1. Create/select your Google Cloud project and enable the **Generative Language
   API**. Configure API access and any required project billing/permissions.
2. In **Google Auth Platform**, configure Branding and Audience. While the app is
   in testing, add your Google account under Test users.
3. Create an OAuth client with application type **Desktop app**. Enter its client
   ID, supplied desktop client secret, and project ID in Zanzibarr. Do not use
   a web, Android or iOS OAuth client for this desktop flow.
4. Select **Google sign-in (OAuth)** and click **Sign in with Google**. Complete
   consent in your browser and return to Zanzibarr. Consent requests the
   `cloud-platform` and `generative-language.retriever` scopes documented in
   Google's Gemini OAuth guide.
5. After the sign-in is saved, return to Discover films & TV and send a request. A
   completed model response is the check of actual API/model access.

[Google Gemini OAuth guide](https://ai.google.dev/gemini-api/docs/oauth) and
[desktop OAuth requirements](https://developers.google.com/identity/protocols/oauth2/native-app).
Public distribution may require Google consent-screen verification. Test-mode
refresh-token limits and organization restrictions can require reauthentication.
Google OAuth currently uses a desktop loopback callback; mobile users can use
API keys. Only Windows builds are verified locally.

## Credentials, recovery and data

Keys, client details and access/refresh tokens use OS secure storage. Secrets
and tokens are not written to logs, source files or process arguments. API keys
and tokens are excluded from URLs; the browser authorization URL contains the
public OAuth client ID, state and PKCE challenge. Clear a key and
save to remove it. **Disconnect Google on this device** deletes the saved local
tokens; revoke the application separately in your Google Account if desired.
Changing the client or project clears the previous Google tokens.

The browser flow binds only to loopback on a temporary port, validates state
and optional issuer, uses PKCE S256, and closes on completion/cancel/timeout.
Refresh is persisted before a model request; failed storage prevents that send.
Failed connection saves preserve the form draft and existing stored settings.
Requests use fixed HTTPS endpoints, header credentials, no redirects, bounded
response sizes and deadlines. Stop cancels the active request. Error messages
do not include raw provider responses or credentials.

Without Live research, your prompt and up to ten recent exchanges (bounded to 48,000 characters)
are sent to the selected provider. No library, provider passwords, source paths,
MCP tools or automatic playback are exposed. Switching providers clears the
conversation. Film descriptions and years remain AI suggestions, not verified
availability. Named playlists and Find releases work as described in
[FILM_CHAT.md](FILM_CHAT.md).

## Optional Live research

In Settings -> AI connections, select Claude or Gemini, enable **Live research**
and Save. It defaults off, including existing saved connections. It is ignored
for ChatGPT through Codex, whose web and other tools remain disabled.

An enabled reply makes one extra research request. The model decides whether
current web evidence is useful; ordinary recommendations may need no search.
Claude uses the basic server web-search tool with a hard maximum of three
searches. Gemini uses Google Search grounding in one request; this endpoint does
not expose the same per-query cap, and Google controls the query count. Both
add API usage and can add search charges to the selected provider account.
No different provider or separate search key is silently selected.

The research request receives the same bounded prompt/recent-chat context as
film chat. Providers may derive search queries from it. No library, indexer
credentials, paths, MCP tools or player controls are added. Public web text is
untrusted data, not authority to run commands or acquire permissions. The
research phase has a 45-second deadline and the existing 512 KiB response bound;
there is no automatic paid retry or continuation loop.

Research is separate from the structured film-card request: Claude citations
are incompatible with strict JSON output. Only provider citation metadata
becomes clickable source links, with at most 12 distinct sources. Uncited prose
is discarded from the factual research context. Search failure stops the reply
and keeps the draft; absence of citations is labelled unverified. The app cannot
guarantee that a cited source is correct or that a catalogue is complete.

Google's original research text is shown with its Search Suggestions markup,
separate from film cards. A supported native web view is checked before a paid
Gemini research request (WebView2 Runtime on Windows; Linux is unsupported).
The suggestion view disables JavaScript and local-file access and applies a
restrictive content policy (only inline styling/data images and Google static
branding images are allowed). It has no API headers or host command bridge.
Only user-initiated, validated HTTPS links open externally. If attribution cannot
load, the researched reply is discarded and its prompt is restored when safe.

Research notes/sources stay in the in-memory conversation and are not added to
playlist storage, telemetry or a persistent cache. Film descriptions remain
spoiler-free and evergreen; dated catalogue claims belong in the reply message.
Criterion edition dates, film original years, Collection releases and Channel
availability are kept distinct in the research instructions. Research checks
authorization and configuration between phases and before accepting a result;
Stop cancels the active HTTP operation. Already issued API usage cannot be undone.

Official contracts checked 2026-10-21:

- [Claude web search](https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-search-tool)
- [Claude structured-output compatibility](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)
- [Gemini Generate Content grounding](https://ai.google.dev/gemini-api/docs/generate-content/google-search)
- [Google grounding display requirements](https://ai.google.dev/gemini-api/terms#grounding-with-google-search)

## Verification limits

Protocol fixtures and UI tests cover both APIs, real local OAuth callbacks,
PKCE/state/issuer checks, token refresh, failures and cancellation. Live Claude
and Gemini inference and real Google consent require the user's API keys/client
registration and have not been exercised. Zanzibarr 1.15 fixes a reproduced Codex disconnect hang. The diagnostic app reached browser
sign-in, and one live recommendation passed after the profile became connected.
The original startup failure was not conclusively attributed to that hang.
Claude and Gemini do not start Codex when selected.
