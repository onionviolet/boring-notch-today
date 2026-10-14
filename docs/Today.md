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

## Contract v1 and v2

The publisher and MCP tool accept schema v1 or v2 and at most 64 KiB of UTF-8 JSON and write it to:

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

Requested October 12, 2026. Implemented in source with schema v2; local test/build gates are recorded below. Installed-app and physical-notch acceptance remain open.

Show a banner in the notch when a Today deadline's reminder time arrives, without requiring the user to open the Today tab. Use explicit deadline and reminder timestamps published from the planning vault, which remains the task authority. Required work and optional work should be visibly distinct.

Example: for CSCI Lab 05 and the two optional extra-credit uploads due October 12 at 22:00 Eastern, show a 19:00 preparation reminder and a 21:30 final submission reminder. The banner should name the work, show the deadline and offer a route to its Today card or source.

Due reminders appear as a compact indicator beside the closed hardware notch. Full reminder controls stay inside Today’s scroll area, rather than overlaying other tabs. They offer Today, a validated HTTPS site when supplied, Dismiss and Snooze 10 min. Neither dismissal, opening a site nor finishing a focus timer marks work complete. Submission checkpoints explicitly ask the user to verify required files and the final receipt. There is no sound or native notification fallback.

Schema v2 adds an optional `deadlines` array; v1 remains accepted and cannot include this field. Example extension, alongside the existing rows/actions:

```json
{
  "schemaVersion": 2,
  "deadlines": [{
    "id": "lab-05-deadline",
    "rowID": "stable-row-id",
    "dueAt": "2026-10-12T22:00:00-04:00",
    "required": true,
    "actionID": "source",
    "reminders": [
      {"id": "prep", "at": "2026-10-12T19:00:00-04:00", "kind": "preparation"},
      {"id": "submit", "at": "2026-10-12T21:30:00-04:00", "kind": "checkpoint"}
    ]
  }]
}
```

This is an extension fragment, not a complete publishable payload. Up to five deadlines are allowed, with four reminders each. Deadline IDs and reminder IDs are nonempty, unique within their respective arrays, and at most 100 characters. Each deadline references an existing row; `required` is an explicit boolean. Reminder timestamps must include seconds and a timezone and cannot fall after cutoff. `actionID`, when supplied, references an existing HTTPS source action; checkpoints require it. Unknown fields and unsupported reminder kinds are rejected independently by publisher and app. Free-text labels never determine timing.

Local behavior:

| Condition | Behavior |
|---|---|
| Running app | Evaluate every second; coalesce all eligible reminders into one banner with one entry per deadline. Required work appears first. |
| Sleep/wake or restart | Re-evaluate explicit timestamps. Undelivered reminders catch up together until one hour after cutoff; passed deadlines say “Deadline passed.” Delivered reminders do not replay on restart. |
| Refresh | Stable IDs, timestamps, requirement and source keep their delivery identity. Title/detail changes update a visible banner. Changed schedule/source reference/requirement creates a new identity. Removed schedules disappear. |
| Dismiss/snooze | Dismiss consumes this banner locally. Snooze stores a ten-minute retry across restart, subject to freshness, quiet hours and the one-hour catch-up limit. |
| Stale/rejected/empty payload | Suppress scheduling and countdowns. A rejected replacement can leave the prior cards visible, but cannot trigger alerts. |
| Quiet hours | Local recurring time interval, in the Mac's timezone, including midnight wrapping. Routine reminders wait while quiet; the user may explicitly allow required deadline alerts. Optional work never bypasses quiet hours. |

Delivery history and snoozes use local UserDefaults, separate from the payload and vault. Delivery history keeps the newest 512 identities for up to 30 days. An identity evicted beyond those limits can alert again if republished while eligible. A reminder presented in the compact glance is recorded immediately; a crash or restart can therefore consume it without the user seeing it. Fullscreen notch hiding also hides the banner. These are in-app reminders, not guaranteed notification delivery.

### Related Today features

Saved October 12, 2026 and implemented alongside timed banners. These controls change local display/session state only.

| ID | Feature | Intended behavior | Acceptance or design boundary |
|---|---|---|---|
| O1 | Deadline countdown | Compact countdown beside the hardware notch when music is not playing. Required work is ahead of optional work. Click to open its Today card. Focus sessions and reminders take display priority. | Use explicit deadline timestamps; handle expired, changed and stale deadlines without implying completion. |
| O2 | Submission checkpoint | Before cutoff, remind the user to check all required files and the final receipt, with a button to open the submission site. | Opening the site or dismissing the checkpoint never counts as submission or completion. |
| O3 | Wake-up catch-up | After sleep or app restart, combine missed reminders into one useful banner instead of replaying each one. | Coalesce reminders and avoid duplicates; distinguish an upcoming deadline from one already passed. |
| O4 | Per-task focus timer | Start a work session from a Today card using the selected new-session duration (25 minutes by default); show task and remaining time in Today and in compact wings beside the closed hardware notch. Stop/Clear controls are local. End time survives restart and sleep; a finished session stays visible until cleared. A removed row cancels its session. | Timer state is local session state; finishing a timer never marks the vault task complete. |
| O5 | Quiet hours and urgency | Suppress routine nudges during class or recovery, while allowing explicitly chosen hard-deadline alerts through. | Use the moon button in Today to enable quiet hours, choose From/Until in 30-minute increments, and opt into required deadline interruptions. Equal times suppress routine alerts all day. |

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
swiftc boringNotch/components/Today/TodayPayload.swift boringNotch/components/Today/TodaySchedule.swift tests/TodayScheduleTests.swift -o work/today-schedule-tests
work/today-schedule-tests
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release build
```

Local implementation gates, October 12, 2026: ten Python publisher/bridge tests, the official-SDK stdio MCP smoke test (including v2 publication and rejected-update preservation), both standalone Swift suites, and an unsigned Release build passed. An isolated runtime harness using copies of the production views/store with a scratch storage directory also checked refresh deduplication, rejected-update suppression even after requesting refresh, valid recovery, and cancellation of a focus session when the payload is removed. Offscreen rendering exercised the view layout but could not verify native button compositing; physical notch display, sleep/wake delivery and human visual acceptance remain open. No live payload was published, app installed, commit created or push performed. Use a valid schema-v2 snapshot to activate deadline features; existing v1 snapshots continue to show ordinary Today cards.

Local install follow-up, October 12, 2026 at 23:32 Eastern: the user authorized updating the local app. Copied the validated unsigned Release bundle to `/Applications/Boring Notch.app`, verified its executable SHA-256 matches the build (`2712cfff75bcaeef4e066440dd7b592747a53b082bfcd69a55823de8265020d5`), quit the development instance and confirmed the new process runs from Applications. The prior installed app was initially preserved at `work/local-app-backups/Boring Notch-20261012-233257.app`; the user subsequently requested its deletion, and that backup has been removed. Future authorized local updates delete their previous app copy after the replacement passes its launch check, as recorded in `CLAUDE.md`. The live payload was not changed; physical-notch and sleep/wake acceptance remain open.

## Rollback and upstream sync

To clear the view, quit Boring Notch and move `payload.json` to a backup location; the next launch shows the empty state. To restore a previous plan, republish the saved JSON through the validator. Do not edit the live file in place. Remove the `boring-notch-today` MCP entry with the Codex MCP settings or CLI when the bridge is no longer wanted.

Keep `upstream` pointed at `https://github.com/TheBoredTeam/boring.notch.git`. Before an upstream merge, fetch it, build the integration branch, merge or rebase deliberately, resolve the three Today wiring points (`NotchViews`, `TabSelectionView`, and `ContentView`), then rerun the focused payload test and release build. This derivative remains GPL-3.0 under the upstream `LICENSE`; retain upstream notices and provide corresponding source when distributing builds.

The notch layout anchors its content at the top. Today receives the panel height
minus the header and bottom inset, so long plans scroll inside the remaining
space rather than pushing the tab row above the display.

Presentation/customization status is tracked in [Customization](Customization.md).
O7 and O8 have source/build checkpoints; their installed/native/human gates remain open.


## Today presentation preferences (O7 source, October 13)

Settings → Notch → Today Presentation provides 15/25/45/60-minute new focus sessions,
All/Required-only work, Current/Compact density and Standard/Subtle in-scroll
reminders. Defaults are 25, All, Current and Standard. O6 deadline horizon stays in
Closed Notch Glance and keeps its routine-countdown-only meaning.

Required-only hides rows only when all their explicit deadlines are optional. Rows
without deadlines, mixed rows and active focus/reminder targets remain; explicit
glance navigation reveals/expands a hidden target until filter or snapshot changes.
Mixed-row optional deadline detail normally hides except active targets. Original
ranks/order and unlinked Start/Next strings remain. Filtered-empty text never implies
completion. Compact changes spacing/padding; Subtle changes reminder weight/padding.
Both preserve copy, disclosure and actions. No task, snapshot, quiet-hours, reminder
ledger or scheduling mutation. A changed duration affects new sessions only.

O7 strings use today.focus.duration, today.presentation, today.density and
today.reminder.prominence in UserDefaults/AppStorage with bounded effective fallback.
Exact NSClipView offset persistence remains with range clamping after content shrinks.
Local automated/offscreen and unsigned-build evidence, installed/native/human limits,
and O8 handoff are in Customization.md. The earlier O7 source checkpoint predates the current installation in
`CLAUDE.md`; native restart/keyboard/VoiceOver acceptance remains open.


## Named Today presets (O8 source, October 13)

Settings → Notch offers Study, Quiet, Media and one local Custom slot over the four
O7 presentation keys and four O6 glance keys only. Preview is informational and shows
all target values, including new focus duration 25 for built-ins. Explicit Apply
freshly reads current settings. Save Custom stores effective values without applying
them. Persistent one-level Restore keeps subsequent manual edits, including removal
or invalid raw values, and consumes its record after reconciliation. Quiet means
presentation only; active focus, reminders, quiet hours and payloads are unaffected.
Source/test/unsigned Release passes and pending native/human gates are recorded in
Customization.md's O8 checkpoint. That source checkpoint predates the current
installation recorded in `CLAUDE.md`.

## Efficiency source checkpoint, October 14

Today now skips unchanged plan reads/decodes using replacement-aware file metadata,
and gates unchanged observable state/reminders/transport publications. It retains
one-second semantic scheduling and the five-second bridge heartbeat/15-second
fallback contracts. Untimed idle content no longer publishes a clock each second;
focus and fresh deadline displays retain time updates. A rejected replacement keeps
last-good cards while suppressing reminders. Scratch filesystem, clock and lifecycle
checks and an unsigned Release build passed. The source remains uncommitted. The candidate was installed and passed its
Applications launch check at 14:46 EDT; physical sleep/wake and battery savings
remain OPEN. Current installed identity is owned by `CLAUDE.md`. Detailed F1–F10
source dispositions, counts, commands and candidate identity are in
[Battery efficiency](Battery-efficiency-2026-10-14.md#implementation-checkpoint-october-14-2026).
