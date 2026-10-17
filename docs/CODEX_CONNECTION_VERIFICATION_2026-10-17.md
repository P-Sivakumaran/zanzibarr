# Codex connection diagnosis — 2026-10-17

Baseline HEAD: `386c5e2c2f95f0edb6bf3b4537b3c39ebb92cca7`, branch
`kepler/fix-zanzibar-icon`, plus existing uncommitted features. Candidate
**1.15.0+16**. No commit, push, tag or publication.

## Observed failure and reproduction

The installed **1.14.0+15** executable and Dart payload matched the packaged
SHA256 values. The running app selected ChatGPT through Codex and showed
“Could not connect to Codex. Choose an up-to-date official Codex executable.”
Clicking Sign in reproduced the same message before browser login. The Claude
and Gemini options were not the selected provider on this screen.

The isolated account-controller probe timed out. Instrumentation restricted to
stage names showed process startup, initialization and account read succeeded;
account disconnect then timed out after five seconds. Direct RPC cleanup could
succeed when cancellation arrived before the decoder resumed awaiting stdout.
Using the exact installed executable and native profile paths did not cause
startup to fail. No credential files or tokens were opened or logged.

The offline regression uses the production byte-stream decoder. After one RPC
reply it lets the decoder await the next quiet pipe chunk, then disconnects.
Before the fix it times out after one second. With process/pipe closure before
decoder cancellation it completes. The real account-controller probe then
passed startup and cleanup against Zanzibarr's own profile.

## Change

Close the Codex process/pipe before awaiting decoder cancellation. This removes
the circular wait in which cancellation awaited another stdout chunk while
process shutdown was scheduled only after cancellation. Preserve cleanup when
closing throws. Expose the decoder only as a visible-for-testing seam.

Startup errors now distinguish process launch, local profile access, protocol
initialization and account lookup. Process errors expose only the OS error
number; filesystem paths, command arguments and raw exception messages are
excluded. A regression verifies that test credential strings never appear.

## Native observations and limits

A bounded native Flutter probe with real Windows plugins passed support-path
lookup, real Codex startup/account read and cleanup. The full diagnostic app
also reached browser sign-in through its actual Discover films button. No
browser account choice, authentication dialog or token export was automated.

The diagnostic app was left open after user input was detected. A subsequent
official Codex account/read call (without token refresh) confirmed that the
Zanzibarr profile is signed in to ChatGPT; only the connected boolean was
reported. One real FilmChat.send request with a synthetic classic-mystery-film
prompt returned a film title and description and passed the production reply
validator in eight seconds. It changed no playlists or playback. This verifies
the signed-in chat service, not merely the fixtures.

The original installed-app startup error has not yet been causally tied to the
confirmed disconnect deadlock. The older installed app was closed while idle for diagnosis. Later the diagnostic
process was no longer running; its exit cause is unknown. The user subsequently
reported a playback stop. Do not assume they closed it intentionally. The
installed app was upgraded to 1.15.0+16 and launched; its Dart payload hash matched
the verified release build. Rendered installed sign-in has not been rechecked.

## Fresh verification

- Serial locked Rust tests: **266 passed**.
- Locked Clippy, all targets with warnings denied: passed.
- Flutter analysis: no issues.
- Locked native host build: passed.
- Full Flutter suite: **314 passed, 8 existing screenshot skips**.
- git diff --check: passed.
- Release inputs: v1.15 / 1.15.0+16 valid.
- Focused integrations/chat tests: 21 passed.
- Real Codex direct/controller startup and cleanup: passed.
- One separate signed-in real film recommendation and reply validation: passed.

Logs and temporary diagnostic harnesses are clearly isolated under ignored
`dist/audit/codex-*`. No diagnostic logging was added to application code.

## Packaging

Windows release build completed in 117.7 seconds. Setup and portable ZIP passed
SHA256, ZIP integrity and required-payload checks (native/CRT DLLs, notices, MCP
bridge and connection guides). The per-user upgrade exited successfully, reported
1.15.0+16 and matched the built Dart payload. No running app was forcibly closed.

At installation the setup SHA256 was
`06e126da534961ae18be2e1befc79d7fa31df12ecbd244724f3c18a645bbff55`
and ZIP SHA256 was
`823f365b8957593b4a94e3fa10493fc9d7b58afc31ba4baf496ee2b29b240713`.
Later candidates may replace the ignored dist/windows outputs. Signing and a
clean-user installation lifecycle remain unverified. Claude/Gemini live
authentication and inference also remain unverified.
