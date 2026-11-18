# Optimization and improvement review, November 4, 2026

Reviewed clean `main` at `7a28bfc`. This is a prioritized source review, not implementation approval or an energy benchmark. The recent Today clock-publication, D-hall incremental loading and score-cache changes are already present. Older audit findings were checked against current source rather than treated as an unchanged backlog.

## Recommended order

### F6. Fix snooze timing after the clock-publication optimization

**First priority, reproduced regression.** `python3 tests/run_battery_efficiency.py` compiles, then fails the existing assertion at `BatteryEfficiencyTests.swift:68`: a snoozed reminder returns before the expected 600 seconds have elapsed. `TodayStore.swift:322-325` calculates its retry from published `now`. The latest clock optimization deliberately leaves that display value behind the actual clock between countdown-minute changes. Reminder evaluation uses the fresh clock, so it can consider the snooze expired early.

Capture `clock()` once when snoozing and calculate the retry from that instant. Audit other action-time uses of the display clock. Retain the publication optimization, then pass the existing regression and add a focused case where the display clock deliberately lags. This finding is listed first despite its later discovery; F1-F5 retain their review codes.

### F1. Make refresh requests stable and acknowledgements atomic

**Correctness, after F6.** `TodayStore.swift:173-196` only throttles requests for two seconds, then writes a new UUID without reusing an existing pending request. The ready-state button is disabled while pending, but the empty/malformed-state button in `TodayView.swift:94` remains enabled. A later click can replace the ID an agent is servicing. `today_bridge.py:320-326` also reads an ID and unlinks its path without a shared request lock, leaving a concurrent replacement vulnerable to deletion. The race is source-derived, not reproduced in this review.

Reuse a valid pending request across clicks/restarts, give both button states the same pending behavior, and use a shared lock for Swift creation and Python acknowledgement. Add controlled interleaving tests that preserve a newer ID.

Include validator parity in this slice: a direct in-memory probe confirmed Python accepts `2026-99-99T99:99:99Z`; Swift requires an actual ISO date (`TodayStore.swift:235`). Parse a real date in Python and explicitly reject Boolean schema versions. No live bridge records were touched by the probe.

### F2. Reduce Today scheduler wakeups after the recent redraw fix

**Next performance candidate; savings unmeasured.** `TodayStore.swift:264-287` now gates clock publication by countdown minute, retaining seconds for focus. However, `start():109` still runs `tick()` every second even with no focus, deadline or reminder. Each eligible tick reconstructs quiet hours, prunes the ledger and evaluates schedules.

Keep second updates while an active focus display needs them; otherwise schedule the next semantic transition: reminder, snooze, quiet-hour boundary, freshness boundary or countdown minute. Reschedule after payload/preferences changes and reconcile immediately after wake. Do not stop reminder scheduling merely because Today is hidden. A lower-risk alternative is to retain the existing scheduler until profiling shows meaningful cost.

Acceptance: deterministic boundary tests plus equal-workload CPU/wakeup measurements. Fewer observable publications alone do not prove lower battery drain.

### F3. Finish bounded file reads and separate I/O from UI publication

**Robustness and responsiveness.** Today runs on the main actor and reads through `Data(contentsOf:)` after pathname metadata checks (`TodayStore.swift:139-149`, `:205-235`). Payload identity checks already avoid repeated decoding and detect ordinary replacements. They do not bind the read to the checked file descriptor or cap allocation during a concurrent growth/replacement. Status and pending reads have weaker metadata checks than the payload.

Use one bounded descriptor reader for the three records, with no-follow open, descriptor metadata validation and a limit-plus-one read. Then consider serialized background read/decode with a generation check before main-actor publication. Preserve last-good cards and rejected-update reminder suppression. The local same-user trust boundary makes this a bounded robustness improvement, not evidence of a remote exploit.

### F4. Avoid recomputing D-hall history-derived ranking for every arrival

**Lower priority, profile first.** Every `menus` assignment recomputes staples across up to 60 days and clears all scores (`DHallStore.swift:19`, `:103-110`). Incremental loading assigns once per fetched day (`:192-195`) and again on completion (`:180-181`). The recent score cache helps redraws, but these assignments invalidate it repeatedly. Cache encoding and writing also happen on the main actor (`:183-185`).

Preserve incremental display. Reuse staples and scores when meal/item content is unchanged, distinguish timestamp-only updates, and serialize cache encoding/writing off the main actor. Compare a seven-day refresh with a populated history before adding an incremental index. Do not parallelize the shared-cookie, selected-menu request sequence without proving source-session isolation.

### F5. Give nightly builds durable identity and bounded retention

**Developer workflow and disk use.** `local-nightly-build.py:22-33` retains source snapshots per SHA while reusing one DerivedData directory. `docs/Local-workflows.md` explicitly records no cleanup policy. The printed SHA is useful but there is no structured last-success receipt identifying a retained app artifact.

Add a receipt containing SHA, timestamps, result and artifact path; retain the latest successful app independently of mutable build output. Then add a configurable retention policy that protects the active and last-successful snapshots. No cleanup was performed. Test receipt and retention selection against a temporary fixture tree before authorizing deletion of real artifacts.

## Verification and limits

- Python publisher/bridge suite: 10 tests passed. These existing tests do not establish the F1 interleaving or impossible-date rejection.
- Direct validator probe: impossible refresh date accepted, confirming the Python side of the parity gap.
- Lifecycle harness: compiled with warnings, then FAILED at `tests/BatteryEfficiencyTests.swift:68` on the snooze boundary (SIGTRAP from its precondition). Later lifecycle checks did not complete. See F6.
- No application source, payload, preferences, installed app or process configuration changed. No build/install, native UI acceptance, commit or push performed.

A controlled native behavior and energy comparison remains necessary before claiming battery improvement. Include the app, helper and MCP processes under the same display, media, camera and power conditions. The prior battery report contains historical implementation/install receipts, not a current energy measurement.

## Authorized runtime and battery implementation, November 4

The subsequent request authorized runtime, speed and battery improvements. The review above is the pre-change evidence; current implementation dispositions follow.

- **F6 implemented:** snooze captures the action clock once and schedules exactly 600 seconds from that instant. The existing failing regression now passes with an explicit assertion that the display clock lags the action clock.
- **F2 implemented:** replace the permanent one-second Today timer with a one-shot scheduler. Active focus keeps second updates; reminders, snoozes, countdown minutes, enabled quiet-hour minute boundaries and payload freshness choose an earlier transition when needed. Otherwise the dedicated scheduler waits 60 seconds. The existing five-second MCP heartbeat, directory watcher, 15-second file fallback and wake reload remain intact. Preference notifications also reconcile scheduling. Those independent paths can invoke evaluation sooner, so this is not a claim of only one total app wakeup per minute.
- **F4 implemented in a bounded slice:** identical menu snapshots skip observable assignment; timestamp-only updates preserve history-derived staples; cached scores survive content updates when the staple set is unchanged. Changed staples and favorite/keyword changes still invalidate scores. Atomic cache encoding/writing now runs in a utility task while the existing refresh owner remains active, preventing overlapping refresh writes. Incremental day display and the shared-cookie serial network sequence are preserved. A larger incremental history index remains deferred until profiling justifies it.

F1 refresh synchronization, F3 descriptor-based storage reads and F5 nightly receipts/retention remain proposals. No heartbeat cadence, FFT cadence, media smoothness, keep-awake policy or camera demand policy was changed.

### Current verification

- `python3 tests/run_battery_efficiency.py`: PASS, including snooze timing, deterministic idle/reminder/snooze/focus scheduling checks, watcher replacement, audio demand, Shelf persistence, calendar query ownership, periodic network ownership and 31 camera regressions. Uses production owners with inert external adapters; not an app-hosted XCTest result. Log: `work/runtime-20261104/lifecycle.log`.
- Standalone D-hall Swift suite: PASS, including duplicate-publication suppression, timestamp-only refresh and staple-score invalidation. Uses a nonexistent scratch cache path, without live fetches or live cache writes.
- Unsigned Release build: PASS with `xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release -derivedDataPath work/DerivedData -jobs 2 CODE_SIGNING_ALLOWED=NO build`. Log: `work/runtime-20261104/release.log`. Existing warnings remain.
- Python publisher/bridge tests: 10 passed earlier in this review; Python sources were unchanged by implementation.
- Isolated real-run-loop probe: instrumented copies of baseline/current production TodayStore, private empty directories and separate defaults suites. During 4.2 seconds idle, baseline evaluated 5 times and candidate once (the initial reload); both retain the 15-second fallback outside this short window. This verifies removal of the idle one-second timer, not system wakeups or energy. Script/log: `work/runtime-20261104/timer_probe.py`, `timer-probe.log`.
- `git diff --check`: PASS. The pre-existing untracked review was retained and updated with this execution receipt.

No install, commit or push occurred. Actual battery duration, CPU savings, installed UI behavior and physical sleep/wake acceptance remain unmeasured. The next battery evidence gate is a controlled native workload comparison, not another equivalent local test suite.

### Authorized installed update, November 4 at 11:12 EST

The subsequent request authorized installation. The unsigned Release candidate now replaces `/Applications/Boring Notch.app`; its full bundle manifest matches the built candidate. Executable SHA-256: `448a9b8389b3bbb611d2c5cc85e0eb28228146b976186b7104bfea3d22083987`.

The previous process quit normally. The replacement launched from the installed path as PID 39816 and remained alive throughout the 22.61-second launch check, with no new matching crash reports. The previous app copy created for this update was deleted only after that check passed, per the standing installation preference.

Receipt: `work/runtime-20261104/install-20261104-111146/receipt.json`; installer and log: `work/runtime-20261104/install.py`, `install.log`. This supersedes the earlier not-installed state. Source remains uncommitted and unpushed. Visual/human acceptance, physical sleep/wake and measured battery duration remain open.

### Live CPU and AC power follow-up

The installed app was subsequently measured with process counters, a live stack sample and a user-authenticated system power profile. Results and ranked remaining proposals are in [Installed usage, November 4](Installed-usage-2026-11-04.md). The app's CPU was very low in the observed workload; this AC observation still does not establish unplugged battery duration.
