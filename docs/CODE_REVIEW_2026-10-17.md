# Working-change code review — 2026-10-17

Baseline: **386c5e2c2f95f0edb6bf3b4537b3c39ebb92cca7** (current HEAD),
branch kepler/fix-zanzibar-icon. Scope: tracked working changes from git diff
HEAD -- and untracked production/test source for chat, integrations and the MCP
bridge. No new commits exist beyond this baseline. Current source candidate is
1.16.0+17; installed version was last verified as 1.15.0+16.

Standards source: AGENTS.md. Specification source: this task's user requests for
icon/performance refinement, launch-time updates, MCP/plugins, account/provider
connections, in-app film recommendations/playlists and reliable playback resume.
There is no separate issue specification. Independent standards and requirements
reviews were performed, with offline production-code reproductions of both
findings. No application source was changed during this review.

## Standards

### P2 — Google token refresh can undo later connection changes

Location: lib/chat/ai_connections.dart:205–206 (updateGoogleTokens).

The method reads and compares a connection snapshot, then saves the entire
updated value asynchronously. A different store instance can save the user's
provider change or Google disconnect while this refresh write is pending. When
the delayed refresh commits, it overwrites that save, restoring the previous
provider and Google credentials. This violates AGENTS.md rule 5: preserve user
changes and ignore stale asynchronous results.

Confirmed by dist/audit/review_google_refresh_race_test.dart: the user's save
selected Claude and cleared Google tokens; after the delayed refresh committed,
the selected provider was Gemini again. The offline test fails on that assertion.
Only TESTPASS123 fixture credentials were used. No real credentials were read.

Correction: coordinate all settings saves and token-refresh mutations across
store instances, performing the read/compare/write atomically in a shared queue
or using revision checks. Apply only the intended mutation to current state.
A per-instance busy flag does not protect separate screens/stores.

## Spec

### P2 — An older playlist screen can erase newly saved playlists

Locations: lib/chat/film_chat_screen.dart:215 and
lib/chat/film_playlist.dart:147–155.

Requirement: “set up a playlist”; the implemented feature promises persistent
ordered viewing lists. Each screen loads _playlists once, and every edit replaces
the entire saved collection. The UI permits Chat A → Find releases → Search
settings → MCP & AI → Discover films B. Saving a playlist in B and then returning
to edit a playlist in A writes A's older snapshot, deleting B's new list or
undoing its edits without warning.

Confirmed by dist/audit/review_playlist_stale_test.dart using the production
store: expected playlist IDs a and b after renaming a from an earlier snapshot;
actual IDs contained only a. The offline test fails deterministically.

Correction: persist mutations by playlist ID against freshly loaded state under
shared serialization, or reject stale revisions and reload/merge. Merely
serializing whole-collection snapshot saves still loses these updates.

## Verification and limits

- Existing focused Flutter tests: **75 passed** across playback_history,
  resume_durability, film_chat, ai_providers, integrations and search_deduplication.
- Python MCP bridge tests: **3 passed**.
- git diff --check: passed.
- Two additional ignored review probes: **both fail**, demonstrating the findings.
- Logs/harnesses are under ignored dist/audit/review-* and
  dist/audit/code-review-focused.log.
- No live API/authentication calls, browser/native UI automation, installation,
  public release or source fixes were performed during the review.
- The earlier resume native-player check passed, but this review did not repeat
  live NNTP playback, crash recovery or the complete application gate. The
  reported playback cessation has not been reproduced or assigned a cause.
- Binary launcher assets and non-Windows platform runtime behavior were not
  revalidated in this review. They remain platform verification limits, not
  confirmed defects.

Findings: Standards **1 (P2)**; Spec **1 (P2)**. Both should be corrected before
promoting the current candidate. No additional confirmed P0/P1 issue was found.
