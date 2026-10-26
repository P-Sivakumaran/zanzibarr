"""Audit a Windows edition bundle; never installs, publishes or authenticates."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import sys
from prepare_edition import verify, PROFILES

RESTRICTED_ENDPOINTS = (b"theporndb.net", b"stashdb.org", b"eporner.com", b"papi.rest", b"porn-xnxx")


def validate_aot_marker(aot, edition):
    for profile in ("legacy", "clean", "restricted"):
        marker = "ZANZIBARR_BUILD_" + profile.upper() + "_POLICY_1"
        present = marker.encode() in aot or marker.encode("utf-16le") in aot
        if present != (profile == edition):
            raise ValueError("Dart edition marker mismatch")


def audit(source, bundle):
    manifest = verify(source)
    source_manifest = (source / "edition-manifest.json").read_bytes()
    if (bundle / "edition-manifest.json").read_bytes() != source_manifest:
        raise ValueError("Bundled source manifest mismatch")
    edition = manifest["edition"]
    binary = PROFILES[edition]["binary"]
    required = (binary + ".exe", "flutter_windows.dll", "rust_lib_zanzibarr.dll", "data/app.so")
    for relative in required:
        if not (bundle / relative).is_file():
            raise ValueError("Missing bundle component: " + relative)
    if sys.platform != "win32":
        raise ValueError("Native Windows DLL audit requires a Windows host")
    native = ctypes.CDLL(str((bundle / "rust_lib_zanzibarr.dll").resolve()))
    native.zanzibarr_edition_code.restype = ctypes.c_uint32
    native.zanzibarr_policy_version.restype = ctypes.c_uint32
    if native.zanzibarr_edition_code() != {"clean": 1, "restricted": 2}[edition]:
        raise ValueError("Built native edition does not match Dart/source profile")
    if native.zanzibarr_policy_version() != 1:
        raise ValueError("Native policy version mismatch")
    hashes = {}
    for path in sorted(bundle.rglob("*")):
        if not path.is_file():
            continue
        data = path.read_bytes()
        if edition == "clean":
            lowered = data.lower()
            for endpoint in RESTRICTED_ENDPOINTS:
                if endpoint in lowered or endpoint.decode().encode("utf-16le") in lowered:
                    raise ValueError("Restricted endpoint in Clean artifact: " + path.name)
        hashes[path.relative_to(bundle).as_posix()] = hashlib.sha256(data).hexdigest()
    aot = (bundle / "data/app.so").read_bytes()
    # All edition configuration is compiled into Dart, not supplied by an
    # environment variable that could switch a deployed binary at runtime.
    validate_aot_marker(aot, edition)
    return {"schema": 1, "edition": edition, "policy": manifest["policy"],
            "sourceRevision": manifest["sourceRevision"],
            "sourceManifestSha256": hashlib.sha256(source_manifest).hexdigest(),
            "verification": "bundle-audited",
            "releaseEligible": False, "artifacts": hashes}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    report = audit(args.source, args.bundle)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(report["edition"], report["verification"], len(report["artifacts"]), "files; not release eligible")


if __name__ == "__main__":
    main()
