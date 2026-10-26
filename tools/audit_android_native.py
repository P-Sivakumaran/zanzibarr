"""Verify pinned native JAR bytes and ELF load alignment without executing code."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile


def elf_16k(data):
    if data[:4] != b"\x7fELF" or data[5:6] != b"\x01":
        raise ValueError("Unsupported ELF encoding")
    if data[4] == 2:
        offset = struct.unpack_from("<Q", data, 32)[0]
        entry_size, count = struct.unpack_from("<HH", data, 54)
        minimum, fmt, fields = 56, "<Q", (8, 16, 48)
    elif data[4] == 1:
        offset = struct.unpack_from("<I", data, 28)[0]
        entry_size, count = struct.unpack_from("<HH", data, 42)
        minimum, fmt, fields = 32, "<I", (4, 8, 28)
    else:
        raise ValueError("Unsupported ELF class")
    if entry_size < minimum or count == 0 or count > 1024 or offset + entry_size * count > len(data):
        raise ValueError("Invalid ELF program headers")
    loads = []
    for index in range(count):
        header = offset + index * entry_size
        if struct.unpack_from("<I", data, header)[0] != 1:
            continue
        file_offset, virtual, alignment = [struct.unpack_from(fmt, data, header + field)[0] for field in fields]
        loads.append(alignment >= 16384 and alignment & (alignment - 1) == 0 and file_offset % 16384 == virtual % 16384)
    return bool(loads) and all(loads)


def audit(manifest_path, directory):
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("schema") != 1:
        raise ValueError("Unknown native manifest schema")
    results = []
    for name, expected in manifest["artifacts"].items():
        if Path(name).name != name or not name.endswith(".jar"):
            raise ValueError("Unsafe native artifact name")
        artifact = directory / name
        if artifact.stat().st_size != expected["size"] or hashlib.sha256(artifact.read_bytes()).hexdigest() != expected["sha256"]:
            raise ValueError("Pinned artifact mismatch: " + name)
        with zipfile.ZipFile(artifact) as archive:
            libraries = [entry for entry in archive.infolist() if entry.filename.endswith(".so")]
            if not libraries:
                raise ValueError("Native artifact contains no libraries")
            for entry in libraries:
                if entry.file_size > 128 * 1024 * 1024:
                    raise ValueError("Native library exceeds inspection limit")
                data = archive.read(entry)
                results.append({"artifact": name, "library": entry.filename,
                                "sha256": hashlib.sha256(data).hexdigest(), "elf16k": elf_16k(data), "requires16k": data[4] == 2})
    return {"schema": 1, "release": manifest["release"], "pinVerification": "passed",
            "elf16k": all(not result["requires16k"] or result["elf16k"] for result in results), "libraries": results,
            "deviceValidated": False, "publisherAuthenticated": False}


def audit_apk(path):
    results = []
    with zipfile.ZipFile(path) as archive, path.open("rb") as raw:
        for entry in archive.infolist():
            if not entry.filename.endswith(".so"):
                continue
            if entry.file_size > 128 * 1024 * 1024:
                raise ValueError("Native library exceeds inspection limit")
            data = archive.read(entry)
            raw.seek(entry.header_offset + 26)
            name_size, extra_size = struct.unpack("<HH", raw.read(4))
            data_offset = entry.header_offset + 30 + name_size + extra_size
            aligned_zip = entry.compress_type != zipfile.ZIP_STORED or data_offset % 16384 == 0
            results.append({"library": entry.filename, "sha256": hashlib.sha256(data).hexdigest(),
                            "elf16k": elf_16k(data), "zip16k": aligned_zip, "requires16k": data[4] == 2})
    if not results:
        raise ValueError("APK contains no native libraries")
    return {"schema": 1, "apk": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "elf16k": all(not row["requires16k"] or (row["elf16k"] and row["zip16k"]) for row in results),
            "libraries": results, "deviceValidated": False, "publisherAuthenticated": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=Path("vendor/media_kit_libs_android_video/native-artifacts.json"))
    inputs = parser.add_mutually_exclusive_group(required=True)
    inputs.add_argument("--directory", type=Path)
    inputs.add_argument("--apk", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    result = audit_apk(args.apk) if args.apk else audit(args.manifest, args.directory)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if not result["elf16k"]:
        raise SystemExit("Native ELF 16 KiB alignment failed; do not promote Android artifacts")
    print("Pinned artifacts and", len(result["libraries"]), "ELF libraries passed; device validation still required")

if __name__ == "__main__":
    main()
