#!/usr/bin/env python3
"""Publish a bounded, read-only Today payload for Boring Notch."""
import argparse, json, pathlib, sys

from today_bridge import now_string, publish_payload

def publish(input_path):
    data = json.loads(pathlib.Path(input_path).read_bytes())
    print(publish_payload(data))
def sample(output):
    now = now_string()
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
