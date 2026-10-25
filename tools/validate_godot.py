"""Cross-platform regression runner with fresh per-scene save profiles."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LOGS = ROOT / ".validation"


def run(godot, name, arguments, profile):
    env = os.environ.copy()
    for key, directory in {"APPDATA": "roaming", "LOCALAPPDATA": "local", "XDG_DATA_HOME": "data", "XDG_CONFIG_HOME": "config", "XDG_CACHE_HOME": "cache"}.items():
        path = profile / name / directory
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    result = subprocess.run([godot, "--path", str(ROOT), *arguments], cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=180)
    (LOGS / f"{name}.log").write_text(result.stdout, encoding="utf-8")
    errors = [line for line in result.stdout.splitlines() if re.search(r"SCRIPT ERROR:|^ERROR:|\] FAIL:", line) and not re.search(r"^ERROR: Failed to read the root certificate store\.$|^ERROR: \d+ resources still in use at exit", line)]
    if result.returncode or errors:
        print(result.stdout, flush=True)
        raise RuntimeError(f"{name} failed, exit {result.returncode}; see .validation/{name}.log")
    print(f"PASS {name}", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--graphical", action="store_true")
    args = parser.parse_args()
    LOGS.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="trade-nations-checks-") as temporary:
        profile = Path(temporary)
        run(args.godot, "import", ["--headless", "--editor", "--import", "--quit"], profile)
        scenes = {"foundation": "TestRunner", "restoration": "RestorationTests", "interaction": "InteractionTests", "playable": "PlayableTests", "scale": "ScaleTests", "layout": "LayoutTests", "mobile": "MobileTests"}
        for name, scene in scenes.items():
            run(args.godot, name, ["--headless", f"res://tests/{scene}.tscn"], profile)
        run(args.godot, "startup", ["--headless", "--quit-after", "120"], profile)
        if args.graphical:
            for name in ["restoration", "interaction", "mobile"]:
                run(args.godot, name + "-graphical", ["--rendering-method", "gl_compatibility", f"res://tests/{scenes[name]}.tscn"], profile)


if __name__ == "__main__":
    main()
