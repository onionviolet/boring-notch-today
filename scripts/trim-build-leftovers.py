#!/usr/bin/env python3
"""Trim regenerable build leftovers after a verified local app update.

Dry run by default; pass --apply to delete. Policy: docs/Local-workflows.md.

Removes only things a build can recreate:
  - work/ folders whose name contains "DerivedData" or ends in "-build",
    except work/DerivedData (the documented build cache) unless --all
  - work/*.app copies and the contents of work/local-app-backups/
  - work/uv-cache
  - top-level work/*.log older than --log-days (default 14)
  - nightly source snapshots other than the SHA the nightly repo points at

With --min-age-days N it skips anything modified in the last N days, so the
nightly backstop cannot pull a build out from under a task in progress.

Never touches registered git worktrees, symlinks, evidence folders,
screenshots, patches, the installed app or anything outside those two roots.
"""
import argparse
import fcntl
from pathlib import Path
import shutil
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parent.parent
WORK = REPO / "work"
NIGHTLY = Path.home() / "Library/Application Support/boring-notch-local-build"


def size(path: Path) -> int:
    out = subprocess.run(["/usr/bin/du", "-sk", str(path)], capture_output=True, text=True).stdout
    return int(out.split()[0]) * 1024 if out.split() else 0


def worktrees() -> set[Path]:
    out = subprocess.run(["/usr/bin/git", "-C", str(REPO), "worktree", "list", "--porcelain"],
                         capture_output=True, text=True).stdout
    return {Path(line[9:]).resolve() for line in out.splitlines() if line.startswith("worktree ")}


def newest_mtime(path: Path) -> float:
    """Latest change to the path or its first two levels (cheap, good enough)."""
    newest = path.stat().st_mtime
    if path.is_dir():
        for child in path.glob("*"):
            newest = max(newest, child.lstat().st_mtime)
            if child.is_dir() and not child.is_symlink():
                newest = max([newest] + [g.lstat().st_mtime for g in child.glob("*")])
    return newest


def work_targets(keep_cache: bool, log_days: int) -> list[Path]:
    if not WORK.is_dir():
        return []
    protected = worktrees()
    cutoff = time.time() - log_days * 86400
    found = []
    for entry in sorted(WORK.iterdir()):
        if entry.is_symlink() or entry.resolve() in protected:
            continue
        name = entry.name
        if entry.is_dir():
            if name == "DerivedData" and keep_cache:
                continue
            if "DerivedData" in name or name.endswith("-build") or name.endswith(".app") or name == "uv-cache":
                found.append(entry)
            elif name == "local-app-backups":
                found.extend(sorted(child for child in entry.iterdir() if not child.is_symlink()))
        elif entry.is_file() and name.endswith(".log") and entry.stat().st_mtime < cutoff:
            found.append(entry)
    return found


def nightly_targets() -> list[Path]:
    sources = NIGHTLY / "sources"
    if not sources.is_dir():
        return []
    current = subprocess.run(["/usr/bin/git", "-C", str(NIGHTLY / "source.git"), "rev-parse", "refs/heads/local-main"],
                             capture_output=True, text=True).stdout.strip()
    if not current:
        # Without a known current snapshot, keep them all.
        return []
    return sorted(child for child in sources.iterdir()
                  if child.is_dir() and not child.is_symlink() and child.name != current)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--apply", action="store_true", help="delete instead of listing")
    parser.add_argument("--all", action="store_true", help="also remove work/DerivedData (next build is a full one)")
    parser.add_argument("--log-days", type=int, default=14)
    parser.add_argument("--min-age-days", type=float, default=0,
                        help="skip items modified within this many days (used by the nightly backstop)")
    args = parser.parse_args()

    if subprocess.run(["/usr/bin/pgrep", "-x", "xcodebuild"], capture_output=True).returncode == 0:
        print("xcodebuild is running; try again when it finishes.", file=sys.stderr)
        return 1

    targets = work_targets(keep_cache=not args.all, log_days=args.log_days)
    lock = None
    if NIGHTLY.is_dir():
        lock = (NIGHTLY / "build.lock").open("w")
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            targets += nightly_targets()
        except BlockingIOError:
            print("Nightly build is running; skipping its snapshots.", file=sys.stderr)

    if args.min_age_days > 0:
        cutoff = time.time() - args.min_age_days * 86400
        targets = [path for path in targets if newest_mtime(path) < cutoff]

    total = 0
    for path in targets:
        # Belt and braces: only ever delete inside the two known roots.
        resolved = path.resolve()
        if not (resolved.is_relative_to(WORK.resolve()) or resolved.is_relative_to(NIGHTLY.resolve())):
            print(f"skip (outside roots): {path}", file=sys.stderr)
            continue
        bytes_ = size(path)
        total += bytes_
        print(f"{'delete' if args.apply else 'would delete'} {bytes_ / 1e6:9.1f} MB  {path}")
        if args.apply:
            if path.is_dir():
                shutil.rmtree(path)
            else:
                path.unlink()
    verb = "Freed" if args.apply else "Would free"
    print(f"{verb} {total / 1e9:.2f} GB across {len(targets)} items." + ("" if args.apply else " Rerun with --apply to delete."))
    if lock:
        lock.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
