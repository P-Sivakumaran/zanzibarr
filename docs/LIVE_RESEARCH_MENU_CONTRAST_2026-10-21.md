# Optional web research and player menu contrast

Local candidate: **1.29.0+30**, based on `3080da6`, plus recorded working changes.
This is a local candidate, not a published release.

## Research

Claude and Gemini have a saved, off-by-default Live research setting. One
bounded research request precedes the existing structured recommendation request.
Claude has a three-search maximum; Google controls Gemini's query count. The
setting explains additional usage/charges and prompt sharing. No extra provider
key, library access, MCP permissions or playback authority is introduced.

Provider citations form the source list. Uncited text is excluded from factual
context. Research failures stop the reply without an automatic paid retry.
Cancellation and configuration/consent checks apply between phases. Google
research retains its original text and Search Suggestions in a restricted native
view; unavailable attribution hides/discards the researched reply. The native
view has no JavaScript, file access, API headers or command bridge.

See [setup and provider contracts](AI_CONNECTIONS.md). Criteria distinguish
original film years, Criterion editions, Collection releases and region-specific
Channel availability. Saved film descriptions remain evergreen and spoiler-free.

## Menu review and correction

The confirmed defect was dark player popup backgrounds paired with text and
checkmarks inherited from the light app theme. Subtitle track/font/colour, audio,
speed, compact toolbar and advanced context menus now share a scoped dark palette
with opaque surfaces. Programmatic context entries receive the same theme for
their text and focus interactions. App-wide menus keep their existing app theme.
Long subtitle/font labels can wrap inside their available width.

| Role | Colours | Contrast |
| --- | --- | --- |
| Normal text/checkmark | `#F5F5F7` / `#202024` | 14.91:1 |
| Focused text | `#F5F5F7` / `#6C6C74` | 4.78:1 |
| Focus fill / menu | `#6C6C74` / `#202024` | 3.12:1 |
| Disabled text / menu | `#CBCBD3` / `#202024` | 10.07:1 |

Widget checks inspect resolved text/icon colours and actual menu materials in
light and dark themes, dismiss using Escape, preserve the app theme, and exercise
the audio/speed menus. A 390 px, 200% text-size subtitle-font preview was rendered
with bundled fonts and inspected at `dist/audit/subtitle-menu-390.png`.

Remaining accessibility limits: the compact subtitle editor still scales its
toolbar on narrow screens; the menu fix is not a claim that every toolbar target
meets mobile sizing. Physical remote, screen-reader and native-video contrast
checks remain outstanding.

## Verification and artifacts

The fresh ordered gate passed: 280 Rust tests, Clippy with warnings denied,
Flutter analysis including the isolated release entrypoint, host native build,
484 Flutter tests (10 optional skips), and whitespace validation. Eighteen
focused player-menu checks passed separately; 40 research/provider/chat checks
passed before the menu changes. Logs are in ignored `dist/audit/`.
Live paid-provider inference and native Google attribution rendering have not
been exercised with user credentials. Clean-user installation/device playback
require separate validation. No signing certificate is configured.

The build uses `dist/entrypoints/v1.29/main.dart` and explicit version overrides,
preserving the unrelated root v1.27 work. `dist/candidates/v1.29/SOURCE.json`
records the source inventory and baseline routing/package overrides. The
unfinished hosted-video catalog remains excluded; its source files are preserved.

Final Windows build passed in 100.7 seconds. Unsigned setup and portable ZIP are
under `dist/windows/v1.29`. Artifact SHA-256, ZIP CRC and all 64 bundle file hashes
passed, including AOT code, native/CRT/WebView runtimes, notices and guides. The
installer is `NotSigned`. Installer lifecycle smoke stopped at the existing
installation guard; the installed copy was preserved. No clean-user install,
live inference, physical playback, commit, push or publication is claimed.

Build and package logs: `final129-windows-build.log`, `final129-package.log`.
The native build retains plugin CMake developer warnings (CMP0175); they did not
fail the build. Root `pubspec.yaml` and unrelated catalog edits remain unchanged.
