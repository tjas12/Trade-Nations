"""Export and structurally validate the Pages-compatible, offline Web build."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import struct

ROOT = Path(__file__).resolve().parents[1]


def prepare_offline_cache(output):
    worker_file = output / "index.service.worker.js"
    worker = worker_file.read_text()
    match = re.search(r"const CACHED_FILES = (\[.*?\]);", worker)
    if not match:
        raise RuntimeError("Godot service-worker format changed; review offline cache generation")
    files = json.loads(match.group(1))
    manifest = json.loads((output / "index.manifest.json").read_text())
    # Precache the whole playable build, so the first completed installation works offline.
    files += ["index.wasm", "index.pck", "index.manifest.json"]
    files += [icon["src"] for icon in manifest["icons"]]
    replacement = "const CACHED_FILES = " + json.dumps(list(dict.fromkeys(files))) + ";"
    worker = worker[:match.start()] + replacement + worker[match.end():]
    needle = "let cached = await cache.match(event.request);"
    if worker.count(needle) != 1:
        raise RuntimeError("Godot navigation cache logic changed; review offline root URL handling")
    if "Trade Nations root navigation alias" not in worker:
        worker = worker.replace(needle, needle + """
                // Trade Nations root navigation alias: Pages /Trade-Nations/ serves index.html.
                if (cached == null && isNavigate) {
                    const requested = new URL(event.request.url);
                    const scope = new URL(self.registration.scope);
                    if (requested.origin === scope.origin && requested.pathname === scope.pathname) {
                        cached = await cache.match(CACHED_FILES[0]);
                    }
                }
""")
    worker_file.write_text(worker, encoding="utf-8")


def verify(output):
    required = ["index.html", "index.js", "index.wasm", "index.pck", "index.service.worker.js", "index.manifest.json"]
    for name in required:
        file = output / name
        if not file.is_file() or not file.stat().st_size:
            raise RuntimeError(f"Missing/empty Web export: {name}")
    manifest = json.loads((output / "index.manifest.json").read_text())
    if manifest.get("display") != "standalone" or not manifest.get("orientation", "").startswith("landscape"):
        raise RuntimeError(f"Unexpected PWA display/orientation: {manifest}")
    for icon in manifest.get("icons", []):
        if not (output / icon["src"]).is_file():
            raise RuntimeError(f"Missing PWA icon: {icon['src']}")
    html = (output / "index.html").read_text()
    if re.search(r'(?:src|href)=["\']/index\.', html):
        raise RuntimeError("Root-absolute resource URL would break /Trade-Nations/ hosting")
    worker = (output / "index.service.worker.js").read_text()
    for name in ["index.pck", "index.wasm", "index.js", "index.html"]:
        if name not in worker:
            raise RuntimeError(f"Service worker does not list required resource: {name}")
    # Read the actual unencrypted PCK directory (Godot 4.7 format 4).
    pck = (output / "index.pck").read_bytes()
    magic, version = struct.unpack_from("<II", pck)
    if magic != 0x43504447 or version not in (3, 4):
        raise RuntimeError("Unexpected PCK format")
    offset = struct.unpack_from("<Q", pck, 32)[0]
    count = struct.unpack_from("<I", pck, offset)[0]
    offset += 4
    paths = []
    for _ in range(count):
        length = struct.unpack_from("<I", pck, offset)[0]
        offset += 4
        paths.append(pck[offset:offset + length].rstrip(b"\0").decode())
        offset += length + 36
    for path in paths:
        normalized = path.removeprefix("res://")
        if normalized.startswith(("original/", "research/", "tests/", "tools/", "docs/", ".validation/")):
            raise RuntimeError(f"Development/archive file leaked into PCK: {path}")
    for required in ["data/first_playable.json", "data/building_visuals.json", "data/sounds.json"]:
        if required not in [path.removeprefix("res://") for path in paths]:
            raise RuntimeError(f"Missing runtime JSON: {required}")
    print("PASS: production resources, landscape manifest, relative URLs and PWA cache list", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, default=ROOT / "export/web")
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if not args.verify_only:
        result = subprocess.run([args.godot, "--headless", "--path", str(ROOT), "--export-release", "Web - iPhone landscape", str(output / "index.html")], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=300)
        (ROOT / ".validation").mkdir(exist_ok=True)
        (ROOT / ".validation/export-web.log").write_text(result.stdout, encoding="utf-8")
        errors = [line for line in result.stdout.splitlines() if re.search(r"SCRIPT ERROR:|^ERROR:", line) and not line.startswith("ERROR: Failed to read the root certificate store.")]
        if result.returncode or errors:
            print(result.stdout)
            raise RuntimeError(f"Web export failed: exit {result.returncode}; see .validation/export-web.log")
    prepare_offline_cache(output)
    verify(output)
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    files = {p.name: {"bytes": p.stat().st_size, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in output.iterdir() if p.is_file() and p.name != "build-info.json"}
    (output / "build-info.json").write_text(json.dumps({"godot": "4.7.2.stable", "commit": revision, "base_path": "/Trade-Nations/", "files": files}, indent=2), encoding="utf-8")
    (output / ".nojekyll").touch()
    print(f"Web build ready: {output}", flush=True)


if __name__ == "__main__":
    main()
