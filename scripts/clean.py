#!/usr/bin/env python3
"""Remove generated output and only the Host downloaded by this repository."""
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
paths = [root / "build.nosync"]
tools = root / "tools"
if tools.is_symlink():
    raise SystemExit("Refusing symlinked tools directory")
marker = tools / ".gams-download-owned"
if marker.is_file():
    paths += [tools / "gams.app", tools / "gams-release-notices", marker]
for path in paths:
    if path.is_symlink():
        raise SystemExit(f"Refusing symlinked clean target: {path}")
    relative = str(path.relative_to(root))
    tracked = subprocess.check_output(["git", "-C", str(root), "ls-files", "--", relative])
    if tracked:
        raise SystemExit(f"Refusing tracked clean target: {relative}")
for path in paths:
    if path.is_dir():
        shutil.rmtree(path)
    elif path.exists():
        path.unlink()
