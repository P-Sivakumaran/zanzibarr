# Claude and Gemini connections — 2026-10-17

Baseline HEAD: `386c5e2c2f95f0edb6bf3b4537b3c39ebb92cca7`, branch
`kepler/fix-zanzibar-icon`, plus the existing uncommitted feature work.
Candidate: **1.14.0+15**. No commit, tag, push or publication was performed.

## Implemented

- Add an AI connections screen from Discover films and Settings → MCP & AI.
- Route film chat to Claude Messages or Gemini GenerateContent with a user API
  key, retaining the common film validation, playlist and release-search flow.
- Offer Gemini Google sign-in using a user-registered Desktop OAuth client,
  external browser, ephemeral loopback callback, PKCE S256, state/issuer checks,
  refresh and cancellation. No CLI credentials or browser sessions are imported.
- Persist keys and tokens using OS secure storage. Failed saves retain drafts;
  refresh must be persisted before inference. Sanitize errors, block redirects,
  cap response bodies and cancel requests when stopped or closed.
- Clear conversation history when switching providers. Ignore a stale startup
  result if connection settings are opened while loading or discovering Codex.
- Bundle the connection, chat and integration guides in Windows packages.

Claude subscription OAuth is not offered for third-party inference. Gemini
Google OAuth uses API access and project quota, independent of a chat subscription.
See [setup and official provider references](AI_CONNECTIONS.md).

## Fresh verification

Required gate, in repository order:

- Locked Rust tests: **266 passed**, serial execution.
- Locked Clippy, all targets with warnings denied: passed.
- Flutter analysis: no issues.
- Locked host native build: passed.
- Full Flutter suite: **312 passed, 8 existing optional screenshot skips**.
- Whitespace check: passed.
- Release inputs: v1.14 / 1.14.0+15 valid.

Twelve added tests cover provider request formats and history, rejected/partial
responses, redirects, size/time/cancellation bounds, secure-storage failures,
real loopback callback handling with mocked token exchange, PKCE, state and
issuer validation, listener cleanup, token refresh ordering, masked setup fields,
360-pixel/200% text layout, film cards/search, provider switching and stale startup
results. Initial callback tests were intercepted by Flutter's test HTTP override;
the regression now runs the loopback HTTP client under a real HttpOverrides
context. A horizontal-versus-vertical test scrolling ambiguity was also corrected.

Google's live REST discovery schema was checked for GenerationConfig responseFormat:
text.mimeType uses the enum APPLICATION_JSON. Provider fixtures use the verified
wire format; no real model request was made. Logs are under ignored
`dist/audit/ai-providers-*`.

## Packaging

Windows release build passed in 98.9 seconds. Inno installer compilation and
portable packaging passed. ProductVersion is **1.14.0+15**. Both dependency
lockfiles remain unchanged. Setup/ZIP hashes, ZIP CRCs, required native/CRT
libraries, notices, MCP bridge and all three setup guides were verified.

Artifacts (unsigned; not installed or published):

- `dist/windows/zanzibarr-windows-x64-setup.exe` — 29,325,900 bytes
- `dist/windows/zanzibarr-windows-x64.zip` — 38,308,813 bytes
- `dist/windows/SHA256SUMS`

SHA256:

```text
f3b3788cf62baae97fe8e271437a5ebeb103064ac329cc736605c889e74e0ef3  zanzibarr-windows-x64-setup.exe
a705fef05701a853c22afb000fbc4e22b30f914b617e9e4991b72ac5fcb45e49  zanzibarr-windows-x64.zip
```

## Remaining verification

No real Claude/Gemini API key or Google desktop client was supplied, so live
browser consent, token exchange and model inference remain unverified. Enter
credentials only in the application. The client registration must be configured
by its Google Cloud project owner. No other platform build was performed.

The installed app remains **1.13.0+14**. Its reported Codex connection failure
remains unresolved. A separate real Dart probe against installed Codex 0.162.1
successfully exercised startup, creation of a login URL and cancellation; it did
not establish why the installed Flutter application fails. It performed no login
completion or inference. Computer Use was stopped when the user pressed Escape.

Native 1.14 rendering, clean-user installer lifecycle, physical playback and
real provider account access have not been exercised. An existing installation
registration prevents the disposable installer lifecycle smoke from running safely;
use a fresh Windows user/VM. Existing installation and settings are preserved.
