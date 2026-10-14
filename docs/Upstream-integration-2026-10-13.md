# Upstream and fork integration, 2026-10-13

## Current scope

The user authorized absorbing useful upstream changes, considering other forks,
and updating the local app. Integration source is the recovered worktree at
`/Users/weiwei/.codex/worktrees/absorb-upstream-oct09/boring-notch-today`, on
`codex/absorb-upstream-2026-10-09`. Its October 9 merge remains uncommitted.

The missing directory was restored from its surviving Git index with
`checkout-index`. That index contains the resolved upstream-dev merge and D-hall.
Recovery establishes the staged snapshot only; it cannot recover unknown unstaged
or untracked files that disappeared with the original directory. The primary
checkout's current Today payload/store/view/schedule, bridge and tests were carried
forward, and deadline/focus banners were adapted into the newer ContentView.
The primary checkout's existing source edits remain intact.

| Code | Absorbed change | Evidence |
| --- | --- | --- |
| D1 | Equal-width battery-notice sides, with hidden measurement copies excluded from accessibility; legacy non-notch height migration before initial view creation. | Upstream [PR 1675](https://github.com/TheBoredTeam/boring.notch/pull/1675), [PR 1686](https://github.com/TheBoredTeam/boring.notch/pull/1686), changes between `dee29a6` and `30dd715`. |
| D2 | Localization catalog, power labels, onboarding/window/Quick Share strings and menu-bar spelling. | Fresh upstream-dev diff; dependency versions and stock appcasts were left out of this selective pass. |
| D3 | Release the IOKit service returned by the brightness-availability probe. | Source review of [servitola `098e2d1672`](https://github.com/servitola/boring-notch/commit/098e2d1672) exposed the same unreleased resource in our brightnessDisplayID helper. Adapted narrowly; no brightness ramp or display-selection rewrite. |
| D4 | Reject invalid/unknown/implausible media durations before constructing a seek range; show an inert track and unknown trailing time. Guard time conversion against negative and huge inputs too. | Atoll [duration/slider review correction `3de0f12b2ef2`](https://github.com/Ebullioscopic/Atoll/commit/3de0f12b2ef2), checked against our actual unguarded `0...duration`. Added production-view rendering regressions. |

## Broader fork review

Screened the top 20 forks returned by GitHub's forks API, then inspected recent
commits in six relevant repositories. Star ranking was a discovery filter, not
an acceptance criterion. Source diffs informed the decisions below.

| Source | Disposition and reason |
| --- | --- |
| [Atoll](https://github.com/Ebullioscopic/Atoll) | Took duration validation. Current performance changes mostly involve animated artwork, glow textures, audio spectrum and newer lyrics providers absent from our implementation. Our playback timeline already ticks at 0.2 seconds and pauses, so importing a 30 Hz timeline would increase work. No whole media-stack transplant. |
| [Not So Boring Notch](https://github.com/Cris2907/not-so-boring-notch) | Recent timer sizing fixes and Quick Notes depend on that fork's timer/extension presentation. Our Today focus timer uses a different layout; these are future feature options, not direct fixes. |
| [BoringNotchPlus](https://github.com/mustafa-ramax/BoringNotchPlus) | Recent clipboard fix removes a duplicate monitor declaration that is absent here. Continuous clipboard capture was not added. |
| [servitola](https://github.com/servitola/boring-notch) | Took the applicable resource-release fix. Brightness ramping and asymmetric HUD styling need separate hardware/UI validation and are deferred. |
| [QuotaNotch](https://github.com/ApisXia/QuotaNotch) | Reviewed `683f13e196` and `44e5b887ed`: physical-notch anchoring audits and state-derived wing offsets are useful patterns, but its quota/task/cat module geometry does not map directly to our four-tab layout. No extra account integrations imported. |
| meloer101/boring.notch | GitHub API returned 404. The search result was insufficient evidence for adoption; no code used. |

The already-adapted 64-pixel artwork averaging mechanism was retained. GPL notices
remain. Fork updater feeds remain disabled. No vault files or live payload were
changed.

## Verification and installation

| Gate | Result |
| --- | --- |
| Python publisher/bridge | 10/10 pass |
| Official-SDK MCP smoke | Pass |
| Standalone Today payload and schedule | Pass |
| D-hall parser/date/cache | Pass |
| Paired media timing and gesture regressions | Pass |
| Full Debug XCTest | 105/105 pass; zero failed or skipped |
| Final focused duration/height XCTest | 3/3 pass after correcting test actor annotations |
| Final unsigned Release build | Pass |
| Installed launch | Running from `/Applications/Boring Notch.app/Contents/MacOS/Boring Notch` |
| Native installed UI | Home, Shelf, Today and D-hall selected successfully. Today restored afterward; existing snapshot renders and D-hall shows October 13 Marketplace meals. |
| Merge hygiene | No unmerged index entries; cached diff check passes |

Installed executable SHA-256:
`f56afc9fc844b9521c1eafd6b1a703afd0eac236df4191c5611228a80fb938fd`.
It matches the final Release candidate. The executable name changed from
`boringNotch` to `Boring Notch` with the recovered upstream product rename.
The current app did not exit on SIGTERM; normal Quit through its menu succeeded
before replacement. This update's temporary rollback copy was deleted only after
successful installed launch and UI inspection, following the user's preference.

Logs are in the recovered worktree's `work/`: `python-oct13.log`,
`mcp-oct13.log`, `xctest-oct13.log`, `duration-tests-final-oct13.log` and
`release-final-oct13.log`. XCTest bundles are in the primary checkout's
`work/DerivedData-upstream-oct13/Logs/Test/`.

Source integration is staged and uncommitted. Nothing was pushed. The local
installation is unsigned; signed distribution and real camera/display switching,
charging-notice transitions and brightness hardware behavior remain unverified.
The live snapshot had no due banner in the inspected state, so native checks do
not establish timed-banner delivery; schedule tests cover that logic separately.

## Superseded resume notes

The following prior primary-checkout resume notes are preserved as history.
Current local installation and source location are recorded above.

## Current state and resume point

- `HANDOFF.md` was refreshed on 2026-10-07 with main history, Atoll commits, fresh test/unsigned-build gates and open items. MCP client restart and signed-distribution `MediaRemoteAdapter` Team ID reconciliation remain separate manual gates.
- Local branch triage on 2026-10-07: `codex/open-today-shortcut` replays onto main cleanly; recommend merge. `codex/today-freshness-accessibility` conflicts in TodayStore/TodayView; recommend replay onto a new integration branch, resolve the current-layout overlap, then merge after its integration gates. Both pass Python/Swift and unsigned Release gates in the tested states recorded in `HANDOFF.md`; neither was merged or rewritten.
- The ten carried Atoll/cleanup paths were committed on `codex/atoll-fixes` as `cf461f5` and `67ca6bb` after the requested tests and an unsigned Release build passed. Main remains at `3baab5f`; nothing was pushed or installed. Preserve any new user edits and stage only explicitly authorized task paths.

## Compact Today follow-up, 2026-10-13

The user reported that the new closed-notch deadline/focus banners obstructed
browser controls and requested using the space beside the hardware notch.

Removed the lower closed-notch banner and the full reminder overlay over other
tabs. Today now uses two fixed 90-point side wings at the normal closed-notch
height: task on the left, countdown/reminder/focus status on the right. Routine
deadlines appear when music is not playing; focus and due reminders take priority.
Notifications, battery notices and system HUD retain their existing precedence.
Zero-height/fullscreen-hidden notches suppress the glance. Clicking it opens the
associated Today card. Full reminder controls live within Today's scroll area.

Final unsigned Release build passed (`work/compact-today-final-build.log`). Native
installed-app inspection showed `POL · Tue 23:59` and `23h 9m` beside the notch,
at 38-point closed height with no lower strip. Clicking the glance opened Today
and expanded the POL card. Four top tabs remain present. No payload was published.
This is build/native UI verification; the earlier 105-test result predates this
layout change and is not claimed as a new full-suite pass.

Current installed executable SHA-256: `86f61ed3c9af03ba9c7a4b3828f7b540974f459ab0eec5a539de37108b3839ae`.
It matches this follow-up's Release build and supersedes the earlier installed
hash above. The follow-up's temporary rollback copy was deleted after successful
launch and native checks. Changes remain staged and uncommitted; nothing pushed.
