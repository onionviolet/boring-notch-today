# HANDOFF

Updated 2026-10-07. Local working branch: `codex/atoll-fixes`; main remains `3baab5f`. Today is a read-only projection of authorized snapshots; the planning vault is the sole task authority. App actions remain HTTPS source links and fixed `dev.itembank` launch only. No vault or live payload edits, install, signing/feed change, push or merge occurred in this session.

## History since the initial Today integration

Baseline `83847f4` adds the read-only Today integration. Subsequent main commits:

| Commit | Change |
| --- | --- |
| `b16bec9` | stdio MCP live updates, bridge status and bounded refresh requests |
| `3842672` | Today default and scroll-safe navigation |
| `2ceac3c` | Shelf drops and artwork sampling |
| `8cb1832` | heartbeat leader election/reliability |
| `eda4f07` | exact native Today scroll persistence |
| `75e5889` | scan-friendly disclosure rows, pinned Start and literal refresh wording |
| `3baab5f` | fork-local CLAUDE instructions |

Today's Atoll branch commits: `cf461f5` (Atoll momentum/timing, attribution and regression tests), `67ca6bb` (idle media animation and preview shutdown cleanup). This handoff/count correction is a separate documentation commit. The report-only audit follows in `docs/Improvements-2026-10-07.md` as its own commit; proposals are not implementation decisions.

## Current gates

Fresh local results: Python **9/9**, official-SDK MCP stdio smoke, standalone Today Swift, PanGesture synthetic AppKit regressions and NowPlaying timing regressions all pass. The unsigned Release build passed on a two-job retry; the first attempt was intentionally interrupted under severe system load (exit 75). `git diff --check` passes. These establish source/test/unsigned-build gates only. The validated Atoll app is preserved at `work/atoll-Release.app`; the shared DerivedData cache is reused for branch triage. Historical handoff evidence recorded live/pending/offline/empty/restored Today UI states; none was repeated today. The setup and contract remain in `docs/Today.md`. No signed launch, physical gesture/playback, installed-app, external-display or human visual acceptance gate was run; hosted CI remains unverified.

## Branch triage and open items

- **A1:** `codex/open-today-shortcut` (`97a3f7b`): unique Cmd-Shift-T/Settings/localization change; detached no-commit replay onto main is conflict-free. Python 9/9, standalone Today Swift, JSON catalog validation and unsigned Release build pass on that candidate. Recommend merge after product acceptance; no merge performed.
- **A2:** `codex/today-freshness-accessibility` (`6b7cbd8`): unique day-boundary freshness, publication/pending details, accessibility and tests. Detached replay conflicts in TodayStore and TodayView; Python 9/9, its extended standalone Today Swift suite and unsigned Release build pass at the original tip, not on a conflict-resolved integration. Recommend rebase-then-merge by replaying onto a new integration branch, retaining the original ref, with explicit preservation of main's disclosure layout, pinned Start, scroll keeper and literal status wording. Branch refs/history remain unchanged; triage worktrees removed.
- **A3:** MCP client restart remains an open manual step to load the configured server/current code. Refresh writes bounded intent and **cannot wake an idle agent**; responding requires an already-running or scheduled authorized workflow.
- **A4:** Signed distribution still needs the upstream `MediaRemoteAdapter` Team ID reconciled separately. Do not change signing, Team IDs, Sparkle feed or `/Applications/boringNotch.app` under this task.
- **A5:** Upstream/dev absorption remains pending on local `codex/absorb-upstream-dev` at `eda4f07`; this branch tip is not proof of a completed integration. Locate/review any candidate, then use an isolated integration branch and rerun Today/build gates under new authorization. Do not absorb it into main here.
