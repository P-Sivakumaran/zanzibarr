"""Export the app's League Mono wordmark as self-contained SVG paths.

Requires fonttools. Run from the repository root; no web font is needed by GitHub.
"""

from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
font = TTFont(ROOT / "assets/fonts/LeagueMono-Thin.ttf")
glyphs = font.getGlyphSet()
cmap = font.getBestCmap()
scale = 96 / font["head"].unitsPerEm
paths = []
x = 32.0
for index, char in enumerate("zanzibarr"):
    name = cmap[ord(char)]
    pen = SVGPathPen(glyphs)
    glyphs[name].draw(pen)
    color = "#ff453a" if index in (2, 3, 5) else "#f2f4f8"
    paths.append(
        f'<path fill="{color}" transform="translate({x:.3f} 118) '
        f'scale({scale:.6f} {-scale:.6f})" d="{pen.getCommands()}"/>'
    )
    x += font["hmtx"].metrics[name][0] * scale
width = round(x + 32)
svg = (
    f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} 164" '
    'role="img" aria-labelledby="title">\n'
    '<title id="title">zanzibarr</title>\n'
    '<!-- League Mono by Tyler Finck; see LeagueMono-OFL.txt. '
    'Matches the app wordmark, including its coral n/z/b. -->\n'
    f'<rect width="{width}" height="164" rx="20" fill="#0b0d12"/>\n'
    + "\n".join(paths)
    + "\n</svg>\n"
)
(ROOT / "docs/assets/zanzibarr-wordmark.svg").write_text(svg, encoding="utf-8")
print("Exported docs/assets/zanzibarr-wordmark.svg")
