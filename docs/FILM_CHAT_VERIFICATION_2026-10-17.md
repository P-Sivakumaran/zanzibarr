# Film chat and playlist verification — 2026-10-17

Baseline HEAD: `386c5e2c2f95f0edb6bf3b4537b3c39ebb92cca7`, branch
`kepler/fix-zanzibar-icon`, plus the existing uncommitted icon, search and
integration work. This change is also uncommitted. No push, tag or publication.

## Implemented

- Home sparkle action and an Integrations entry open film discovery chat.
- Codex executable discovery, managed account connection, browser login status,
  bounded ephemeral turns, follow-up context, cancellation and recovery.
- Structured, validated recommendation cards with descriptions and reasons.
- Named playlists in secure storage, append/deduplicate/reorder/rename/remove,
  and title/year handoff to the existing release-search route.
- Failed requests preserve the chat draft. Failed playlist saves preserve the
  prior list or name draft; failed loads disable editing until recovery.
- Existing library layout and D-pad up-navigation to Settings are preserved.
  Home header actions are above scrollable content for pointer access.

## Fresh verification

- Locked Rust tests: **266 passed**, serial execution (`RUST_TEST_THREADS=1`).
- Locked Clippy, all targets with `-D warnings`: passed.
- Flutter analysis, `lib test`: no issues.
- Locked host native build: passed.
- Full Flutter suite: **297 passed, 8 existing screenshot skips**.
- Ten new chat tests cover schema/identity bounds, persistent playlist ordering,
  failed writes, invalid stored data, early notifications, follow-up context,
  failed/malformed responses, stop before thread acknowledgment, timeout,
  stale account startup, rejected tool requests, save/retry/search UI and
  narrow-screen 200% text. Some scenarios share a test.
- Real installed Codex **0.162.1** accepted initialization, an ephemeral
  read-only film thread and unsubscribe in an isolated signed-out profile.
  This smoke check made **no OAuth or inference request**.
- Release inputs for `v1.12` / `1.12.0+13`: valid.
- `git diff --check`: passed.

The first full Flutter run found Home cards displaced below the initial
viewport and integration-screen tests waiting on real executable discovery.
The Home entry was moved into the header; discovery is injectable in tests.
A subsequent directional-focus regression was corrected by keeping Settings
as the header control nearest the primary cards. Final full-suite results
above include those fixes. Earlier screen-test stalls were fake-time versus
real-event-queue stream cleanup; the test harness now drains both queues.

Logs and the no-inference protocol smoke script are under ignored
`dist/audit/chat-*` and `dist/audit/codex_chat_schema.cjs`.

## Practical limits

Live browser sign-in and actual model recommendations are not verified. The
current installed copy was observed at **1.11.0+12** during this work; the
1.12 candidate adds the chat flow. Model/account eligibility and usage limits
remain controlled by Codex/OpenAI. No in-app Claude inference was added.

Playlists are ordered viewing lists, not an automatic playback queue. Choosing
a release and starting playback remain explicit user actions. AI descriptions
and years can be wrong; no web/metadata grounding or availability lookup occurs
until the user requests release search. Chat history is not persisted by the UI.

Native rendered UI, clean-user installer lifecycle, live indexer/playback,
casting, physical TV/remote interaction and other platforms remain unverified.
The installer is not publisher-signed. See [setup](FILM_CHAT.md) for user steps.

## Windows artifacts

The release build completed in 90.8 seconds; Inno compilation completed in
29.859 seconds. Executable ProductVersion is **1.12.0+13**. Setup and portable
ZIP hashes, ZIP CRCs and required native/CRT/license/bridge components passed.
The dependency lockfile remained unchanged.

- Setup: dist/windows/zanzibarr-windows-x64-setup.exe (29,294,698 bytes)
- Portable: dist/windows/zanzibarr-windows-x64.zip (38,263,401 bytes)
- Manifest: dist/windows/SHA256SUMS

SHA256:

    963e975b2eddf5294f80438e2dccf22753adf6745353a4e0b18141e8fd2e35fb  zanzibarr-windows-x64-setup.exe
    2ac5a34078681e3529d1e2545d95f3442928830d51443d7472f4c04f9bb2bb0f  zanzibarr-windows-x64.zip

These artifacts were built from the verified working tree; they are not tied
to a new commit or published release. No 1.12 installation was performed.
