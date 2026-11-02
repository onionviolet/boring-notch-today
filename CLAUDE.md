# CLAUDE.md

Fork-local notes for agents. Upstream docs (README, CONTRIBUTING) cover the app itself; this file covers what differs here and what is easy to get wrong. Worked so far only in OpenAI Codex.

## What this repo is

Personal fork of Boring Notch (macOS notch app, Swift/SwiftUI) with a read-only **Today** tab. Remotes: `origin` = `onionviolet/boring-notch-today` (the fork), `upstream` = `TheBoredTeam/boring.notch`. Fork work lives on `main` (upstream's own `main` is a release branch and `dev` is a separate, much larger train; see Upstream below). Fork commits start at `83847f4` ("Add read-only Today integration"); everything older is upstream.

What the fork adds:
- A schema-v1/v2 JSON payload at `~/Library/Application Support/boring.notch/Today/payload.json`, displayed by the app. The app never speaks MCP and never reads the planning vault.
- A shared publisher/validator (`scripts/today_bridge.py`), a CLI (`scripts/boring-notch-today.py`) and a stdio MCP server (`scripts/boring-notch-today-mcp.py`, tools `publish_today`, `today_status`, `pending_today_refresh`).
- Today as the default tab, scroll-safe, with exact scroll offset persisted (`today.scrollOffset` in UserDefaults).
- Atoll-derived fixes (gesture, now-playing timing); see `docs/Atoll-review.md`.

Full contract, status semantics and security limits: `docs/Today.md`. Read it before touching the payload, bridge status or actions.

## Hard boundaries (from the user, repeated across Codex sessions)

- The planning vault is the only task authority. Today is a one-way, read-only display: no completion action, no vault scanning, no arbitrary path/command/prompt/URL input.
- Never edit `payload.json` by hand. Publish through the validator (CLI or `publish_today`).
- Only two action kinds exist: `source` (HTTPS only) and `itembank` (fixed bundle id `dev.itembank`).
- Do not label a file watcher as "MCP connected". Status wording must match verified state (live, pending, offline/stale).
- Refresh cannot wake an idle agent; do not imply it can.

## Local app update preference

User instruction, October 12, 2026: after an authorized local app update, verify the replacement launches from `/Applications/Boring Notch.app`, then delete the previous app copy created for that update. Keep a temporary rollback copy only until the replacement passes its launch check; do not retain old app backups after success. If installation or launch fails, preserve the previous app for recovery. This authorizes cleanup associated with future requested updates, not unrelated app deletion or automatic installation.

## Build and test

Run from the repo root. Python, MCP smoke, standalone Swift and the unsigned Release command below passed on 2026-10-07; see `HANDOFF.md` for the distinct gates and runtime limits.

```bash
python3 -m unittest -v tests/test_publisher.py tests/test_bridge.py
uv run --with 'mcp>=2,<3' python tests/mcp_smoke.py
swiftc boringNotch/components/Today/TodayPayload.swift boringNotch/components/Today/TodayBridgeStatus.swift tests/TodayPayloadTests.swift -o work/today-tests && work/today-tests
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release -derivedDataPath work/DerivedData -jobs 2 CODE_SIGNING_ALLOWED=NO build
```

- Local visual test: add `CODE_SIGNING_ALLOWED=NO` to the xcodebuild line. The signed build compiles, but launching it can fail on an upstream `MediaRemoteAdapter` Team-ID mismatch. Then `open .../Release/boringNotch.app --args --today-preview-window` renders the real `TodayView` in a window.
- Full XCTest run needs the full `xcodebuild ... test` action; `test-without-building` fails after a build strips the test bundle (Codex, 2026-09-19).
- CoreDevice/CoreSimulator version warnings from Xcode are noise if the macOS build succeeds.
- `work/` and `__pycache__/` are gitignored scratch (test binaries, DerivedData, Atoll patch, logs). Do not commit them.

## Layout of fork-owned code

- `boringNotch/components/Today/`: `TodayPayload.swift` (strict decode), `TodayBridgeStatus.swift`, `TodayStore.swift` (directory watcher plus 15 s fallback poll), `TodayView.swift` (UI, scroll keeper).
- Today wiring points inside upstream files: `NotchViews`, `TabSelectionView`, `ContentView`, `enums/generic.swift`. These are where upstream merges conflict.
- `boringNotch/components/KeepAwake/`: keep-awake cup in the header, cutoff policy and lid-fade curve, manager, `LidFadeController`, and the root script `boringnotch-lidguard` (bundled into Resources by the synced group, installed by the one-click setup); XPC methods in the helper. Contract and setup: `docs/KeepAwake.md`. Test: `swiftc boringNotch/components/KeepAwake/KeepAwakePolicy.swift tests/KeepAwakePolicyTests.swift -o work/keepawake-tests && work/keepawake-tests`.
- `scripts/`, `tests/` (Python tests, `mcp_smoke.py`, standalone Swift tests), `docs/Today.md`, `docs/Atoll-review.md`, `HANDOFF.md`.
- Bridge state files sit beside the payload: `refresh-request.json`, `bridge-status.json`, all owner-only (0600; dir 0700).

## Gotchas learned

- `boringNotch/components/` is mostly classic groups: a new folder's files are not in the target until it gets a `PBXFileSystemSynchronizedRootGroup` entry (see `KeepAwake`) or pbxproj file references. `components/Settings` and `LiveActivities` are already synced.
- Exact scroll restore needs the `NSScrollView`/`NSClipView` offset keeper. SwiftUI anchor-based `.scrollPosition(id:)` restored the wrong spot on tall rows.
- MCP heartbeat: many Codex tasks spawn many `uv run ... boring-notch-today-mcp.py` processes; they elect one writer by file lock. Status goes stale about 15 s after the last transport exits (no shutdown write). Stale pre-fix processes can leave the UI showing offline.
- Refresh button writes a bounded UUID request only; repeated clicks keep the pending ID.
- Replacing `/Applications/boringNotch.app` invalidates Computer Use bindings; reattach by full path. Prior installs were backed up to `~/.Trash`.
- After a publish, `today_status` should show `connected: true`, `payloadValid: true`; then inspect the installed app. The status line `MCP heartbeat stale • file fallback` is transport state, not payload freshness.
- Fresh run on 2026-10-07: **9/9 Python test methods** pass (3 publisher, 6 bridge). This supersedes the old 7/10 counts; MCP smoke and standalone Swift suites are separate gates.

## Verification gates

Keep these separate and never upgrade one to another: source edit, Python/Swift tests, Release build (unsigned vs signed), runtime preview, installed in `/Applications`, visually human-accepted, committed, pushed. Hosted CI never ran on the fork; do not claim it. Signed local launch, physical notch gestures, external display, camera/Bluetooth and notification-reply delivery were never verified.

## Upstream

`upstream/dev` is hundreds of commits ahead and conflicts with Today wiring. Do not merge it wholesale in this checkout; use an isolated worktree (Codex's attempt: branch `codex/absorb-upstream-dev` at `eda4f07` locally, with a fork-specific updater change that removes the stock Sparkle feed). Before any upstream merge: fetch, build the integration branch, resolve the Today wiring points, rerun payload tests and a Release build. GPL-3.0 stays; keep upstream notices. For Atoll or other projects, audit local code first and adapt narrowly, not wholesale.

## Resume and dated evidence

The October 14 source, installation and test checkpoint is preserved in
`docs/Agent-session-snapshots.md`. It is historical evidence. Check the live
branch and worktree before continuing; inspect the installed app and relevant
acceptance owners before claiming current delivery. Feature acceptance lives
in `docs/Customization.md`; battery evidence lives in
`docs/Battery-efficiency-2026-10-14.md`.

## Codex history

Search these for prior reasoning (inference: the 2026-09-13 cwd is the original scratch checkout):
- Session cwds: `/Users/weiwei/code/boring-notch-today` and `/Users/weiwei/Documents/Codex/2026-09-13/boring-notch-today` under `~/.codex/sessions/2026/09/` (09-13 to 09-30). Output report: `~/Documents/Codex/2026-09-13/boring-notch-today/outputs/`.
- `~/.codex/memories/MEMORY.md`: grep "Boring Notch" (task groups on upstream absorption, scroll release, publishing).
- `~/.codex/memories/rollout_summaries/*boring_notch*` and `*mcp_live_today_bridge*`.


<!-- BEGIN PORTABLE AGENT RULES v1 -->
<!-- PORTABLE AGENT RULES MODE: global -->
## Working agreement source

The portable agreement is owned by the planning vault's
`_templates/portable_agent_rules.md`. `~/.claude/scripts/sync_user_prefs.py`
generates `~/.claude/user-preferences.md` and `~/.codex/AGENTS.md`.
Claude loads the former through `~/.claude/CLAUDE.md`; Codex loads the latter
as global instructions. Apply that already-loaded agreement without rereading it.
If your host did not load global preferences, read the corresponding generated
file once. If neither exists, read the canonical vault template before working.

This managed pointer is generated by the vault's
`.claude/scripts/sync_agent_rules.py`; edit its template, not repository copies.
Text outside the BEGIN/END markers belongs to this project.
<!-- END PORTABLE AGENT RULES v1 -->
