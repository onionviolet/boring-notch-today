# Today integration

This fork adds a compact, read-only Today tab. The planning vault remains the only task authority. The tab has no completion action and cannot scan, write, or infer vault content.

## Install and run

Build with the supported project command:

```bash
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release build
```

On the development Mac used for this fork, that signed build completes, but launching it directly can hit an upstream `MediaRemoteAdapter` Team-ID mismatch. For a local visual test without changing the project signing configuration, build and launch an unsigned copy:

```bash
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release CODE_SIGNING_ALLOWED=NO build
open ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Release/boringNotch.app --args --today-preview-window
```

Create a starting payload and publish it atomically:

```bash
python3 scripts/boring-notch-today.py sample --output /tmp/today.json
python3 scripts/boring-notch-today.py publish --input /tmp/today.json
```

Open the notch and choose the calendar tab. The app rereads its payload on opening and every 15 seconds. The Refresh button writes only a local refresh-request marker. A Codex workflow may notice that marker and publish a new payload, but the app never calls or changes the planning vault.

The developer-only `--today-preview-window` argument renders the same `TodayView` used inside the notch.

## Contract v1

The publisher accepts at most 64 KiB of UTF-8 JSON and writes it to:

```text
~/Library/Application Support/boring.notch/Today/payload.json
```

The parent directory is owner-only (`0700`) and the payload is owner-only (`0600`). Both publisher and app reject symlinked storage, and the app independently enforces the 64 KiB limit. The publisher validates in memory, fsyncs a temporary file in the same directory, then atomically replaces the old payload. A failed publish leaves the prior payload in place.

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-09-13T16:00:00Z",
  "rows": [{
    "id": "stable-row-id",
    "work": "Work", "purpose": "Purpose", "studyMethod": "Study method",
    "doneWhen": "Done when", "time": "25 min", "whyNow": "Why now",
    "basis": "OFFICIAL"
  }],
  "next": "Future trigger",
  "protected": "unscheduled",
  "start": "One action to begin",
  "anki": { "status": "unavailable" },
  "actions": [
    { "id": "source", "label": "Open source", "kind": "source", "url": "https://example.edu" },
    { "id": "itembank", "label": "Open Itembank", "kind": "itembank" }
  ]
}
```

`basis` is `OFFICIAL`, `PLAN`, or `INFERENCE`. Each row includes Work, Purpose, Study method, Done when, Time, Why now, and Basis. `generatedAt` becomes visibly stale after 12 hours. An empty `rows` array is a valid no-work state. Unsupported, malformed, oversized, or unsafe data shows no rows or actions.

Anki is explicit: `available` can carry `reviewedToday` and `newCards`; `unavailable` renders “Anki is not running” and does not pretend counts are zero.

## Action boundary

Only two payload action kinds exist. A `source` action requires HTTPS with a host and rejects local paths, custom schemes, and URL credentials. `itembank` carries no path, command, or URL. It asks macOS to launch only the fixed bundle identifier `dev.itembank`; if that app is absent, the tab reports it as unavailable. Neither action can mark work complete.

The refresh request is stored beside the payload as `refresh-request.json`. It contains only the request timestamp and source name, not vault data.

## Rollback and upstream sync

To clear the view, quit Boring Notch and move `payload.json` to a backup location; the next launch shows the empty state. To restore a previous plan, republish the saved JSON through the validator. Do not edit the live file in place.

Keep `upstream` pointed at `https://github.com/TheBoredTeam/boring.notch.git`. Before an upstream merge, fetch it, build the integration branch, merge or rebase deliberately, resolve the three Today wiring points (`NotchViews`, `TabSelectionView`, and `ContentView`), then rerun the focused payload test and release build. This derivative remains GPL-3.0 under the upstream `LICENSE`; retain upstream notices and provide corresponding source when distributing builds.
