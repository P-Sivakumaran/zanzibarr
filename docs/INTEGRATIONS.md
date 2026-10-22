# Zanzibarr integrations

Available in the 1.20 candidate under **Settings → MCP & plugins**.
The labelled **MCP & AI** action in provider/indexer forms still opens this page.
AI provider setup has its own **Settings → AI connections** entry. On the MCP
page, endpoint/token details and advanced Codex account controls are collapsed
until needed. Everything is optional; local MCP access is off by default.
New integration copy is English in all locales; the screen discloses this.

## Assistants controlling Zanzibarr

Enable local MCP access while the app is open. It listens only on
http://127.0.0.1:18472/mcp and requires its generated bearer token. Copy the
endpoint and secret token separately from Integrations. Rotating the token
revokes the old token. Closing Zanzibarr stops the endpoint.

| Tool | Permission / behavior |
|---|---|
| library_list | Read media titles, IDs and progress; no local paths or source URLs |
| playback_status | Read current playing/position/duration state |
| search_releases | Separate opt-in; enabled indexers only, 25 requested results per source; no download |
| playback_pause / playback_resume / playback_seek | Separate opt-in; ready local player only |

No tool installs software, reads credentials, opens arbitrary files, downloads
NZBs or starts new media. Cast playback control is rejected. Tool permissions
are rechecked on every invocation and immediately before player effects.
Casting/media listeners remain independent.

Local tool calls expire after 30 seconds and support
[`notifications/cancelled`](https://modelcontextprotocol.io/specification/2025-11-25/basic/utilities/cancellation).
Cancellation, endpoint shutdown and configuration/token changes invalidate the
call context. A deferred player handler must check this context and the current
permission/player immediately before acting. Already issued native commands
cannot be undone; read-only native/provider work may finish after cancellation,
but its result is discarded. This is cooperative cancellation, not forced
termination of arbitrary asynchronous work.

The eight-active-HTTP-request limit is unchanged. At saturation, even a
cancellation request can receive 503; the local deadline still invalidates each
call. Request IDs are scoped to the endpoint's existing bearer authority.
Assistants sharing a bearer share authority and must use distinct active IDs;
there is no per-client token isolation. Unknown or malformed cancellations are
ignored. Initialize cannot be cancelled. A cancelled call closes with HTTP 202
without a JSON-RPC result. A fixed-label in-memory outcome audit retains at most
128 entries, without arguments, IDs, provider content or raw failures.

Each server also permits at most eight underlying tool operations. Cancelled or
expired operations retain their slot until the callback actually finishes, even
though the HTTP response returns promptly. This prevents repeated cancellation
from accumulating unbounded read-only native work. This is a per-server bound;
reconfiguring the endpoint can overlap old read-only work with its replacement.

For an HTTP MCP client, source the bearer token from an environment variable.
Codex configuration:

    [mcp_servers.zanzibarr]
    url = "http://127.0.0.1:18472/mcp"
    bearer_token_env_var = "ZANZIBARR_MCP_TOKEN"

Claude Code project MCP configuration:

    {
      "mcpServers": {
        "zanzibarr": {
          "type": "http",
          "url": "http://127.0.0.1:18472/mcp",
          "headers": {"Authorization": "Bearer ${ZANZIBARR_MCP_TOKEN}"}
        }
      }
    }

Supply the variable through a secret store or masked prompt when launching the
client. Do not put the real token in commands, logs or ordinary configuration
files. These examples contain placeholders, not credentials. Your assistant
retains its own AI account sign-in; MCP does not transfer that account.

Clients requiring stdio can run **tools/zanzibarr_mcp_bridge.py** with Python
3.10+. The Windows package includes it under integrations/. Give the bridge
ZANZIBARR_MCP_TOKEN through the environment; optional ZANZIBARR_MCP_PORT
changes the local port. It writes only MCP responses to stdout and never puts
the access token in process arguments. Python is not bundled or installed by
Zanzibarr. Direct HTTP clients do not need the bridge.

## External MCP connections

Add a named HTTPS endpoint (loopback HTTP is allowed) and optional bearer token.
Settings and tokens are stored in OS secure storage. URL credentials, query
strings and redirects are rejected. Open a connection to discover tools,
inspect its schema, supply JSON arguments and explicitly run a selected tool.
This can send data or change the remote service: choose trusted servers.
Output is untrusted provider content and is never executed. Connections do not
poll in the background. Requests have deadlines and body/catalog limits.

The initial client supports Streamable HTTP JSON and SSE responses with protocol
versions 2025-11-25, 2025-06-18 and 2025-03-26. Interactive elicitation, resumable
SSE, remote OAuth and stdio child-server hosting are not implemented. Servers
requiring those capabilities need a compatible adapter or client.

## Provider plugins

Plugins are external MCP services rather than native libraries loaded into the
player. Mark a connection **Use as a metadata provider plugin**. Title lookup
then offers OMDb and your configured providers. Choosing a plugin sends queries
and IMDb IDs to that plugin and does not require an OMDb key.

Initial metadata contract:

- metadata_search arguments: query (string), kind (movie or series), page (int).
  Return Search (array of at most 100 entries) and hasMore (bool).
- metadata_details argument: imdbId. Return a title object or {"found":false}.
- Return objects in MCP structuredContent or JSON in a text content block.
- Title fields: imdbID, Title, Year, Type (movie or series), optional Plot, Genre,
  Runtime and Ratings. Ratings entries use Source and Value; supported sources
  follow the existing metadata UI. The UI labels the plugin as the supplier.
- Details must preserve the requested IMDb identity. Invalid responses fail
  visibly rather than substituting a different title or provider.

Example fictional provider response:

    {"Search":[{"imdbID":"tt0133093","Title":"The Matrix","Year":"1999","Type":"movie"}],"hasMore":false}

Other tools can be called in the tool browser. Subtitle-provider hooks,
downloadable plugin bundles and a marketplace are not included.

## Claude and Gemini film chat

Choose **AI providers & accounts** on the MCP page, or **AI connections** in Settings. This
opens secure API-key setup for both providers and Google desktop OAuth setup
for Gemini. [Setup instructions](AI_CONNECTIONS.md). Chat is under Discover
films and reuses the existing playlists. These API options use provider API
quota; they do not import subscription credentials.

## Subscription accounts

**Codex:** expand **Advanced ChatGPT connection**, enter the path to an up-to-date official Codex executable and choose
Sign in with ChatGPT through Codex. App-server owns OAuth, refresh, cancellation,
sign-out and keyring storage. A separate Codex home lives under Zanzibarr's
application-support directory. Zanzibarr requests keyring credential storage and
never reads or exports auth.json or account tokens. Leaving Integrations stops
the account-management child process. **Home → Discover films** uses this same
Zanzibarr profile for in-app film chat and playlists. External Codex clients
keep their own account configuration. See [film chat setup](FILM_CHAT.md).

**Claude:** use Claude Code/Desktop's own subscription sign-in and connect over
MCP. Anthropic does not permit third-party products to offer Claude.ai
subscription login or intermediate those credentials. An in-app Claude inference
integration requires an API key or supported cloud provider. This candidate
adds in-app Claude API inference with a user-provided API key;
it does not import Claude subscription tokens.

Official references checked 2026-10-16:

- [MCP transports](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports)
- [Codex MCP configuration](https://learn.chatgpt.com/docs/extend/mcp)
- [Codex app-server accounts](https://learn.chatgpt.com/docs/app-server)
- [Claude Code MCP configuration](https://code.claude.com/docs/en/mcp)
- [Anthropic credential guidance](https://code.claude.com/docs/en/legal-and-compliance#authentication-and-credential-use)

Local tests cover protocol boundaries, permission revocation, failed storage,
metadata identity and managed-auth events. A signed-out handshake passed with
Codex CLI 0.162.1. The Windows diagnostic app reached browser sign-in. The connected Codex profile
and one real film recommendation were subsequently verified. Claude/Gemini live
account access and inference remain unverified.
Live provider compatibility and physical playback/remote behavior remain to be
checked. See dated integration verification notes for the gate and build.


### Optional rating-count context

Each Ratings entry may add an exact positive integer Count beside Source and
Value. Internet Movie Database counts represent user votes; Rotten Tomatoes
and Metacritic counts represent critic reviews. For example:

```json
{"Ratings":[{"Source":"Rotten Tomatoes","Value":"95%","Count":240}]}
```

Old payloads remain valid. Counts are optional; omit them when unavailable.
Do not send rounded abbreviations or reuse a different source's count. Zanzibarr
validates, stores and displays the counts with their source's original scale.


### Optional review gap filling (1.22)

Settings > Artwork & ratings > Cast, topics & review context can select an
existing metadata-enabled MCP connection for lazy title-page enrichment. The
connection must return the confirmed title ID and type plus Ratings rows with
source-specific score and exact Count. The app replaces score/count observations
together and shows the selected connection name as attribution. Source scales
and counts are validated; missing/invalid fields preserve the prior observation.

The app does not reinterpret arbitrary votes fields or bundle a licensed Fabric
bridge. Provider authors must map documented critic-review vs user-vote meanings
and ensure their data access/redistribution terms allow the intended use. Cached
successful/absent responses expire after 24 hours; failures use a shorter retry
window. No OMDb key is sent to the MCP review provider.
