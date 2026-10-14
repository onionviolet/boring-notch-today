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

## O6 compact Today glance implementation, October 13

The existing fixed 90-point wings used the full title and obstructed neighboring
menu-bar content. This authorized slice replaces them with independently fitted
wings and local Settings → Notch → Closed Notch Glance controls. Defaults are
Automatic visibility, Compact label, Compact width and All deadline horizons.
Balanced caps each side at 80 points; Compact caps each at 56 points, including
four points of text padding and the existing 14-point external corner padding.
Thus the entire rendered width is at most the hardware width plus 112 points in
Compact, compared with the former hardware width plus 218 points including outer
padding. Short labels fit below the cap.

Compact labels retain at most eight supplied title characters plus an ellipsis;
no course identity is inferred. Full uses the supplied title, still truncated to
the width cap. Help/accessibility retain the full title and detailed status.
Routine countdowns use minute/hour/day buckets with monospaced digits and one
fixed measured right-hand allocation. Values round up; focus completion says
Done and reminders say Alert, including preparation/checkpoint reminders that
are not the actual deadline. Countdown details remain available in Today/help.

The closed-content presentation now includes Today, so rendering, animation
selection, width and offset use the same presentation. Its shaped row, hover/tap
region and chin receive (rightWidth - leftWidth)/2 together. The hardware gap is
exactly the hardware width; there is no additional center spacer. Removing a
side leaves the hardware center fixed. The transparent backing window remains
centered. Both the button and clicks in its padded outer area select the associated
Today row before opening the tab.

Hidden removes this Today presentation. Horizon affects only routine upcoming
countdowns, with an inclusive upper boundary; reminder/focus state is unchanged.
Reminder then focus then idle routine-deadline priority remains within Today;
hello, fallback notice, notifications, battery notices and HUD suppress it.
Fullscreen/zero-height/open-notch suppression remains wired to existing state.
No payload, vault data, scheduling timestamp, notification delivery, updater feed,
other tab, scroll keeper or gesture implementation was changed.

| Gate | Result for this slice |
| --- | --- |
| Source | Edited the recovered integration checkout only; existing staged merge preserved. New changes are unstaged. |
| Focused XCTest | 8/8 TodayGlanceTests pass in Debug, covering normalized invalid preferences, persistence through a fresh UserDefaults instance, horizon edges, reminder/focus/media priority, suppression policy, countdown boundaries, measured font widths and asymmetric/no-side geometry. |
| Offscreen rendering | Actual TodayNotchGlance rendered with the existing NotchShape, matching padding/offset and center guides for short/long/full/left-only/right-only/no-wing fixtures. Inspected bounds and legibility. A final opaque-background render rerun passes separately. These fixtures do not claim installed Hidden-mode or native pointer verification. |
| Scheduling regression | Standalone TodayScheduleTests pass for catch-up, restart, snooze, quiet hours, changed/removed/stale deadlines, original detailed countdown and schema. |
| Final unsigned Release | Build succeeded from recovered source at work/DerivedData-o6/Build/Products/Release/Boring Notch.app. |
| Runtime / installed UI | No manual candidate launch or installation performed. XCTest used the Debug test host and offscreen render only. Existing /Applications app was not replaced. |
| Human acceptance | Open. Native hover/click alignment, card navigation/exact scroll restore, live HUD/media/reminder transitions and physical fullscreen/zero-height behavior remain to verify with an authorized runtime pass. |
| Commit / push | Neither performed. |

Final candidate executable SHA-256:
`ce3ba0c1b1e868b15694c067261e22521ab1595926fd14d4ff5fe48fa44a2b01`.
Logs: recovered worktree `work/o6-tests-final.log`, `work/o6-render-final.log`
and `work/o6-release-final.log`. Render: `work/o6-glance-render.png`.
Focused test bundle:
`/Users/weiwei/code/boring-notch-today/work/DerivedData-upstream-oct13/Logs/Test/Test-boringNotch-2026.10.13_01-38-16--0400.xcresult`.
The first XCTest invocation used Release without enable-testing and failed before
running tests; Debug corrected the configuration. The old 105-test result is not
claimed for this slice. No additional Python/MCP suite was required because the
publisher, bridge and payload contract were untouched.

O5 genuine haptic intensity research remains next, with the source-backed Tactile
candidate and physical strength gate intact. O7 Today preferences, O8 presets and
O9 Quick Notes remain separate future scopes. This implementation does not accept
the broader proposed wing/widget framework or establish physical haptic results.

## O6 local installation, October 13

User authorized the local app update in this chat. The candidate above was
installed at `/Applications/Boring Notch.app` after normal Quit. Launch check
observed PID 96713 at `/Applications/Boring Notch.app/Contents/MacOS/Boring Notch`;
the installed executable matches the candidate hash
`ce3ba0c1b1e868b15694c067261e22521ab1595926fd14d4ff5fe48fa44a2b01`.
Native UI inspection found all four tabs; clicking the closed Today glance
opened Today and expanded the POL card. Settings → Notch shows Automatic,
Compact label, Compact width and All horizons. Settings were closed without
changing preferences. The update-specific rollback copy was removed after these
checks. Installed launch/navigation/settings are verified; human visual
acceptance, exact scroll restore across restart, live timed transitions and
physical fullscreen/zero-height behavior remain separate open gates.
No commit or push.

## Customization continuation authorization, October 13

After the O6 installation request, the user asked: “after finishing that send out
another round trip for next part and once thats done send into new chat and run
and continue the cycke”. This authorizes the reviewed bounded O5 implementation
and subsequent useful review → local successor → execution units in this roadmap.
It does not authorize commit/push or silently carry the O6-only app installation
request into unlimited later updates. Human physical intensity acceptance remains
a user-only gate; independent O7 work can advance with O5 acceptance pending.

The next ordinary ChatGPT High review is complete. Saved outbound, verbatim
response, provenance and reconciled executable packet use the
`Customization-haptics-2026-10-13-*` / `Customization-haptics-next-pass.md` names.
The reviewed O5 packet preserves genuine intensity research, conditional adoption
of the pinned actuator mechanism, explicit single pulses and supported cue
controls. The successor should record its own chat ID, this predecessor
`01a133be-2e22-7db3-8dce-5732b54b1656`, and its acceptance/resume state here.
Upon successful dispatch this predecessor releases all affected haptic/settings/
app/tests and Customization/integration-history writes, including primary docs
mirrors, to that successor. No existing haptic successor was found in live recent
chat inventory. O7 then O8 remain next; O9 remains optional rather than a mandatory
prerequisite or an excuse for indefinite chaining.


## O5 execution ownership, October 13

Successor `01a133d0-ad75-72c2-8827-84b714d43549` owns this bounded haptic pass,
from predecessor `01a133be-2e22-7db3-8dce-5732b54b1656`. Initial state: branch
`codex/absorb-upstream-2026-10-09`, recovered staged merge plus unstaged O6;
initial staged/unstaged binary patches saved in `work/o5-initial-*.patch`.
No installation, staging, commit or push is authorized in this pass.


## O5 haptic implementation and verification, October 13

Source O5 is implemented and an unsigned Release candidate is built. The
canonical mechanism/ABI inventory, cue map, exact commands, evidence and human
trial are in [Customization.md](Customization.md#o5-haptic-implementation-and-acceptance-october-13).
This is **mechanism implemented; physical intensity unverified**.

Added default-on Hover/Action switches on the existing SwiftUI alignment route,
and an explicit single-pulse private actuator test with Off/0.20/0.45/0.70.
The local ABI check found MTActuatorOpen's second 32-bit argument, omitted by the
pinned source. The wrapper passes zero and gates this private route to inspected
arm64 macOS build 26B5101f. Three no-pulse lifecycle scans succeeded; no real
experimental actuation or new installation was performed.

Affected XCTest 30/30, final haptic XCTest 11/11, existing standalone schedule
regression and unsigned Release pass. Logs: work/o5-tests.log,
work/o5-haptic-final-tests.log, work/o5-schedule.log, work/o5-release.log.
Candidate: work/DerivedData-o6/Build/Products/Release/Boring Notch.app;
executable SHA-256 5ce3e5e67ecb6571389a0b433cd96fbd64d04584613ffb1001aa50c4da6471eb.
The initial staged binary diff remains byte-identical. No stage/commit/push.
Source changes remain unstaged. Installed/native persistence and physical
strength acceptance remain separate gates; O7 can proceed independently.


## O7 reviewed handoff, October 13

O5's bounded source/build gate is closed with physical intensity acceptance still
pending. The O7 ordinary Chrome ChatGPT review is complete: observed GPT-6 checked,
High effort 3 of 3. Full response, provenance and executable reconciliation are
saved as `Customization-today-preferences-2026-10-13-*` and
`Customization-today-preferences-next-pass.md`. The response remains a review
artifact, not verification of O7. Live recent inventory shows no O7 local successor.

Predecessor `01a133d0-ad75-72c2-8827-84b714d43549` now dispatches the O7 unit to a
fresh local owner. On successful creation it releases affected Today/settings/tests,
Today.md, Customization.md and integration-history writes plus primary docs mirrors,
and performs no further edits there. The recipient must record its returned chat
ID and initial state here before implementation. It receives the existing dirty
source intact; every app/source/test/build action must use the recovered checkout.
No installation/staging/commit/push is authorized. O8 review and one useful successor
remain authorized after O7 settles; O9 remains optional.


## O7 execution ownership, October 13

Successor `01a133e3-265d-79e0-8c08-f8c61eec5127` receives exclusive O7 writes from
`01a133d0-ad75-72c2-8827-84b714d43549`. Verified recovered root and branch
`codex/absorb-upstream-2026-10-09`; staged merge and unstaged O5/O6 preserved.
Initial binary patches: `work/o7-initial-staged.patch` and
`work/o7-initial-unstaged.patch`. Staged hash
`11a5a08fd0d1e40efdf487b9643d0fd7b64d69bbef89526d08247452538cb456`.
No overlapping O8 owner found in recent chat inventory. No install/stage/commit/push.
O7 implementation and verification in progress; O8 follows after this unit settles.


## O7 Today presentation implementation checkpoint, October 13

Four O7 preferences are implemented with metadata-only filtering, active and explicit
navigation target retention, new-session-only duration, density and Subtle reminder
presentation. Exact NSClipView restore remains with tested shrink clamping.
27/27 affected XCTest, standalone payload/schedule and final unsigned Release pass.
Complete commands, render/log paths, failed-probe reconciliation and gate inventory
are in Customization.md under O7 Today preferences. Candidate executable SHA-256
fdb260c05dba6eb249477ad5d2639e9bb3c0542e13ba8ded35966689df702395; installed app remains
O6 ce3ba0c1b1e868b15694c067261e22521ab1595926fd14d4ff5fe48fa44a2b01. No installation,
manual candidate launch, haptic pulse, stage/commit/push. Native/human acceptance and
VoiceOver remain open. Initial staged merge remains byte-identical. O8 presets are
next under the existing review → local successor authority, with O9 optional.


Final O7 follow-up evidence: the finalized six-test TodayPresentationTests slice
passes 6/6, zero failures/skips/runtime warnings (work/o7-presentation-final.log,
work/o7-presentation-result-summary.json). After adding an explicit real SwiftUI
pane reopen assertion, the native offscreen navigation/scroll/render test passes
1/1 with the saved 60-point offset restored before interactions
(work/o7-scroll-reopen-final.log, work/o7-scroll-reopen-result-summary.json).
The broader 27-test result remains the affected-regression evidence; no source
change followed that run. Final new-test SHA-256
063427d85b3982eb8c425832a5642c82198be61a16891fda870ee32f9baa9abd;
source patch SHA-256 4fe57df53da5b3214a73a1dd67abc1b2d5aac0ddb965c2dfaf72b42ae1c7fcdc.
The AX traversal's dynamic-selector follow-up also returned no offscreen tree;
those diagnostic assertions were removed from the executable gate rather than
claiming unsupported accessibility coverage. Saved renders were inspected directly.

O8 ordinary ChatGPT review sent once at 2026-10-13T06:20:39.408Z, with observed
GPT-6 checked and High, 3 of 3. Conversation:
https://chatgpt.com/c/6acdcda1-abfc-83ea-8435-85b901586668 . Outbound/provenance:
Customization-presets-2026-10-13-outbound.md and -provenance.md. Capture and
reconciliation are pending; no O8 source implementation or successor exists yet.


## O8 reviewed handoff, October 13

O7 has settled at source/build verification with native/human gates open. O8 ordinary
Chrome ChatGPT review is complete, GPT-6 checked, High 3 of 3. Full response/provenance
and executable reconciliation are saved as Customization-presets-2026-10-13-* and
Customization-presets-next-pass.md. Presets use the exact eight O7/O6 whitelist keys;
full deterministic built-ins, fresh-value preview/apply, one Custom slot and persisted
conflict-aware one-level restore. Reconciliation clarifies Apply's intentional target
writes, raw-state conflict detection, invalid-prior normalization and the real Release
gate. No O8 implementation was performed here.

No O8 successor found in live recent inventory. Predecessor
`01a133e3-265d-79e0-8c08-f8c61eec5127` dispatches exactly one fresh local O8 owner;
on successful creation it transfers exclusive affected settings/preset/tests and
Today/Customization/integration owner writes plus their three primary documentation
mirrors, and stops writing them. Receiver must record returned chat ID/initial state.
No staging/commit/push/install/permissions/security/publish/vault work. O9 optional;
stop after O8 settles or a real block, without another automatic chain.


## O8 execution ownership, October 13

Receiver `01a133ee-7bcc-76d0-8f3b-a2a0891e19a9` accepts exclusive O8 writes from
predecessor `01a133e3-265d-79e0-8c08-f8c61eec5127`. Live reviewed handoff confirmed.
Source root is the recovered absorb-upstream-oct09 worktree, branch
`codex/absorb-upstream-2026-10-09`. Resolved staged uncommitted merge is present;
initial staged binary diff SHA-256 is
`11a5a08fd0d1e40efdf487b9643d0fd7b64d69bbef89526d08247452538cb456`.
Pre-existing unstaged O5/O6/O7 and untracked artifacts remain. Initial status and
unstaged patch saved in `work/o8-initial-status.txt` and `work/o8-initial-unstaged.patch`.
No competing O8 successor found in live inventory. Implementation is in progress.
No stage/commit/push/install/publication or next successor is authorized.


## O8 source/build checkpoint, October 13

Receiver `01a133ee-7bcc-76d0-8f3b-a2a0891e19a9` completed the bounded named-presets
source unit after the reviewed transfer from `01a133e3-265d-79e0-8c08-f8c61eec5127`.
No O9 work or successor was created. Ordinary ChatGPT review was reused, not repeated.

Settings → Notch → Named Today Presets now provides Study, Quiet, Media and exactly
one locally saved Custom slot. All use the reviewed deterministic eight-key mappings.
Preview shows every target in human-readable terms, including unchanged values and
the 25-minute new-session duration. Selecting/rendering/startup writes nothing.
Apply re-reads current persistent-domain settings and shows its actual delta.
Save Custom normalizes current effective values without applying them or changing undo.
Quiet changes presentation only; reminder delivery and quiet hours remain separate.

Changed source: `boringNotch/components/Settings/TodayPresets.swift`,
`boringNotch/components/Settings/Views/TodayPresetSettingsView.swift`, one section
insertion in `NotchSettingsView.swift`, and `boringNotchTests/TodayPresetTests.swift`.
O6/O7 key names/encodings agree with the review packet; no mapping reconciliation
was needed. The closed typed whitelist is the only preference write surface.
Custom and Restore records use Data containing version-1 JSON entry arrays capped
at 4096 bytes/eight entries. Unknown fields/version/keys, duplicate preference keys,
missing Custom entries, unsupported types/values and malformed/oversized data reject
the whole record. Invalid Custom can be overwritten with Save Custom. Invalid undo
disables Restore without any partial writes. Bookkeeping keys are
`today.presets.custom` and `today.presets.restore`.

One-level Restore persists across a fresh defaults/store instance. It restores only
keys whose actual raw stored value still equals the value Apply wrote. Subsequent
manual edits, removal or invalid raw values are retained even when their effective
fallback coincides. Previously absent keys are removed; previously invalid stored
values restore their documented effective default rather than arbitrary data.
No-op Apply preserves undo. A changed Apply replaces it with the immediately prior
state; one valid Restore consumes it even with all conflicts. Reconciliation reports
restored counts and names of retained edits.

### Actual verification

All commands ran with explicit workdir
`/Users/weiwei/.codex/worktrees/absorb-upstream-oct09/boring-notch-today`.
Debug DerivedData reuses the existing primary-checkout cache as in O7; compiler
source paths point to the recovered worktree. No primary app source was edited.

- Initial test build failed from an outdated TodayRow fixture initializer and a
  missing local render-helper @MainActor annotation. Both test-only errors were
  corrected; production O8 source compiled. Original failure: `work/o8-tests.log`.
- Affected run: 38/38 passing, comprising 11 O8 plus 27 O6/O7/compatibility/calendar/
  UI-event regressions (`work/o8-tests-final.log`). Final strengthened O8 slice:
  12/12 (`work/o8-presets-final.log`), followed by the added Custom apply/revert test
  1/1 (`work/o8-custom-apply-final.log`). Thus all 13 final O8 methods have passing
  evidence across these slices, not a claimed new all-project suite. Each xcresult
  summary reports zero failures, skips and runtime warnings; JSON summaries are
  saved alongside the logs as `*-summary.json`.
- Standalone payload and schedule checks passed (`work/o8-payload.log`,
  `work/o8-schedule.log`). Synthetic isolated suites protect unrelated sentinel
  preferences, active focus/endsAt and actual due reminder/ledger state. Existing
  navigation/filter-retention and fractional scroll/clamping regressions pass.
- Safe non-installed NSHostingView tests produced and inspected seven 480-point-wide
  section renders: `work/o8-study.png`, `o8-quiet.png`, `o8-media.png`, `o8-custom.png`,
  `o8-custom-saved.png`, `o8-noop-restore.png`, `o8-restore-result.png`. Preview, empty/
  saved Custom, explicit controls, available undo, no-op and retained-edit messaging
  are readable. Render tests assert no preference writes. These are section-level
  offscreen fixtures, not installed/native interaction or VoiceOver acceptance.
- Actual unsigned Release passed (`work/o8-release-final.log`). Existing upstream
  concurrency/deprecation/linker warnings remain; no O8 source warnings observed.
- `git diff --check` passed. Initial staged binary diff SHA-256 remains
  `11a5a08fd0d1e40efdf487b9643d0fd7b64d69bbef89526d08247452538cb456`.
  Saved initial-vs-final tracked diff comparison and reconstructed initial Notch
  source confirm all other tracked source changes preserved; Notch differs by one
  section insertion (`work/o8-hygiene.txt`). O7 TodayPresentationTests hash remains
  `063427d85b3982eb8c425832a5642c82198be61a16891fda870ee32f9baa9abd`.

Commands (run from the workdir above):

```bash
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug -destination 'platform=macOS' -derivedDataPath /Users/weiwei/code/boring-notch-today/work/DerivedData-upstream-oct13 -jobs 2 CODE_SIGNING_ALLOWED=NO -only-testing:boringNotchTests/TodayPresetTests -only-testing:boringNotchTests/TodayPresentationTests -only-testing:boringNotchTests/TodayGlanceTests -only-testing:boringNotchTests/PreferenceCompatibilityTests -only-testing:boringNotchTests/CalendarBoundaryTests -only-testing:boringNotchTests/NotchUIEventTests test
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug -destination 'platform=macOS' -derivedDataPath /Users/weiwei/code/boring-notch-today/work/DerivedData-upstream-oct13 -jobs 2 CODE_SIGNING_ALLOWED=NO -only-testing:boringNotchTests/TodayPresetTests test
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug -destination 'platform=macOS' -derivedDataPath /Users/weiwei/code/boring-notch-today/work/DerivedData-upstream-oct13 -jobs 2 CODE_SIGNING_ALLOWED=NO -only-testing:boringNotchTests/TodayPresetTests/testSavedCustomAppliesItsSnapshotAndRestoreKeepsImmediatePriorState test
swiftc boringNotch/components/Today/TodayPayload.swift boringNotch/components/Today/TodayBridgeStatus.swift tests/TodayPayloadTests.swift -o work/o8-payload-tests
work/o8-payload-tests
swiftc boringNotch/components/Today/TodayPayload.swift boringNotch/components/Today/TodaySchedule.swift tests/TodayScheduleTests.swift -o work/o8-schedule-tests
work/o8-schedule-tests
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release -derivedDataPath work/DerivedData-o6 -jobs 2 CODE_SIGNING_ALLOWED=NO build
```

Candidate: `work/DerivedData-o6/Build/Products/Release/Boring Notch.app`.
Executable SHA-256:
`6c19bb6bd840e81bba6c3956c7e40a359c303cc25784addc9ac82107cf887da8`.
Installed executable freshly remains O6:
`ce3ba0c1b1e868b15694c067261e22521ab1595926fd14d4ff5fe48fa44a2b01`.

O8 is source/test/unsigned-build complete. Installation, manual candidate launch,
native keyboard/VoiceOver/restart and human acceptance were not performed and remain
open. O5 physical haptic intensity remains independently unverified. No live payload,
vault/course data, permission/account/security, haptic, quiet-hour, updater, geometry,
gesture or tab mutation was performed by O8. No stage/commit/push/install/publication.
Three primary documentation mirrors are synchronized. Stop at this checkpoint.

O8-only source patch against receiver initial state: `work/o8-final-source.patch`,
SHA-256 `244e935a4212e6e5a2aabd8e04b2716da7821ff0066df4f6ff6dc5a0fe72855b`. New files remain untracked; no index changes.
