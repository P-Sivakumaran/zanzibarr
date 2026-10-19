# Film & TV chat and playlists

Available in the **1.22.0+23** Windows candidate under **Home → Ask AI for ideas**,
or **Settings → MCP & plugins → Discover films & TV: chat and playlists**.

## Choose an assistant

Open **AI connections** in Discover films & TV, or **Settings → AI connections**. Select Claude API, Gemini API or ChatGPT through
Codex. Claude uses your API key. Gemini accepts an API key or registered Google
Desktop OAuth client. See [Claude and Gemini setup](AI_CONNECTIONS.md). Each
provider uses the same recommendation cards, playlist saving and release search.
Changing provider clears the current conversation; saved playlists remain.

## Connect through Codex

1. Install the current official Codex desktop app or CLI on the same computer.
2. Open Discover films & TV using the sparkle button next to Home settings.
   Zanzibarr checks the saved path, the usual Windows Codex installation and PATH. Open **Advanced connection settings** (the tune icon) to change the path.
3. Choose **Sign in with ChatGPT**, complete the browser sign-in and return to
   Zanzibarr. The connection card should say **ChatGPT ? Connected**.
4. Enter a request and press **Send**. For example: “Suggest five slow-burn
   crime films from the 1970s. Give me a spoiler-free description of each.”
5. Follow up with “Make the list less violent” or “Put these in viewing order”.

The verified Codex path on Treewizard's Windows computer is:

    C:\Users\prash\AppData\Local\Programs\OpenAI\Codex\bin\codex.exe

The local executable is a prerequisite; it is not bundled in the installer.
Codex manages browser sign-in and keyring credentials in Zanzibarr's separate
profile. Signing into another Codex client does not sign into this profile.
No API key, MCP server or metadata plugin is needed for this chat flow.
Subscription access and usage limits still apply. The installed Codex selects
its default model; Zanzibarr does not hard-code a model entitlement.

If connection fails, use the reported startup step to check the executable path,
local profile access or Codex initialization. Update the official Codex installation
if needed. Version 1.15 also fixes a hang when disconnecting a quiet Codex process. If a reply fails, check your connection and subscription usage,
then reconnect and retry. Failed and stopped requests retain the message draft.
Stopping a reply closes the dedicated app-server process; reconnecting uses
the account already stored by Codex. An account-status check sends no model prompt.

## Save and use a playlist

Choose **Add to playlist** on a title, or **Save these picks as a playlist** for
the whole response. Create a named list or append to an existing one. Repeated
type/title/year combinations are skipped when appending. Up to 20 playlists with 100 titles
each are stored on this device using OS secure storage.

Open **Playlists** to rename a list, move titles up/down, remove titles or delete
the list. **Find releases** opens the existing indexer search using the title
and year for films, or the TV category and show title for TV recommendations. Configure an indexer if needed, choose a release, then play it using
the normal player. These are ordered viewing lists; automatic playback of the
next film is not included. AI suggestions do not prove indexer availability.
AI-supplied IDs are never used to constrain release search.

Playlist writes update the visible list only after storage succeeds. Failed
saves retain the current list or name draft. If saved data cannot be loaded,
editing is disabled and Retry is offered, preserving the stored value.

## Data and scope

Pressing Send supplies the message and up to ten recent exchanges (bounded to
48,000 characters of context) to the selected AI provider. The app does not
attach indexer credentials, playback history or local file paths. Conversation
state stays in memory and is cleared when leaving the screen; saved playlists
remain on this device. Codex threads are ephemeral and unsubscribed after each
reply. Provider-side data handling follows the selected provider's terms and
the user's account settings.

Replies contain at most twelve film or TV cards with descriptions and reasons. They
are AI-generated suggestions and may be inaccurate. No current web lookup is
performed. Codex chat uses read-only sandbox settings, disables shell tools, web
search, apps, remote plugins and delegation, and rejects server tool/approval
requests. Claude and Gemini receive no tools. Chat does not automatically run
external MCP tools or control playback.

Claude's external MCP integration remains available; in-app Claude subscription
inference is not included. Interface copy falls back to English; prompts can
request replies in another language. The Codex option requires desktop Codex;
Claude and Gemini API-key options work independently. Mobile/TV inference and
physical remote behavior are not verified.

Protocol checked against the installed Codex 0.162.1 schema and the official
[app-server documentation](https://learn.chatgpt.com/docs/app-server) and
[configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference).
On Windows, the diagnostic app reached browser sign-in; Codex subsequently
reported the profile connected to ChatGPT. One live film recommendation passed
through the real chat service and reply validator. Other platforms and broader
model/account combinations remain unverified.

## TV shows and keyboard controls (1.17)

Ask for films, TV shows, miniseries or a mixture. Each card labels its type.
TV recommendations use the first release year and open TV release search;
films retain their title/year search. Existing saved film playlists still load,
and a new playlist can mix films and TV shows. Unknown or missing types in new
AI replies are rejected rather than silently searched as a film.

The composer stays visible on larger screens and scrolls with content in short
windows or at large text sizes. New replies open at their beginning. After a
keyboard send, focus returns to the composer when the chat is still active.

| Shortcut | Action |
|---|---|
| Enter / Ctrl+Enter / Cmd+Enter | Send from the composer |
| Shift+Enter | New line |
| Escape | Stop a reply or account connection check; keep the draft |
| Ctrl/Cmd+N | New chat; keep the current draft |
| Ctrl/Cmd+L | Switch to Chat and focus the composer |
| Ctrl/Cmd+1 / 2 | Chat / Playlists |
| Ctrl/Cmd+, | AI connection settings |
| Ctrl/Cmd+/ or F1 | Keyboard help |
| Ctrl/Cmd+A / C / X / V | Native select all / copy / cut / paste |
| Ctrl/Cmd+Z | Undo |
| Ctrl/Cmd+Shift+Z | Redo; Ctrl+Y is also available in the Windows/Linux composer |

Enter is left to the input method while a composition is active. Shortcuts do
not send from the executable-path field or operate over a modal dialog. Normal
Tab and Shift+Tab traversal remains available. These are ordered title lists;
automatic episode selection, playback or next-episode queues are not included.


## Playlists and artwork

Open **Playlists** directly from Home or My library to view saved lists without
starting the AI connection. Configured OMDb access automatically identifies
recommendations, playlist covers and expanded entries. Posters respect **Load
artwork** in Settings. Use **Rematch title** to correct an identification. No
IDs supplied by the model are trusted. Resolved titles drive release search;
unresolved suggestions remain editable searches. Saved playlists still work
without metadata access. Review totals appear only when supplied by the provider;
IMDb counts are user votes, while RT/Metacritic counts are critic reviews.
