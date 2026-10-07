# CLAUDE.md

Fork-local notes for agents. Upstream docs (README, CONTRIBUTING) cover the app itself; this file covers what differs here and what is easy to get wrong. Worked so far only in OpenAI Codex.

## What this repo is

Personal fork of Boring Notch (macOS notch app, Swift/SwiftUI) with a read-only **Today** tab. Remotes: `origin` = `onionviolet/boring-notch-today` (the fork), `upstream` = `TheBoredTeam/boring.notch`. Fork work lives on `main` (upstream's own `main` is a release branch and `dev` is a separate, much larger train; see Upstream below). Fork commits start at `83847f4` ("Add read-only Today integration"); everything older is upstream.

What the fork adds:
- A schema-v1 JSON payload at `~/Library/Application Support/boring.notch/Today/payload.json`, displayed by the app. The app never speaks MCP and never reads the planning vault.
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
- `scripts/`, `tests/` (Python tests, `mcp_smoke.py`, standalone Swift tests), `docs/Today.md`, `docs/Atoll-review.md`, `HANDOFF.md`.
- Bridge state files sit beside the payload: `refresh-request.json`, `bridge-status.json`, all owner-only (0600; dir 0700).

## Gotchas learned

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

## Current state and resume point

- `HANDOFF.md` was refreshed on 2026-10-07 with main history, Atoll commits, fresh test/unsigned-build gates and open items. MCP client restart and signed-distribution `MediaRemoteAdapter` Team ID reconciliation remain separate manual gates.
- Local branch triage on 2026-10-07: `codex/open-today-shortcut` replays onto main cleanly; recommend merge. `codex/today-freshness-accessibility` conflicts in TodayStore/TodayView; recommend replay onto a new integration branch, resolve the current-layout overlap, then merge after its integration gates. Both pass Python/Swift and unsigned Release gates in the tested states recorded in `HANDOFF.md`; neither was merged or rewritten.
- The ten carried Atoll/cleanup paths were committed on `codex/atoll-fixes` as `cf461f5` and `67ca6bb` after the requested tests and an unsigned Release build passed. Main remains at `3baab5f`; nothing was pushed or installed. Preserve any new user edits and stage only explicitly authorized task paths.

## Codex history

Search these for prior reasoning (inference: the 2026-09-13 cwd is the original scratch checkout):
- Session cwds: `/Users/weiwei/code/boring-notch-today` and `/Users/weiwei/Documents/Codex/2026-09-13/boring-notch-today` under `~/.codex/sessions/2026/09/` (09-13 to 09-30). Output report: `~/Documents/Codex/2026-09-13/boring-notch-today/outputs/`.
- `~/.codex/memories/MEMORY.md`: grep "Boring Notch" (task groups on upstream absorption, scroll release, publishing).
- `~/.codex/memories/rollout_summaries/*boring_notch*` and `*mcp_live_today_bridge*`.
