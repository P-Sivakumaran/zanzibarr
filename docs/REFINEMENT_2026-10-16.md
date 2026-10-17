# Codebase refinement — 2026-10-16

Baseline: 386c5e2c2f95f0edb6bf3b4537b3c39ebb92cca7, plus this task's working changes.

## Search deduplication

Extracted the Flutter result deduplicator into search_deduplication.dart.
Retained URLs use a set; retained normalized titles use size buckets. Titles
are normalized once per candidate and the separator expression is reused.
Unrelated titles no longer incur pairwise normalization and size comparisons.
First-result priority, URL matching, unknown sizes, BigInt arithmetic and the
inclusive 1% size threshold remain unchanged. Rejected candidates never enter
the indexes, preserving the original non-transitive matching behavior.
Pagination still uses the existing raw source offsets.

Four regressions cover matching boundaries and compare with the original
pairwise algorithm over 40 deterministic sets of 150 mixed releases.

Local Dart JIT microbenchmark, 10 measured runs after 5 warmups, distinct titles:

| Results | Original total | Indexed total |
|---|---:|---:|
| 100 | 203,656 microseconds | 5,538 microseconds |
| 500 | 5,651,864 microseconds | 15,299 microseconds |
| 1,000 | 24,958,315 microseconds | 24,531 microseconds |

These are synthetic function timings, not network or end-to-end search times.
Same-title size buckets can still require pairwise comparisons. Logs and the
benchmark harness are under ignored dist/audit/.

## Icon repair

The original source was an opaque product-style image with a black surround.
The built-in image_gen tool produced the transparent cutout master at
assets/zanzibarr-icon.png. The generator normalizes residual alpha, crops to
the solid silhouette and preserves antialiased rounded corners. Generated
assets/zanzibarr-icon-256.png is used on Home and in Linux packages. Windows
ICO, macOS, Android, Android TV and opaque iOS assets have been regenerated.
The promotional logo and documentation images remain available.

The generator resolves all paths relative to its own location, replacing the
upstream developer's absolute source path. Requires Pillow:

    python tools/generate_icons.py

Final built-in edit prompt:

> Extract the navy rounded-square app icon from this image. Preserve original
> coral triangle sunset sailboat palms artwork. Critical production alpha
> requirements: the entire navy tile interior must be fully opaque (alpha 255),
> the entire exterior must be completely transparent (alpha 0), with only clean
> smooth anti-aliased pixels at rounded tile contour. No shadow, no glow, no
> specks, no background, no semi-transparent texture. Tile centered, fills 94%
> width and height. This is a clean flat app icon cutout, not product mockup.
> Avoid changing design.

## Verification

- Flutter 3.44.6 / Dart 3.12.2; resolved locked Flutter dependencies in this fresh checkout.
- Required gate in order: 266 Rust tests passed; Clippy/all targets with warnings
  denied passed; Flutter analysis passed; native host build passed; 270 Flutter
  tests passed with 8 existing opt-in screenshot skips; whitespace check passed.
- Initial analysis caught two style issues in the new test; both fixed before
  the passing analysis and subsequent build/tests.
- Icon checks: transparent desktop/Android/Linux corners, opaque centers,
  opaque RGB iOS images and all seven Windows ICO resolutions passed. Tiny
  subpixel alpha from ICO downsampling is permitted (at most 3/255 in corners).
- Generator rerun from a different working directory produced identical hashes.
- Windows release build passed. All seven replacement ICO frames were found
  embedded in build/windows/x64/runner/Release/zanzibarr.exe, and the bundled
  transparent Home asset exactly matches the source. The complete Release
  directory is required to run the app. No installer was produced.
- Linux package execution and Android/iOS/macOS builds/device launcher checks
  were not run on this Windows host. Installed Windows icon-cache behavior is
  not covered by image validation. No installer, release, commit or push made.
