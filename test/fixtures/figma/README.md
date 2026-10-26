# Figma preview artwork

`quiet-coast.png` is the source image supplied by the user's Zanzibarr Figma
file `rTvTd3yopeT26JEmVneFYU` (featured image node `103:798`, also used by the
Cinematic variant). Retrieved through Figma MCP design context on 19 October
2026. It is used only by opt-in rendered-widget previews, with fictional sample
metadata. It is not bundled as a poster for any actual title or release.

`last-orchard.png`, `blue-hours.png` and `place-between.png` were downloaded
through Figma MCP design context on 26 October 2026 from the same Minimalist
frame (nodes 103:842, 103:857 and 103:872). They are also sample-only assets,
used by the UI review library; no real-title metadata is inferred from them.

Regenerate previews with `GENERATE_SCREENSHOTS=1 flutter test --no-pub
test/metadata_library_test.dart --plain-name "render Figma artwork"
--update-goldens` (set the environment variable using your shell's syntax).
