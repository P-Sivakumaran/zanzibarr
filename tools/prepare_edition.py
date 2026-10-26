"""Prepare isolated Windows edition source inputs. Never installs or publishes.

Clean is the default. Unimplemented content admission keeps Clean capabilities
closed; a preparation manifest is not a release or content-safety certification.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

PROFILES = {
    "clean": {"name": "Zanzibarr Clean", "binary": "zanzibarr-clean",
              "app_id": "{43D521D2-34C4-4A73-B470-3384C459788A}"},
    "restricted": {"name": "Zanzibarr Restricted", "binary": "zanzibarr-restricted",
                   "app_id": "{AB202AC6-B4A6-4C15-80A3-E3BEF7D3DE19}"},
}
POLICY = "clean-v1"
IMPORT = re.compile(r"(?:import|export|part)\s+['\"]([^'\"]+)['\"]")
FORBIDDEN = ("lib/adult/", "lib/catalog/", "lib/chat/", "lib/integrations/",
             "lib/player/", "lib/search/", "lib/main.dart", "lib/settings/settings_home.dart")

# Adding another project module to Clean requires an explicit composition review.
CLEAN_PROJECT_FILES = frozenset({
    "lib/main_clean.dart", "lib/editions/clean_app.dart",
    "lib/editions/edition.dart", "lib/editions/edition_config.dart",
    "lib/editions/content_policy.dart", "lib/editions/native_gate.dart",
    "lib/editions/native_initialization.dart",
    "lib/src/rust/api/download.dart", "lib/src/rust/api/repair.dart",
    "lib/src/rust/api/search.dart", "lib/src/rust/api/simple.dart",
    "lib/src/rust/api/streaming.dart", "lib/src/rust/frb_generated.dart",
    "lib/src/rust/frb_generated.io.dart", "lib/src/rust/frb_generated.web.dart",
})


def dart_graph(root, entry):
    pending, seen = [entry], set()
    while pending:
        relative = pending.pop()
        if relative in seen:
            continue
        path = root / relative
        if not path.is_file() or not path.resolve().is_relative_to((root / "lib").resolve()):
            raise ValueError("Invalid or missing Dart import: " + relative)
        seen.add(relative)
        source = path.read_text(encoding="utf-8")
        # Audit every URI in a real directive, including conditional imports.
        # Searching arbitrary string literals also matches documentation examples.
        directives = re.findall(r"^\s*(?:import|export|part)\s+([^;]+);", source, re.M)
        imports = [uri for directive in directives
                   for uri in re.findall(r"[\"']([^\"']+)[\"']", directive)]
        for uri in imports:
            if uri.startswith("dart:"):
                continue
            if uri.startswith("package:"):
                if not uri.startswith("package:zanzibarr/"):
                    continue
                target = root / "lib" / uri.removeprefix("package:zanzibarr/")
            else:
                target = path.parent / uri
            resolved = target.resolve()
            if not resolved.is_relative_to((root / "lib").resolve()):
                raise ValueError("Import escapes lib")
            pending.append(resolved.relative_to(root.resolve()).as_posix())
    return seen


def audit_clean(root):
    graph = dart_graph(root, "lib/main_clean.dart")
    for path in graph:
        if any(path.startswith(prefix) for prefix in FORBIDDEN):
            raise ValueError("Restricted Clean import: " + path)
        if path not in CLEAN_PROJECT_FILES:
            raise ValueError("Unreviewed Clean import: " + path)
    return graph


def prepare(root, destination, edition="clean"):
    profile = PROFILES[edition]
    root, destination = root.resolve(), destination.resolve()
    if destination.exists():
        raise ValueError("Destination already exists; candidates are immutable")
    if not destination.is_relative_to(root / "dist" / "editions"):
        raise ValueError("Destination must be under dist/editions")
    entry = "lib/main_" + edition + ".dart"
    graph = audit_clean(root) if edition == "clean" else None
    listing = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=root)
    paths = sorted(set(x.decode("utf-8") for x in listing.split(b"\0") if x))
    destination.mkdir(parents=True)
    selected = []
    for relative in paths:
        path = root / relative
        # Only explicit build inputs, never .git, tests, task notes or local state.
        allowed = (relative.startswith(("lib/", "rust/", "rust_builder/", "vendor/", "windows/", "assets/"))
                   or relative in ("pubspec.yaml", "pubspec.lock", "flutter_rust_bridge.yaml", "analysis_options.yaml", "l10n.yaml",
                                      "tools/windows/package.ps1", "tools/windows/installer.iss"))
        if edition == "restricted" and relative.startswith("lib/catalog/"):
            continue
        if not allowed or not path.is_file():
            continue
        if edition == "clean":
            if relative == "l10n.yaml":
                continue
            if relative.startswith("lib/") and relative not in graph:
                continue
            if relative.startswith("assets/legal/"):
                continue
        if path.is_symlink() or not path.resolve().is_relative_to(root):
            raise ValueError("Unexpected build input link: " + relative)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        selected.append(relative)
    def replace(relative, old, new):
        path = destination / relative
        source = path.read_text(encoding="utf-8")
        if old not in source:
            raise ValueError("Missing identity/configuration anchor in " + relative)
        path.write_text(source.replace(old, new), encoding="utf-8")
    replace("lib/editions/edition_config.dart", "'legacy'", repr(edition))
    replace("lib/editions/edition_config.dart", "ZANZIBARR_BUILD_LEGACY_POLICY_1",
            "ZANZIBARR_BUILD_" + edition.upper() + "_POLICY_1")
    replace("windows/CMakeLists.txt", 'set(BINARY_NAME "zanzibarr")',
            'set(BINARY_NAME "' + profile["binary"] + '")')
    replace("windows/runner/main.cpp", 'L"zanzibarr"', 'L"' + profile["name"] + '"')
    for old, new in [('"zanzibarr"', '"' + profile["name"] + '"'),
                     ('"zanzibarr.exe"', '"' + profile["binary"] + '.exe"')]:
        replace("windows/runner/Runner.rc", old, new)
    if edition == "restricted":
        # Explicit route composition, never rewrite application widgets/routes.
        (destination / "lib/editions/catalog_routes.dart").write_text(
            "export 'catalog_routes_restricted.dart';\n", encoding="utf-8")
        (destination / "lib/editions/catalog_routes_legacy.dart").unlink(missing_ok=True)
        dart_graph(destination, entry)
    if edition == "clean":
        # No regionless metadata, external players or restricted legal copy assets.
        p = destination / "pubspec.yaml"
        text = p.read_text(encoding="utf-8")
        text = re.sub(r"^    - assets/legal/.*\n", "", text, flags=re.M)
        text = text.replace("  generate: true", "  generate: false")
        p.write_text(text, encoding="utf-8")
        audit_clean(destination)
    # Clean denies native media; Restricted starts locked and requires a native
    # Windows authentication grant. Preserve Legacy source.
    replace("rust/src/edition.rs", 'NAME: &str = "legacy"', 'NAME: &str = "' + edition + '"')
    package = destination / "tools/windows/package.ps1"
    installer = destination / "tools/windows/installer.iss"
    if not package.is_file() or not installer.is_file():
        raise ValueError("Windows packaging inputs are missing")
    if package.is_file() and installer.is_file():
        text = package.read_text(encoding="utf-8")
        begin = text.index("    $integrations = Join-Path")
        end = text.index("    $licenses = Join-Path", begin)
        # MCP and hosted catalog guides are deliberately not bundled by either
        # new composition. Preserve CRT, native DLL and license packaging.
        text = text[:begin] + text[end:]
        text = text.replace("zanzibarr.exe", profile["binary"] + ".exe")
        text = text.replace("zanzibarr-windows-x64", profile["binary"] + "-windows-x64")
        package.write_text(text, encoding="utf-8")
        text = installer.read_text(encoding="utf-8")
        text = text.replace("C39B6F7D-9326-4E4B-B0AE-123BCB782461", profile["app_id"].strip("{}"))
        text = text.replace("zanzibarr", profile["binary"])
        text = text.replace("AppName=" + profile["binary"], "AppName=" + profile["name"])
        text = text.replace("DefaultGroupName=" + profile["binary"], "DefaultGroupName=" + profile["name"])
        installer.write_text(text, encoding="utf-8")
    hashes = {p.relative_to(destination).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in sorted(destination.rglob("*")) if p.is_file()}
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    manifest = {"schema": 1, "edition": edition, "nativeEdition": edition,
                "policy": POLICY, "platform": "windows-x64", "sourceRevision": revision,
                "sourceIncludesWorkingChanges": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=root, text=True).strip()), "entrypoint": entry,
                "identity": profile, "verification": "prepared-only",
                "releaseEligible": False, "inputs": hashes}
    (destination / "edition-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def verify(root):
    manifest = json.loads((root / "edition-manifest.json").read_text(encoding="utf-8"))
    edition = manifest["edition"]
    if (manifest["schema"] != 1 or manifest["platform"] != "windows-x64"
            or manifest["verification"] != "prepared-only" or manifest["releaseEligible"] is not False
            or manifest["entrypoint"] != "lib/main_" + edition + ".dart"
            or not re.fullmatch(r"[a-f0-9]{40}", manifest["sourceRevision"])
            or edition not in PROFILES or manifest["nativeEdition"] != edition
            or manifest["identity"] != PROFILES[edition] or manifest["policy"] != POLICY):
        raise ValueError("Edition manifest identity mismatch")
    for relative, expected in manifest["inputs"].items():
        path = (root / relative).resolve()
        if not path.is_relative_to(root.resolve()) or not path.is_file():
            raise ValueError("Missing or escaping build input")
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError("Changed build input: " + relative)
    actual = {p.relative_to(root).as_posix() for prefix in ("lib", "rust", "vendor", "windows", "assets", "rust_builder", "tools")
              for p in (root / prefix).rglob("*") if p.is_file()
              and not any(part in ("build", "target", "ephemeral", ".dart_tool") for part in p.relative_to(root).parts)}
    allowed_generated = {"edition-manifest.json", ".metadata", ".flutter-plugins-dependencies", ".flutter-plugins"}
    if any(path.is_file() and path.name not in manifest["inputs"] and path.name not in allowed_generated
           for path in root.iterdir()):
        raise ValueError("Unmanifested root configuration")
    if actual - set(manifest["inputs"]):
        raise ValueError("Unmanifested source input")
    if edition == "clean":
        audit_clean(root)
        if any((root / prefix).exists() for prefix in ("lib/adult", "lib/catalog", "lib/main.dart")):
            raise ValueError("Restricted source present in Clean")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--edition", choices=PROFILES, default="clean")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--verify", type=Path)
    args = parser.parse_args()
    if args.verify:
        manifest = verify(args.verify)
    else:
        root = Path(__file__).resolve().parents[1]
        if not args.output:
            parser.error("--output is required (a fresh directory under dist/editions)")
        manifest = prepare(root, args.output, args.edition)
    print(json.dumps({key: manifest[key] for key in ("edition", "verification", "releaseEligible", "sourceRevision")}))


if __name__ == "__main__":
    main()
