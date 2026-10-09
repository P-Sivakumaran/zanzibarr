# UI/UX review — 2026-10-10

Scope: current local Flutter source and repository screenshots of home, settings, search, and player. Screenshots are existing desktop golden fixtures, not fresh captures of the running app. No live playback, physical remote, screen reader, or device testing was performed. This is a heuristic review, not accessibility certification. Existing implementation changes were preserved.

The findings below record the state before implementation. The follow-up at the end describes the local fixes.

The dark visual language, consistent cards, clear primary home actions, labeled settings fields, player tooltips, slider semantics, and explicit TV focus treatment provide a solid foundation. The largest opportunities are completing tasks on phones and helping new users reach successful playback.

## Findings, in priority order

### 1. High — Audio-track selection disappears on narrow screens

`lib/player/gyuni_player_controls.dart:711` gates both volume and the audio-track menu behind `constraints.maxWidth >= 430`. After horizontal padding, common portrait phones fall below this threshold. The advanced settings panel exposes audio processing and delay, but no alternative track selector. Users cannot switch a multilingual release to their preferred language without changing the window/orientation.

Recommendation: keep audio-track selection available at every supported width, using a labeled overflow menu or a combined audio/subtitle sheet. Volume can rely on device controls on phones.

Validation: at 360 and 390 logical pixels, select a second audio track without rotating; repeat with keyboard and screen reader.

### 2. High — Player controls have small touch targets

`lib/player/gyuni_player_controls.dart:1097` gives shared icon buttons a tight 34×32 logical-pixel box with compact density and zero padding. This affects play/pause, close, subtitles, fullscreen, and other common actions. Adjacent controls are difficult to hit precisely on a phone.

Recommendation: use at least 48×48 logical-pixel hit areas for touch layouts while retaining smaller visual icons. Move secondary actions into overflow rather than shrinking targets. Give TV layouts larger spacing and an obvious focus state.

Validation: inspect actual hit rectangles on a narrow phone; confirm adjacent targets do not overlap and the expanded toolbar still fits.

### 3. High — First-time playback leads to a dead-end error

Home offers “Select NZB and play” before checking provider readiness (`lib/main.dart:480`). The player checks credentials only after navigation (`lib/player/player_screen.dart:344`), then shows an error whose actions include closing and potentially repair, with no provider setup action (`:3356`). A new user must back out and discover the settings gear. Settings also offers an indexer connection test but no NNTP connection test, so saving credentials does not establish that playback will work.

Recommendation: show a first-run provider setup action, explain that a Usenet provider is required and an indexer is optional, preserve the pending NZB through setup, and continue automatically after saving. Add a distinct NNTP connection test with useful authentication/connection feedback.

Validation: from empty storage, open an NZB, configure the provider, and reach the selected file without choosing it again. Incorrect credentials should offer a direct correction path.

### 4. Medium — Search reports results users cannot reach

`lib/search/search_screen.dart:67,165` requests 50 results with offset zero. The UI displays the server total but renders only the returned items and has no pagination or “load more” control. A total greater than 50 implies a collection the user cannot browse.

Recommendation: add pagination or a load-more action, preserving query and scroll position. Display “Showing 50 of 240” until all results are reachable; provide loading and retry states for subsequent pages.

Validation: a fake response with total 120 allows reaching all 120 entries without duplicate rows or losing focus after loading.

### 5. Medium — Settings routing loses the user's task

`lib/main.dart:503` routes missing-indexer users to the general settings screen. That screen is titled “Provider” (`lib/settings/settings_screen.dart:401`), begins with appearance preferences, and puts indexer setup below NNTP settings. After saving and returning, the original search action is not resumed. Both credential forms require explicit saves, but leaving the screen has no dirty-state guard.

Recommendation: rename the screen “Settings”, support opening directly at Provider or Indexer, resume search after successful indexer setup, and indicate unsaved changes when navigating away. Clearly distinguish immediately saved appearance preferences from credentials requiring Save.

Validation: selecting Search with no indexer focuses the indexer form; saving continues to Search. Back with edited credentials offers Save/Discard/Keep editing.

### 6. Medium — Episode names are truncated at the decision point

`lib/player/entry_picker.dart:92` restricts names to one ellipsized line. Releases often share long prefixes, making episode suffixes or distinguishing versions invisible on phones. Search similarly truncates release names to two lines without a details action (`lib/search/search_screen.dart`, result card).

Recommendation: prioritize parsed episode/title information, allow names to wrap, and offer full-name details accessible by touch, keyboard, and remote. Keep archive kind/parts secondary to the media identity. Add a visible Cancel action to the episode picker for desktop discoverability.

Validation: two long names differing near their end can be distinguished and selected at 360 logical pixels and enlarged text.

### 7. Medium — Secondary text is too subdued and small

Search ages and years use foreground alpha 0.38 with 11-pixel text (`lib/search/search_screen.dart:531,542`); badges use 10-pixel text (`:500`). Home and settings also use heavily faded supporting text. Existing screenshots show metadata receding substantially. TV uses the same compact typography, which is especially difficult at viewing distance.

Recommendation: use semantic secondary-text colors with verified contrast against the actual composited surfaces, increase metadata sizing, and add a TV typography/spacing profile. Avoid using opacity alone to establish hierarchy.

Validation: measure final rendered foreground/background contrast in both themes, inspect at 200% text scaling, and evaluate TV readability at normal viewing distance. Exact contrast compliance was not measured in this review.

### 8. Medium — Errors and failed actions lack useful recovery

Search renders a raw exception truncated to four lines (`lib/search/search_screen.dart`, `_SearchError`); settings loading does the same in three lines. Player errors expose engine terminology in the main message. History load/delete failures silently return (`lib/main.dart:449,460`), leaving users uncertain whether an action worked.

Recommendation: map common errors to a short explanation and relevant action: Edit provider, Edit indexer, Retry, or Choose another file. Place sanitized technical details behind an expandable/copyable disclosure. Show explicit failure feedback for history operations; consider Undo after successful removal.

Validation: authentication failure, offline search, malformed NZB, and history-write failure each show a comprehensible message and working next action. Never expose credentials in details.

## Suggested implementation order

1. Restore mobile audio selection and enlarge touch targets together.
2. Complete provider/indexer setup and return-to-task flows.
3. Add search pagination and full filename inspection.
4. Improve error recovery, typography, and TV presentation.

Before release, run focused widget checks at 360/390/1280 logical pixels, enlarged text and RTL; then manually verify keyboard, TalkBack/NVDA, and a physical Android TV remote. Existing screenshots cannot establish runtime focus, assistive-technology announcements, or responsive overflow behavior.

## Implementation follow-up — 2026-10-10

All eight findings have local fixes:

1. Audio-track selection remains available at narrow widths. Secondary top-toolbar controls move into a labeled overflow menu.
2. Player icon, track, and speed controls have minimum 48px targets. Elapsed time has its own line to avoid crowding; history removal targets were enlarged too. Player button semantics expose an activation action.
3. Opening an NZB without provider credentials goes to provider setup and retains the pending path and episode. Player errors also offer provider editing and resume the selected file after saving. The new native provider check authenticates one TLS connection within 15 seconds without fetching media, saving credentials, or echoing server response text.
4. Search supports additional pages, accurate shown/total counts, retained queries, retry, deduplication, stale-response suppression, and focus on newly appended results. Changing indexer configuration clears stale results.
5. Settings opens directly at the relevant provider/indexer form, continues search after setup, and offers Save/Discard/Keep editing for unsaved credentials. Appearance preferences are explicitly automatic. Loading failures offer retry, loading timers are canceled on disposal, and invalid submissions scroll to the first error.
6. Episode filenames wrap fully, the picker has a visible Cancel action, and search offers a keyboard/touch-accessible full-name details dialog.
7. Metadata uses larger text and stronger contrast. Directional navigation gets a minimum 1.25 text scale without reducing user scaling. Narrow layouts reflow metadata, and enlarged-text appearance selection uses a dropdown. Language/theme dropdowns expand within their available width.
8. Search errors show a useful explanation and settings/retry actions, with selectable sanitized diagnostics behind a disclosure. Player startup diagnostics are similarly separated from the explanation; URLs and recognized credential fields are redacted. Search additionally redacts the active API key. History read failures offer retry; delete failures preserve the item and report failure.

New UI copy is English/Turkish, with English fallbacks for other locales. Existing translations are preserved. The already locked `intl` version is now an explicit dependency for generated localization formatting; no dependency versions were upgraded.

Automated coverage includes setup return-to-task, failed saves and draft preservation, provider testing without saving, pagination retries/overlap/late responses, long filenames, narrow RTL search, history read/delete failures, diagnostic redaction, phone player controls at 360/390 pixels with 200% text, and settings/search at 360 pixels with 200% text. Existing D-pad regression coverage remains enabled.

No live provider account, physical phone/TV, or screen reader was used. Final on-device contrast measurements and updated release screenshots remain follow-up validation; this work does not claim accessibility certification.

Final verification: `cargo test --locked` **257 passed**; `cargo clippy --locked --all-targets -- -D warnings` passed; host `cargo build --locked` passed; `flutter analyze --no-pub lib test` reported no issues; `flutter test --no-pub` **190 passed, 8 existing opt-in screenshot cases skipped**; `git diff --check` passed. Changes remain local and uncommitted.
