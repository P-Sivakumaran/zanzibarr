# Claude and Gemini connections

Available in the **1.15.0+16** Windows candidate. Open **Discover films → AI
connections**, or **Settings → MCP & AI → Claude and Gemini AI connections**.

## Claude API

1. Open Claude Console from the setup screen and create an API key.
2. Select **Claude API**, enter the key in the masked field and choose your model
   ID. The initial model is `claude-sonnet-4-6`; enter another supported model
   if needed. API access, availability and quota belong to your Claude account.
3. Choose **Save and use this provider**, return to Discover films and send a
   request. Saving alone does not validate the key or send a prompt.

This uses Claude API access. It does not use a Claude Pro/Max subscription.
[Anthropic authentication guidance](https://code.claude.com/docs/en/legal-and-compliance#authentication-and-credential-use).

## Gemini API key

1. Select **Gemini API → API key**. Open Google AI Studio from the screen.
2. Create an API key in your project and enter it in the masked field. The initial
   model is `gemini-3.8-flash`; the model ID is editable.
3. Save, return to Discover films and send your request. API quota/charges apply
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
5. After the sign-in is saved, return to Discover films and send a request. A
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

Only your prompt and up to ten recent exchanges (bounded to 48,000 characters)
are sent to the selected provider. No library, provider passwords, source paths,
MCP tools or automatic playback are exposed. Switching providers clears the
conversation. Film descriptions and years remain AI suggestions, not verified
availability. Named playlists and Find releases work as described in
[FILM_CHAT.md](FILM_CHAT.md).

## Verification limits

Protocol fixtures and UI tests cover both APIs, real local OAuth callbacks,
PKCE/state/issuer checks, token refresh, failures and cancellation. Live Claude
and Gemini inference and real Google consent require the user's API keys/client
registration and have not been exercised. Zanzibarr 1.15 fixes a reproduced Codex disconnect hang. The diagnostic app reached browser
sign-in, and one live recommendation passed after the profile became connected.
The original startup failure was not conclusively attributed to that hang.
Claude and Gemini do not start Codex when selected.
