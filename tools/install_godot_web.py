"""Install official, checksum-pinned Godot and only its single-thread Web templates."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import urllib.request
import zipfile

VERSION = "4.7.2-stable"
BASE = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}/"
# Official release API asset digests verified on 2026-10-25.
# https://api.github.com/repos/godotengine/godot-builds/releases/tags/4.7.2-stable
ASSETS = {
    "Godot_v4.7.2-stable_linux.x86_64.zip": "cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4",
    "Godot_v4.7.2-stable_export_templates.tpz": "f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011",
}


def download(name, cache):
    target = cache / name
    if not target.exists():
        pending = target.with_suffix(target.suffix + ".partial")
        request = urllib.request.Request(BASE + name, headers={"User-Agent": "TradeNations-build"})
        with urllib.request.urlopen(request, timeout=90) as response, pending.open("wb") as output:
            shutil.copyfileobj(response, output, 4 * 1024 * 1024)
        pending.replace(target)
    with target.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    if digest != ASSETS[name]:
        raise RuntimeError(f"SHA256 mismatch for {name}: {digest}; remove the cached archive and retry")
    print(f"Verified SHA256: {name}", flush=True)
    return target


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache-dir", type=Path, required=True)
    parser.add_argument("--binary-dir", type=Path)
    parser.add_argument("--templates-dir", type=Path)
    args = parser.parse_args()
    args.cache_dir.mkdir(parents=True, exist_ok=True)
    if args.binary_dir:
        args.binary_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(download(next(iter(ASSETS)), args.cache_dir)) as archive:
            binary = args.binary_dir / "godot"
            binary.write_bytes(archive.read("Godot_v4.7.2-stable_linux.x86_64"))
            binary.chmod(0o755)
    templates = args.templates_dir or Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "godot/export_templates"
    destination = templates / "4.7.2.stable"
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(download("Godot_v4.7.2-stable_export_templates.tpz", args.cache_dir)) as archive:
        version = archive.read("templates/version.txt").decode().strip()
        if version != "4.7.2.stable":
            raise RuntimeError(f"Unexpected template version: {version}")
        for name in ["version.txt", "web_nothreads_debug.zip", "web_nothreads_release.zip"]:
            (destination / name).write_bytes(archive.read("templates/" + name))
    print(f"Installed single-thread Web templates: {destination}", flush=True)


if __name__ == "__main__":
    main()
