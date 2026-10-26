"""Export readable review copies of the app's single-source legal drafts."""

import argparse
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check copies without writing")
    options = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    for name in ("terms", "privacy"):
        source = root / "assets" / "legal" / f"{name}.json"
        data = json.loads(source.read_text(encoding="utf-8"))
        paragraphs = [
            f"# {data['title']}",
            f"**{data['status']} — {data['version']}**",
            data["notice"],
            f"> Generated review copy from [JSON source](../../assets/legal/{name}.json). "
            "Edit that source and run `python tools/export_legal_documents.py` "
            "to refresh both documents.",
            data["summary"],
        ]
        for section in data["sections"]:
            paragraphs.append(f"## {section['title']}")
            paragraphs.extend(section["paragraphs"])
        text = "\n\n".join(paragraphs) + "\n"
        target = root / "docs" / "legal" / f"{name.upper()}_DRAFT.md"
        if options.check:
            if not target.exists() or target.read_text(encoding="utf-8") != text:
                raise SystemExit(f"Outdated legal review copy: {target.relative_to(root)}")
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding="utf-8", newline="\n")
    print("Legal review copies are current.")


if __name__ == "__main__":
    main()
