#!/usr/bin/env python3
"""Install a built Boring Notch over /Applications, verify it, then clean up.

One command so the cleanup cannot be skipped: stage the candidate, quit the
running app, swap, launch, watch for 20 s, check for crash reports, delete the
previous copy, then run trim-build-leftovers.py --apply. If any step fails the
previous app is kept under work/install-<stamp>/previous.app and nothing is
trimmed. Run only for an update the user asked for. Policy: CLAUDE.md and
docs/Local-workflows.md.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parent.parent
INSTALLED = Path("/Applications/Boring Notch.app")
DEFAULT_CANDIDATE = REPO / "work/DerivedData/Build/Products/Release/Boring Notch.app"
QUIT = ('import AppKit; for app in NSWorkspace.shared.runningApplications '
        f'where app.bundleURL?.path == "{INSTALLED}" {{ guard app.terminate() else {{ exit(1) }} }}')


def now() -> str:
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def binary(bundle: Path) -> Path:
    info = plistlib.loads((bundle / "Contents/Info.plist").read_bytes())
    return bundle / "Contents/MacOS" / info["CFBundleExecutable"]


def manifest(bundle: Path) -> dict:
    result = {}
    for parent, dirs, files in os.walk(bundle, followlinks=False):
        for name in dirs + files:
            path = Path(parent) / name
            key = str(path.relative_to(bundle))
            if path.is_symlink():
                result[key] = ["link", os.readlink(path)]
            elif path.is_file():
                result[key] = ["file", digest(path)]
            else:
                result[key] = ["directory"]
    return result


def pids() -> list[int]:
    target = str(binary(INSTALLED)) if INSTALLED.exists() else str(INSTALLED / "Contents/MacOS/Boring Notch")
    found = []
    for line in subprocess.check_output(["/bin/ps", "-axo", "pid=,command="], text=True).splitlines():
        row = line.strip().split(None, 1)
        if len(row) == 2 and (row[1] == target or row[1].startswith(target + " ")):
            found.append(int(row[0]))
    return found


def wait(condition, seconds: float) -> bool:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if condition():
            return True
        time.sleep(0.25)
    return condition()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--candidate", type=Path, default=DEFAULT_CANDIDATE)
    parser.add_argument("--no-trim", action="store_true", help="skip the build-leftover trim after success")
    args = parser.parse_args()

    candidate = args.candidate.resolve()
    if not (candidate / "Contents/Info.plist").is_file():
        sys.exit(f"No built app at {candidate}")
    if not INSTALLED.is_dir():
        sys.exit(f"{INSTALLED} is missing; this script only replaces an existing install")

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    folder = REPO / "work" / f"install-{stamp}"
    folder.mkdir(parents=True)
    staged = INSTALLED.parent / f".Boring-Notch-staged-{stamp}.app"
    backup = folder / "previous.app"
    receipt = {
        "candidate": str(candidate),
        "startedAt": now(),
        "executableSHA256": digest(binary(candidate)),
        "previousExecutableSHA256": digest(binary(INSTALLED)),
        "sourceCommit": subprocess.run(["/usr/bin/git", "-C", str(REPO), "rev-parse", "HEAD"],
                                       capture_output=True, text=True).stdout.strip(),
        "sourceDirty": bool(subprocess.run(["/usr/bin/git", "-C", str(REPO), "status", "--porcelain"],
                                           capture_output=True, text=True).stdout.strip()),
    }

    def save() -> None:
        (folder / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")

    def fail(message: str) -> int:
        receipt["failure"] = message
        receipt["previousCopyPreserved"] = backup.exists()
        save()
        if staged.exists():
            shutil.rmtree(staged)
        where = f" Previous app kept at {backup}." if backup.exists() else " Installed app was not touched."
        print(f"FAILED: {message}.{where} Nothing trimmed.", file=sys.stderr)
        return 1

    save()
    subprocess.run(["/usr/bin/ditto", str(candidate), str(staged)], check=True)
    wanted = manifest(candidate)
    if manifest(staged) != wanted:
        return fail("staged bundle differs from the candidate")

    subprocess.run(["/usr/bin/swift", "-e", QUIT], check=False)
    if not wait(lambda: not pids(), 15):
        return fail("the running app did not quit")

    shutil.move(str(INSTALLED), str(backup))
    staged.rename(INSTALLED)
    if manifest(INSTALLED) != wanted:
        return fail("installed bundle differs from the candidate")
    installed_at = time.time()
    receipt["installedAt"] = now()
    save()

    subprocess.run(["/usr/bin/open", "-a", str(INSTALLED)], check=False)
    if not wait(pids, 15):
        return fail("the replacement did not launch")
    launched = pids()
    receipt["launchedPIDs"] = launched
    time.sleep(20)
    if not all(pid in pids() for pid in launched):
        return fail("the replacement exited during the 20 s launch check")
    crashes = []
    for directory in (Path.home() / "Library/Logs/DiagnosticReports", Path("/Library/Logs/DiagnosticReports")):
        if directory.is_dir():
            crashes += [str(p) for p in directory.iterdir()
                        if p.is_file() and p.name.lower().startswith(("boring notch", "boringnotch"))
                        and p.stat().st_mtime >= installed_at]
    if crashes:
        return fail(f"new crash reports: {crashes}")

    shutil.rmtree(backup)
    receipt["previousCopyDeleted"] = True
    receipt["verifiedAt"] = now()
    save()
    print(f"Installed and launch-checked. Receipt: {folder / 'receipt.json'}", flush=True)

    if not args.no_trim:
        trim = subprocess.run([sys.executable, str(REPO / "scripts/trim-build-leftovers.py"), "--apply"])
        receipt["trimExitStatus"] = trim.returncode
        save()
    return 0


if __name__ == "__main__":
    sys.exit(main())
