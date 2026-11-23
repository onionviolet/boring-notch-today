#!/usr/bin/env python3
"""Build an unsigned local Release candidate and record its source identity."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", *args], cwd=ROOT)


def source_identity() -> dict:
    revision = git("rev-parse", "HEAD").decode().strip()
    diff = git("diff", "--binary", "HEAD", "--")
    untracked = git("ls-files", "--others", "--exclude-standard", "-z").split(b"\0")[:-1]
    fingerprint = hashlib.sha256(diff)
    for name in untracked:
        path = ROOT / os.fsdecode(name)
        mode = path.lstat().st_mode
        content = os.fsencode(path.readlink()) if path.is_symlink() else path.read_bytes()
        fingerprint.update(name + b"\0" + str(mode).encode() + b"\0")
        fingerprint.update(hashlib.sha256(content).digest())
    merge_head = git("rev-parse", "--git-path", "MERGE_HEAD").decode().strip()
    merge_file = ROOT / merge_head
    return {
        "sourceCommit": revision,
        "sourceMergeHeads": merge_file.read_text().splitlines() if merge_file.exists() else [],
        "sourceDirty": bool(diff or untracked),
        "sourceChangesSHA256": fingerprint.hexdigest(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--derived-data", type=Path, default=ROOT / "work/DerivedData")
    args = parser.parse_args()
    derived = args.derived_data.resolve()
    app = derived / "Build/Products/Release/Boring Notch.app"
    receipt = app.with_suffix(".build.json")
    source = source_identity()
    label = source["sourceCommit"][:8]
    if source["sourceDirty"]:
        label += "+" + source["sourceChangesSHA256"][:8]
    xcode = subprocess.check_output(["xcodebuild", "-version"], text=True).strip()
    receipt.unlink(missing_ok=True)
    subprocess.run([
        "xcodebuild", "-project", "boringNotch.xcodeproj", "-scheme", "boringNotch",
        "-configuration", "Release", "-destination", "platform=macOS",
        "-derivedDataPath", str(derived), "-jobs", "4", "CODE_SIGNING_ALLOWED=NO",
        f"BN_SOURCE_REVISION={label}", "build",
    ], cwd=ROOT, check=True)
    if source_identity() != source:
        raise SystemExit("Source changed during the build. Rebuild to record a receipt.")
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if info.get("BNSourceRevision") != label:
        raise SystemExit("The app does not contain the expected build identity.")
    binary = app / "Contents/MacOS" / info["CFBundleExecutable"]
    body = {
        **source,
        "sourceLabel": label,
        "builtAt": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
        "xcode": xcode,
        "configuration": "Release",
        "codeSigningAllowed": False,
        "executableSHA256": hashlib.sha256(binary.read_bytes()).hexdigest(),
    }
    temporary = receipt.with_suffix(".tmp")
    temporary.write_text(json.dumps(body, indent=2) + "\n")
    temporary.replace(receipt)
    print(f"Build receipt: {receipt}", flush=True)


if __name__ == "__main__":
    main()
