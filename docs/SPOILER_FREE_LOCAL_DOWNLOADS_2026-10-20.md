# Spoiler-conscious overviews, fixed header and local downloads

Candidate: **1.23.0+24**. Continues the 1.22 metadata work.

## Experience

Overview copy uses year, up to three genres, director and up to two cast members.
It never reads or truncates the provider plot. This gives a concise introduction
without assuming a short synopsis is spoiler-free. Full plot text is behind
**Story synopsis (may reveal plot)** on title pages. AI discovery is instructed
to use one sentence, at most 35 words, about tone, filmmaking, genre or cast and
avoid plot outcomes. This prompt is guidance, not a guarantee for AI responses;
existing unmatched AI descriptions are not regenerated. Matched cards use facts.

The Home logo and animated wordmark now share a fixed 52-pixel header row with
navigation. The scroll view starts below it. Narrow windows expose navigation
through a menu; reduced motion behavior remains in the existing wordmark.

**Download / local video** on Home opens an explicit NZB/folder workflow.
Streaming failures also offer **Download & play locally**, releasing that stream
before downloading. Original NZB files, including archive volumes and recovery
files, are downloaded without asking the streaming archive parser to open them.
Completed videos have Play actions. Archive sets require extraction using a
separate local archive tool, followed by **Open local video**. Local videos use
file URIs and the existing controls/history, without creating a streaming session
or requiring configured NNTP access. Moved/deleted local files show a specific
message instead of triggering indexer recovery.

## Bounds and recovery

One active download; keep its screen open. Back navigation confirms cancellation
and waits for terminal state. Jobs accept NZBs up to 64 MiB, 1-4096 original files,
and at most 200 GiB decoded data. Decoded offsets and size come from yEnc, never
encoded NZB estimates. Each read is at most 1 MiB; NNTP caching/prefetch stays bounded.
Destination is an existing chosen folder with a unique job subfolder. Names must
be safe basenames, unique ignoring case, without Windows reserved devices.

Files use create-new staging, exact-length reads, sync and rename. Normal failures
and cancellation remove the current partial file and preserve completed files.
Abrupt process termination can leave a .zanzibarr-part file. There is no persistent
job queue, automatic extraction, PAR repair or cross-launch download resumption.
Progress distinguishes written bytes from decoded size discovered so far.
Provider credentials use the existing secure store; errors remain static/sanitized.

## Verification

Fresh ordered gate passed: 270 Rust tests (serial), Clippy with warnings denied,
Flutter analysis, native host build, 388 Flutter tests with 9 screenshot skips,
and whitespace checks. Four native download regressions cover filename safety,
invalid files/session handling, bounded copying/short reads and cancellation.
Five Flutter regressions cover local file URIs/missing files, spoiler-independent
copy, explicit download/progress/cancel, sanitized failure recovery and fixed
header placement after scrolling. An additional 21 preview checks passed while
refreshing actual widget screenshots at desktop/narrow widths.

Rendered previews were inspected: [desktop resume](screenshots/resume-1280-flutter.png),
[narrow resume](screenshots/resume-360-flutter.png),
[title](screenshots/metadata-title-flutter.png).

Windows build/package evidence will be recorded below when complete. No live NNTP
download, RAR4 extraction, local native playback, device playback or clean-user
installation is claimed. No release is signed or published.
