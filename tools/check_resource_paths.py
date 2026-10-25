"""Fail on res:// paths whose capitalization differs from Git (Linux export)."""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode().split("\0")
canonical = {name.lower(): name for name in tracked if name}
errors = []
for name in tracked:
    if Path(name).suffix not in {".gd", ".tscn", ".tres", ".godot"}:
        continue
    text = (root / name).read_text(encoding="utf-8-sig")
    for match in re.finditer(r'res://([^"\s]+)', text):
        path = match.group(1)
        actual = canonical.get(path.lower())
        if actual and path != actual:
            errors.append(f"{name}: res://{path} must be res://{actual}")
if errors:
    raise SystemExit("\n".join(errors))
print("PASS: tracked resource paths match Linux capitalization")
