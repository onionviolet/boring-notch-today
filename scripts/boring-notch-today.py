#!/usr/bin/env python3
"""Publish a bounded, read-only Today payload for Boring Notch."""
import argparse, datetime as dt, json, os, pathlib, re, sys, tempfile, urllib.parse

ROOT = pathlib.Path.home() / "Library/Application Support/boring.notch/Today"
PAYLOAD = ROOT / "payload.json"
MAX_BYTES = 64 * 1024
REQUIRED = ("id", "work", "purpose", "studyMethod", "doneWhen", "time", "whyNow", "basis")
RFC3339 = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$")

def invalid(message): raise ValueError(message)
def text(value, name):
    if not isinstance(value, str) or not value.strip() or len(value) > 500: invalid(f"invalid {name}")
def validate(data):
    if not isinstance(data, dict) or data.get("schemaVersion") != 1: invalid("schemaVersion must be 1")
    try:
        if not isinstance(data["generatedAt"], str) or not RFC3339.fullmatch(data["generatedAt"]): invalid("generatedAt must include time and timezone")
        dt.datetime.fromisoformat(data["generatedAt"].replace("Z", "+00:00"))
    except (KeyError, TypeError, ValueError): invalid("generatedAt must be ISO-8601")
    rows = data.get("rows")
    if not isinstance(rows, list) or len(rows) > 5: invalid("rows must contain zero to five entries")
    for row in rows:
        if not isinstance(row, dict): invalid("each row must be an object")
        for key in REQUIRED: text(row.get(key), f"row.{key}")
        if row["basis"] not in ("OFFICIAL", "PLAN", "INFERENCE"): invalid("row.basis is invalid")
    if len({row["id"] for row in rows}) != len(rows): invalid("row ids must be unique")
    for key in ("next", "protected", "start"):
        if key in data and data[key] is not None: text(data[key], key)
    anki = data.get("anki")
    if anki is not None and (not isinstance(anki, dict) or anki.get("status") not in ("available", "unavailable")): invalid("anki.status is invalid")
    if anki is not None:
        counts = (anki.get("reviewedToday"), anki.get("newCards"))
        if anki["status"] == "available" and any(type(value) is not int or value < 0 for value in counts): invalid("available Anki requires nonnegative integer counts")
        if anki["status"] == "unavailable" and any(value is not None for value in counts): invalid("unavailable Anki must omit counts")
    actions = data.get("actions")
    if not isinstance(actions, list): invalid("actions must be an array")
    for action in actions:
        if not isinstance(action, dict): invalid("each action must be an object")
        for key in ("id", "label", "kind"): text(action.get(key), f"action.{key}")
        url, kind = action.get("url"), action["kind"]
        parsed = urllib.parse.urlsplit(url) if isinstance(url, str) else None
        if kind == "source" and (parsed is None or parsed.scheme != "https" or not parsed.hostname or parsed.username is not None or parsed.password is not None): invalid("source actions require safe https")
        if kind == "itembank" and url is not None: invalid("itembank actions do not accept a URL")
        if kind not in ("source", "itembank"): invalid("action.kind is invalid")
    if len({action["id"] for action in actions}) != len(actions): invalid("action ids must be unique")
def publish(input_path):
    raw = pathlib.Path(input_path).read_bytes()
    if len(raw) > MAX_BYTES: invalid("payload exceeds 64 KiB")
    data = json.loads(raw)
    validate(data)
    if ROOT.parent.is_symlink() or ROOT.is_symlink() or PAYLOAD.is_symlink(): invalid("refusing symlinked Today storage")
    ROOT.mkdir(mode=0o700, parents=True, exist_ok=True)
    ROOT.chmod(0o700)
    with tempfile.NamedTemporaryFile(dir=ROOT, prefix="payload.", delete=False) as handle:
        handle.write(json.dumps(data, separators=(",", ":"), ensure_ascii=False).encode())
        handle.flush(); os.fsync(handle.fileno()); temp = pathlib.Path(handle.name)
    temp.chmod(0o600); os.replace(temp, PAYLOAD)
    print(PAYLOAD)
def sample(output):
    now = dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")
    data = {"schemaVersion":1,"generatedAt":now,"rows":[{"id":"example","work":"Example work","purpose":"Show the notch payload","studyMethod":"Read and act","doneWhen":"The sample is visible","time":"5 min","whyNow":"Verifies the local bridge","basis":"PLAN"}],"next":"Replace this sample with the canonical Today output.","protected":"unscheduled","start":"Run the publisher with a real bounded payload.","anki":{"status":"unavailable"},"actions":[{"id":"source","label":"Source","kind":"source","url":"https://github.com/onionviolet/boring-notch-today"},{"id":"itembank","label":"Open Itembank","kind":"itembank"}]}
    pathlib.Path(output).write_text(json.dumps(data, indent=2) + "\n")
def main():
    parser = argparse.ArgumentParser(); sub = parser.add_subparsers(dest="command", required=True)
    pub = sub.add_parser("publish"); pub.add_argument("--input", required=True)
    sam = sub.add_parser("sample"); sam.add_argument("--output", required=True)
    args = parser.parse_args()
    try: publish(args.input) if args.command == "publish" else sample(args.output)
    except (OSError, ValueError, json.JSONDecodeError) as error: print(f"error: {error}", file=sys.stderr); return 2
    return 0
if __name__ == "__main__": raise SystemExit(main())
