# Film and TV discovery / keyboard verification

Candidate **1.17.0+18**, based on `a84cd0e` plus the working changes in this
task. The earlier PR #1 is merged; these changes are not yet committed or landed.

## Behavior

- Codex, Claude and Gemini share a typed recommendation schema for films,
  TV shows and miniseries. TV suggestions retain their type through chat,
  mixed playlists and TV release-search handoff. Missing types in new AI
  replies are rejected; legacy saved film lists remain readable.
- Discovery navigation and examples include TV. Cards show a Film/TV show
  label. The composer stays visible on desktop and reflows on short windows
  or large text. Responses scroll to their beginning.
- Enter sends; Shift+Enter inserts a newline. Ctrl/Cmd+Enter also sends.
  Escape stops a reply or connection check. Ctrl/Cmd+N starts a chat while
  preserving the draft; L focuses the composer; 1/2 selects Chat/Playlists;
  comma opens AI connections; slash or F1 opens shortcut help.
- Native selection, clipboard, undo, redo and Tab navigation remain available.
  Windows/Linux also accept Ctrl+Y for redo. IME composition can commit without
  submitting the request. Commands do not act through a dialog or another route.

## Fresh verification

The required gate passed in order: 266 Rust tests (serial), Clippy with warnings
denied, Flutter analysis, host native build, 337 Flutter tests (8 opt-in
screenshot cases skipped), and `git diff --check`. After the screenshot-only
capture adjustment, its focused case and analysis passed again.

The 19 focused TV/model/UI tests also passed with preview generation enabled.
Coverage includes shared schemas for all three providers, mixed-list roundtrip,
legacy compatibility, TV search, save/reopen, Enter/newline/undo/redo, IME,
cancel, shortcut navigation, native clipboard, simulated macOS keys, and narrow
RTL layout at 200% text with keyboard insets. `validate_release.py v1.17` passed.
Logs are under ignored `dist/audit/tv-*`.

Rendered widget previews (production theme, test font, mocked providers):

- [Ready](screenshots/film-chat-ready.png)
- [TV recommendation](screenshots/film-chat-tv-recommendation.png)
- [Connection recovery](screenshots/film-chat-connection-error.png)
- [Compact light theme](screenshots/film-chat-light-compact.png)
- [Shortcut dialog with large RTL text](screenshots/film-chat-shortcuts-large-text.png)

Windows release build passed; executable ProductVersion is `1.17.0+18`.
Setup and portable ZIP were built with the existing packaging script. Both
SHA256 hashes, ZIP CRC integrity and required native/CRT DLLs, transparent icon,
MCP bridge, notices and connection guides passed verification.

| Artifact | Bytes | SHA256 |
|---|---:|---|
| `dist/windows/zanzibarr-windows-x64-setup.exe` | 29349260 | `7c0f9386fedd3ca896cb109ea17c0c188777a08ab731ad4daf0308b0f79f91b0` |
| `dist/windows/zanzibarr-windows-x64.zip` | 38341504 | `88e6db2c2ebb4579b2fc86d1738384c3d103e393efee54e81022befff0a8cadb` |

These packages are unsigned, not installed or published. Installer lifecycle
smoke was not run against the existing user installation.

No live model request or authentication was performed. These previews are not
installed native UI evidence. Clean-user installation, physical remote input,
native macOS behavior and device playback have not been verified in this task.
Title playlists do not implement episode selection, a playback queue or
availability verification. Earlier persistence-review findings remain separate.
