#!/usr/bin/env python3
"""Build the fork's current remote main without touching a worktree."""
import fcntl
import os
from pathlib import Path
import subprocess
import sys

base = Path.home() / "Library/Application Support/boring-notch-local-build"
base.mkdir(parents=True, exist_ok=True)
bare = base / "source.git"
with (base / "build.lock").open("w") as lock:
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("A local build is already running.", file=sys.stderr)
        sys.exit(1)
    if not bare.exists():
        subprocess.run(["/usr/bin/git", "init", "--bare", str(bare)], check=True)
    subprocess.run(["/usr/bin/git", "-C", str(bare), "fetch", "--no-tags", "https://github.com/onionviolet/boring-notch-today.git", "+refs/heads/main:refs/heads/local-main"], check=True)
    sha = subprocess.check_output(["/usr/bin/git", "-C", str(bare), "rev-parse", "refs/heads/local-main"], text=True).strip()
    source = base / "sources" / sha
    marker = source / ".local-snapshot-complete"
    if not marker.exists():
        source.mkdir(parents=True, exist_ok=True)
        archive = subprocess.Popen(["/usr/bin/git", "-C", str(bare), "archive", sha], stdout=subprocess.PIPE)
        extracted = subprocess.run(["/usr/bin/tar", "-x", "-C", str(source)], stdin=archive.stdout)
        archive.stdout.close()
        if extracted.returncode or archive.wait():
            sys.exit("Could not extract the source snapshot")
        marker.touch()
    print(f"Building remote main {sha} without code signing", flush=True)
    result = subprocess.run(["/usr/bin/xcodebuild", "-project", "boringNotch.xcodeproj", "-scheme", "boringNotch", "-configuration", "Release", "-derivedDataPath", str(base / "DerivedData"), "-jobs", "2", "CODE_SIGNING_ALLOWED=NO", "build"], cwd=source)
    sys.exit(result.returncode)
