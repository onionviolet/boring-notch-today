# Today integration

This fork adds a compact, read-only Today tab. The planning vault remains the only task authority. The tab has no completion action and cannot scan, write, or infer vault content. A narrow local MCP server lets an authorized AI publish validated snapshots without putting MCP, a network listener, or a general tool runner inside the app.

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

Open the notch and choose the calendar tab. The app watches the Today directory and debounces filesystem events for prompt reloads after atomic replacement. It also rereads every 15 seconds as a fallback. The watcher is only a hint: every reload repeats the symlink, size, schema, and action checks, and a rejected update leaves the last valid snapshot visible.

## Connect the local MCP server

The server uses the official Python MCP SDK over stdio. `uv` resolves its pinned major-version dependency from the script metadata, so it opens no listening port and needs no API key or credential:

```bash
codex mcp add boring-notch-today -- uv run /absolute/path/to/boring-notch-today/scripts/boring-notch-today-mcp.py
codex mcp list
```

Restart the Codex client after adding it. The server exposes only `publish_today`, `today_status`, and `pending_today_refresh`, plus the read-only `boring-notch://today/status` resource. An authorized AI can call `publish_today` with a schema-v1 object and optionally the matching refresh-request ID. The tool reuses the same validator and atomic publisher as the CLI.

The UI status is literal:

- **Connected** means at least one local Codex MCP transport is active. When several tasks are open,
  they elect one heartbeat writer so the shared status file is not rewritten by every process.
- **Refresh requested, waiting for agent** means the sidecar reports an outstanding bounded request.
- **Offline** or **Connection inactive** means the validated file fallback still works.
- **Connection needs attention** means the app rejected the status record; it does not display raw bridge errors.

The heartbeat starts with the MCP transport, preserves the last successful publication time, and naturally
becomes stale within 15 seconds after the final transport exits. No persistent daemon or network listener is used.

The Refresh button writes only a bounded local request containing schema version, UUID, timestamp, and the fixed source name. It does not include a prompt, path, command, URL, credential, or vault text. A connected or scheduled AI workflow must still call `pending_today_refresh`, read only sources it is separately authorized to use, and publish a replacement. MCP notifications and marker creation do not wake an absent or idle agent by themselves.

The developer-only `--today-preview-window` argument renders the same `TodayView` used inside the notch.
Start and the update age stay above the scrollable task list. Task rows expand to show their purpose, method, urgency, completion criteria, and basis. Hover over the connection label for technical details.

Today opens at 640 × 300 points; the other tabs retain their 640 × 190 size. Switching tabs resizes the panel. The Today view fills the available width and height below the tab bar, keeping the scroll viewport inside the rounded bottom edge. Long time labels wrap in a trailing column rather than squeezing task titles.

The Today pane remembers its last scroll position and restores it after the pane or app is reopened, so details such as assigned page ranges stay where the reader left them.

## Contract v1

The publisher and MCP tool accept at most 64 KiB of UTF-8 JSON and write it to:

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

`basis` is `OFFICIAL`, `PLAN`, or `INFERENCE`. Each row includes Work, Purpose, Study method, Done when, Time, Why now, and Basis. `generatedAt` becomes visibly stale after 12 hours and cannot be more than five minutes in the future. An empty `rows` array is a valid no-work state. Unknown fields, more than three actions, unsupported, malformed, oversized, or unsafe data are rejected.

Anki is explicit: `available` can carry `reviewedToday` and `newCards`; `unavailable` renders “Anki is not running” and does not pretend counts are zero.

## Feature backlog

### Timed Today deadline banners

Requested October 12, 2026. Status: backlog, not implemented.

Show a banner in the notch when a Today deadline's reminder time arrives, without requiring the user to open the Today tab. Use explicit deadline and reminder timestamps published from the planning vault, which remains the task authority. Required work and optional work should be visibly distinct.

Example: for CSCI Lab 05 and the two optional extra-credit uploads due October 12 at 22:00 Eastern, show a 19:00 preparation reminder and a 21:30 final submission reminder. The banner should name the work, show the deadline and offer a route to its Today card or source.

Acceptance: banners appear once at each configured time while the app is running; dismissing or snoozing never marks work complete. Define behavior for sleep/wake, app restart, changed or removed deadlines, stale snapshots and multiple reminders due together before implementation. Keep scheduling local and avoid duplicate banners after a refresh. Sound and native macOS notification fallback are optional design choices, not requirements yet. The payload schema needs an explicit extension; free-text card labels must not become scheduling inputs.

### Related Today features

Saved to the backlog at the user's request October 12, 2026. All five remain unimplemented. O1 and O2 are the first candidates alongside timed banners; O3 belongs with banner reliability. This order is a recommendation, not an implementation schedule.

| ID | Feature | Intended behavior | Acceptance or design boundary |
|---|---|---|---|
| O1 | Deadline countdown | Show a compact countdown in the closed notch, such as `CS Lab · 2h 15m left`. Put required work ahead of optional work. | Use explicit deadline timestamps; handle expired, changed and stale deadlines without implying completion. |
| O2 | Submission checkpoint | Before cutoff, remind the user to check all required files and the final receipt, with a button to open the submission site. | Opening the site or dismissing the checkpoint never counts as submission or completion. |
| O3 | Wake-up catch-up | After sleep or app restart, combine missed reminders into one useful banner instead of replaying each one. | Coalesce reminders and avoid duplicates; distinguish an upcoming deadline from one already passed. |
| O4 | Per-task focus timer | Start a 25-minute work session from a Today card and show the task and remaining time in the notch. | Timer state is local session state; finishing a timer never marks the vault task complete. |
| O5 | Quiet hours and urgency | Suppress routine nudges during class or recovery, while allowing explicitly chosen hard-deadline alerts through. | Let the user choose quiet periods and which alerts may interrupt; optional work does not become urgent automatically. |

## Action boundary

Only two payload action kinds exist. A `source` action requires HTTPS with a host and rejects local paths, custom schemes, and URL credentials. `itembank` carries no path, command, or URL. It asks macOS to launch only the fixed bundle identifier `dev.itembank`; if that app is absent, the tab reports it as unavailable. Neither action can mark work complete.

The refresh request and bounded heartbeat are stored beside the payload as `refresh-request.json` and `bridge-status.json`. All three records are owner-only. The MCP process heartbeat is a connection indicator, not task authority or content.

The local user account is the trust boundary. Symlink, owner, regular-file, link-count, permission, schema, and size checks prevent accidental or cross-user substitution, but another process already running as the same macOS user can still race filesystem checks. The MCP SDK parses the stdio request before the bridge applies its 64 KiB payload limit, so configure this server only for trusted local Codex clients.

## Verification

```bash
python3 -m unittest -v tests/test_publisher.py tests/test_bridge.py
uv run --with 'mcp>=2,<3' python tests/mcp_smoke.py
swiftc boringNotch/components/Today/TodayPayload.swift boringNotch/components/Today/TodayBridgeStatus.swift tests/TodayPayloadTests.swift -o work/today-tests
work/today-tests
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release build
```

## Rollback and upstream sync

To clear the view, quit Boring Notch and move `payload.json` to a backup location; the next launch shows the empty state. To restore a previous plan, republish the saved JSON through the validator. Do not edit the live file in place. Remove the `boring-notch-today` MCP entry with the Codex MCP settings or CLI when the bridge is no longer wanted.

Keep `upstream` pointed at `https://github.com/TheBoredTeam/boring.notch.git`. Before an upstream merge, fetch it, build the integration branch, merge or rebase deliberately, resolve the three Today wiring points (`NotchViews`, `TabSelectionView`, and `ContentView`), then rerun the focused payload test and release build. This derivative remains GPL-3.0 under the upstream `LICENSE`; retain upstream notices and provide corresponding source when distributing builds.

The notch layout anchors its content at the top. Today receives the panel height
minus the header and bottom inset, so long plans scroll inside the remaining
space rather than pushing the tab row above the display.
