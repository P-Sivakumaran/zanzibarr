"""Fail before platform builds if the release tag/version/notes disagree."""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
tag = sys.argv[1] if len(sys.argv) == 2 else ""
match = re.fullmatch(r"v(\d+)\.(\d+)(?:\.(\d+))?", tag)
if not match:
    sys.exit("Release tag must be vMAJOR.MINOR or vMAJOR.MINOR.PATCH")
version = re.search(r"^version: (\d+\.\d+\.\d+)\+(\d+)$", (root / "pubspec.yaml").read_text(encoding="utf-8"), re.M)
expected = ".".join([match[1], match[2], match[3] or "0"])
if not version or version[1] != expected:
    sys.exit("Release tag does not match pubspec.yaml version")
notes = root / "docs" / "releases" / f"{tag}.md"
if not notes.is_file() or not notes.read_text(encoding="utf-8").strip():
    sys.exit("Release notes are missing or empty")
print(f"Release inputs valid: {tag} ({version[0]})")
