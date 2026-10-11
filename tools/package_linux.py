"""Package the Ubuntu 24.04 x64 Flutter bundle as an installable .deb."""
import pathlib
import re
import shutil
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parent.parent
bundle = root / "build/linux/x64/release/bundle"
if not (bundle / "zanzibarr").is_file():
    raise SystemExit("Build the Linux release bundle first")
version = re.search(r"^version: (\d+\.\d+\.\d+)\+(\d+)$", (root / "pubspec.yaml").read_text(), re.M)
if not version:
    raise SystemExit("Invalid pubspec version")
output = root / "dist/linux"
output.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="zanzibarr-deb-") as temporary:
    package = pathlib.Path(temporary)
    shutil.copytree(bundle, package / "opt/zanzibarr")
    licenses = package / "opt/zanzibarr/licenses"
    licenses.mkdir(exist_ok=True)
    shutil.copy2(root / "assets/fonts/LeagueMono-OFL.txt", licenses)
    shutil.copy2(root / "vendor/unrar-sys/vendor/unrar/license.txt", licenses / "unrar-license.txt")
    control = package / "DEBIAN"
    control.mkdir()
    (control / "control").write_text(
        f"Package: zanzibarr\nVersion: {version[1]}-{version[2]}\n"
        "Architecture: amd64\nMaintainer: zanzibarr contributors\n"
        "Section: video\nPriority: optional\n"
        "Depends: libc6 (>= 2.39), libstdc++6, libgtk-3-0t64, libmpv2, libsecret-1-0, liblzma5\n"
        "Description: Seekable Usenet NZB video player\n",
        encoding="utf-8",
    )
    desktop = package / "usr/share/applications"
    desktop.mkdir(parents=True)
    (desktop / "zanzibarr.desktop").write_text(
        "[Desktop Entry]\nType=Application\nName=zanzibarr\n"
        "Exec=/opt/zanzibarr/zanzibarr\nIcon=zanzibarr\n"
        "Terminal=false\nCategories=AudioVideo;Video;\n",
        encoding="utf-8",
    )
    icon = package / "usr/share/icons/hicolor/256x256/apps"
    icon.mkdir(parents=True)
    shutil.copy2(root / "assets/zanzibarr-logo.png", icon / "zanzibarr.png")
    subprocess.run(["dpkg-deb", "--root-owner-group", "--build", str(package), str(output / "zanzibarr-linux-x64.deb")], check=True)
