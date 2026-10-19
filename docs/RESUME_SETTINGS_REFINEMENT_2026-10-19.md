# Resume view and settings refinement - 1.20

The user requested removal of "Your next screening", a professional continue-
watching view with real metadata, critic scores and appropriate artwork, and a
cleanup of AI and other settings. This pass preserves the earlier uncommitted
1.17-1.19 work and prepares an app preview rather than an installer.

## Continue watching

Removed the heading from Home and the library. The featured saved release now
has a portrait poster, canonical title, year, certification, runtime, known
season/episode, genre and synopsis. IMDb, Rotten Tomatoes and Metacritic retain
their original source and scale. Missing scores are explicitly unavailable.
A separate progress indicator shows the actual saved playhead and remaining
time. Resume plays the exact saved release; Title details opens the full page.
The original release filename is under a collapsed Release information section.

Saved metadata is reused without a network request. For an identified release
whose details are not saved, Load title details explicitly fetches the known
IMDb ID. For an unidentified or incorrectly identified release, Match title &
artwork / Change title match opens a title chooser. A filename only prefills the
editable search hint; it never becomes proof of identity or artwork. The chooser
returns metadata rather than starting a release search. Returned IDs and media
types are checked before saving. Posters use the existing opt-in, approved-CDN
loader and retain their full aspect ratio. No video frames are fetched, decoded
or invented for the Home view.

A confirmed match is saved to the title library and linked to the exact history
(nzbPath, entryKey). The history mutation is serialized and preserves current
playhead, source profile, recovery URL, episode and favorites. Deleted or changed
history entries cannot be recreated or overwritten by a late match. Failed
history writes preserve the previous record. Library metadata is saved first;
if the history link then fails, the selected title may remain saved in the
library, while the playback record stays unchanged.

OMDb remains optional and requires the user's key. Artwork loading remains an
independent opt-in. Older unmatched releases need one explicit match to show
reliable metadata; no ambiguous title or critic score is guessed.

## Settings organization

Home's Settings button now opens categories for Appearance, Language & subtitles,
Artwork & ratings, AI connections, Usenet provider, Indexers, and MCP & plugins.
It adapts from two columns to a single column for narrow screens/large text.
Provider and indexer setup routes retain their focused forms and save/recovery
behavior. Theme, language and media-language controls have dedicated entry points.
Artwork & ratings centralizes the image preference and masked OMDb key.

AI connections shows the saved provider, selected provider and its relevant
credentials. Save stays visible below the scroll view. Model IDs and account/
privacy explanation use progressive disclosure; external setup links align with
the fields. Back navigation protects an unsaved draft with Keep editing and
Discard changes. Existing provider switching, Google cancellation, secure
storage, save failure recovery and sanitized errors remain intact. Saving a
provider still does not claim successful live authentication or model access.

MCP settings separates AI recommendations, local assistant permissions, outgoing
connections/plugins and advanced Codex controls. Endpoint/token details and
executable-path configuration are collapsed. Removed the duplicate prominent
ChatGPT sign-in action and trailing Claude explanation; the advanced account
controls remain reachable. Local MCP still defaults off and existing permission
boundaries are unchanged. New copy uses disclosed English fallback.

## Preview images

Actual Flutter widget renders, using fictional sample title/ratings and the
existing Figma source fixture. These are layout examples, not live film metadata.

- [Home / resume](screenshots/resume-1280-flutter.png)
- [Phone resume](screenshots/resume-360-flutter.png)
- [Settings overview](screenshots/settings-1280-flutter.png)
- [Phone settings at 200% text](screenshots/settings-360-flutter.png)
- [AI settings](screenshots/ai-settings-flutter.png)

Regenerate with GENERATE_RESUME_SCREENSHOTS=1 and
`flutter test --no-pub test/resume_settings_test.dart --update-goldens`.

## Verification

Fresh ordered gate passed: 266 Rust tests (serial to avoid known Windows local
socket contention), Clippy, Flutter analysis, native host build, 363 Flutter
tests with 9 opt-in screenshot skips, and whitespace checks. Release inputs for
v1.20 validated. Logs are under ignored `dist/audit/resume-*`.

The seven new checks cover exact-entry history linking and current playhead/
recovery preservation, refusal of stale or deleted matches, failed identity
writes, metadata-only chooser returns, explicit known-ID enrichment, protected
AI drafts, persistent Save visibility, and desktop/360px layout renders. The
existing suite retains provider OAuth cancellation, settings save recovery,
D-pad, resume durability and manual curation checks.

The initial Flutter run exposed duplicate Continue watching text for unknown
entries; the neutral Saved release fallback removed that duplication. The
chooser test was corrected to scroll to its result before selecting it. Final
results above come from the passing rerun. No installer,
installation, publication, commit or push was requested or performed. Live
OMDb/model calls and physical playback/remote focus are not established by
widget renders or host builds.


Windows release build passed in 119.1 seconds. The executable reports
1.20.0+21. Bundle: `build/windows/x64/runner/Release/`; launch `zanzibarr.exe`
with its DLLs and data retained. SHA256: `7a37648813ba3d2b31a9bbe468b0d762d72e2bf931458efc6d78785859610b8b`.
The seven focused checks also passed with screenshot regeneration enabled.
Unsigned local preview; no installer was created and no installation was changed.
