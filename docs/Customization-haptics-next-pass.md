Implement the next bounded customization pass for the personal macOS Boring Notch fork: investigate whether this Mac's trackpad exposes meaningfully controllable haptic strength through the pinned actuator mechanism, build a small explicit test surface for that experiment, and add only the practical supported cue controls that fit naturally beside it.

This is implementation authorization, not a report-only audit. Do not claim that a source-level `strength` parameter, a successful actuator call, differing numeric values, or differing public haptic patterns prove physically adjustable trackpad intensity. Until the user completes the physical comparison described below, call the private route an experimental actuator-strength mechanism, not verified hardware intensity.

## Checkout and protected baseline

Work only in:

`/Users/weiwei/.codex/worktrees/absorb-upstream-oct09/boring-notch-today`

branch:

`codex/absorb-upstream-2026-10-09`

This checkout contains a recovered, resolved, staged-but-uncommitted upstream merge plus later unstaged compact-glance changes. The primary checkout at `/Users/weiwei/code/boring-notch-today` is older architecture and is not the implementation source.

Before editing:
- read the live `AGENTS.md` / `CLAUDE.md` instructions that apply;
- read `docs/Customization.md` and `docs/Upstream-integration-2026-10-13.md`;
- inspect `git status` and the relevant staged/unstaged diffs so pre-existing work is distinguished from yours;
- verify consequential repository details below at execution time rather than assuming the supplied summary is still exact.

Preserve every pre-existing staged and unstaged edit. Do not reset, discard, stage, commit, push, or modify the older primary app source.

Current supplied baseline to verify, not rediscover from scratch:

- Compact Today glance has local Automatic/Hidden, Compact/Full, Compact/Balanced width cap, and 1h/6h/24h/All horizon controls.
- Default compact geometry includes corner/text padding, with at most 56 points per side and a fixed hardware center.
- Eight focused XCTest, standalone schedule regression, offscreen rendering, and unsigned Release previously passed.
- The installed candidate at `/Applications/Boring Notch.app` previously matched executable SHA-256 `ce3ba0c1b1e868b15694c067261e22521ab1595926fd14d4ff5fe48fa44a2b01`.
- Native glance-to-card and settings-default checks passed.
- Human visual acceptance, exact-scroll restart, and live fullscreen/transient hardware journeys remain separate open gates.

Preserve all four tabs, the Today exact `NSClipView` scroll keeper, reminder/focus/deadline behavior, read-only payload/vault boundary, notification/HUD/battery precedence, fullscreen and zero-height hiding, existing gestures, and disabled stock updater feed.

## Haptic facts and claim boundary

The supplied source inventory says:

- `enableHaptics` is an on/off Defaults key, default `true`.
- `ContentView`, `LiveActivityStack`, and `BoringCalendar` use fixed `.sensoryFeedback(.alignment, trigger: haptics)`.
- Their actual hover, open/close, gesture, activity-selection, and calendar trigger sites still need a narrow execution-time inventory.
- There is no existing adjustable-amplitude engine or intensity slider.
- Do not invent slider haptics or any other trigger as existing behavior.

Research already recorded in `Customization.md` establishes only that:
- Apple's SwiftUI `impact(weight:intensity:)` documentation does not establish a macOS Force Touch amplitude route for this use.
- `NSHapticFeedbackPerformer` offers patterns/timing but no public amplitude argument.
- Different public patterns, or an intensity-looking UI that compiles, would not demonstrate genuine strength adjustment.

The experimental candidate is the pinned MIT-licensed Tactile implementation:

`Mason363/Tactile`, revision `a9b02a4e4fae6408058bd876e24accb52a864520`

Relevant source:
`https://github.com/Mason363/Tactile/blob/a9b02a4e4fae6408058bd876e24accb52a864520/Tactile/Engines/ActuatorHapticEngine.swift`

Prior inspection found dynamically loaded MultitouchSupport symbols, trackpad actuator discovery, and a bounded numeric strength supplied to `MTActuatorActuate` for one waveform. Treat all of that as a mechanism hypothesis until independently checked in the pinned source and against the current build/runtime environment.

In particular, do not infer that the argument is continuous, linear, monotonic, perceptually distinct, stable across macOS versions or trackpads, or even interpreted as amplitude merely because the source names or scales it that way.

## Implement this bounded pass

### 1. Establish whether the candidate mechanism is supportable

Inspect the pinned implementation and the current app architecture before adopting code. Record in the existing customization owner:

- the exact pinned source/revision and MIT attribution;
- the symbols and signatures relied upon;
- how trackpads/actuators are discovered and selected;
- handle/object ownership and destruction;
- thread or queue assumptions if present;
- what constitutes a failed actuation;
- what happens when the private framework, symbol, device, or actuator is unavailable;
- any meaningful OS/architecture/device assumptions visible from source or local execution.

At execution time, verify rather than guess the ABI/signature being called, the library/symbol availability on the current system, and the lifecycle behavior needed by this app. Also check how a device disappearance/re-enumeration can invalidate retained state.

If that inspection does not justify a small defensible wrapper, do not force the private mechanism into the app. Preserve the existing supported haptics, document the concrete blocker, and leave the physical-intensity gate pending.

If it is supportable, adapt only the minimum lookup, ownership/lifecycle, and one-shot actuation code required by this experiment, with attribution. Do not import Tactile's global hover monitoring, audio/phone features, continuous-vibration worker, unrelated abstractions, or new permissions.

### 2. Add an explicit experimental test surface

Use existing Settings conventions and keep the UI small.

Expose a clearly labeled experimental trackpad-strength test only when its backend is actually available. It must provide:

- one conservative bounded strength control or a small set of bounded strength values;
- an explicit single-pulse `Test` action;
- zero/off producing no actuation;
- visible unavailable/failure handling that does not pretend public pattern fallback is intensity;
- conservative default and clamping behavior.

The UI and documentation must distinguish:
1. the numeric strength requested from the private actuator mechanism; and
2. user-verified physical intensity.

Do not pulse on startup, relaunch, every slider movement, background activity, or preference restoration. One deliberate Test request should request at most one experimental pulse.

A missing library/symbol/device, enumeration failure, actuation failure, or disconnected/stale device must leave the rest of Boring Notch functional. Do not retain unusable handles indefinitely or keep retrying/stimulating in the background.

### 3. Add only practical supported cue controls justified by the real trigger inventory

First map the existing haptic trigger sites narrowly enough to know what currently fires and whether one user action can reach multiple feedback modifiers.

Keep ordinary app cues on their current supported macOS route by default. The experimental actuator backend must not silently replace routine application feedback before physical acceptance.

Within this pass, add only a small number of settings-backed choices that correspond cleanly to existing behavior, for example separating low-value hover feedback from deliberate open/close, gesture, selection, or calendar/action cues if the live trigger inventory supports that grouping.

Requirements:
- `enableHaptics == false` overrides every ordinary cue and every experimental Test pulse.
- Existing default behavior should remain recognizable when the new choices are untouched.
- Avoid duplicate feedback when multiple existing trigger paths represent the same user action.
- Do not manufacture an elaborate cue taxonomy merely to populate Settings.
- If disentangling supported cue groups proves architecturally large, implement the intensity experiment cleanly and leave the larger cue migration as an explicitly bounded successor instead of coupling it into this pass.

### 4. Verify behavior, persistence, and failure handling

Add focused tests around the boundary rather than tests that simply restate implementation details.

Use a fake/injected actuator boundary where necessary to verify at least:

- settings persistence and default migration;
- invalid stored-value fallback;
- conservative strength clamping;
- zero/off and master-off silence;
- unavailable library/symbol/device behavior;
- failed actuation behavior;
- stale/disconnected device invalidation and safe reacquisition where the chosen lifecycle requires it;
- one backend pulse request for one explicit Test action, with no pulse from ordinary preference editing/restoration.

Do not claim automated tests prove perceived physical intensity.

Run the repository's relevant focused tests plus the existing regressions affected by Settings/haptic changes. Build the actual unsigned Release from this recovered checkout. Report the exact commands and outcomes, including failures or skipped hardware-only checks.

Do not install this new candidate merely because the predecessor had explicit installation authorization for the compact-glance build. Save a runnable/testable candidate and identify what would require a separate installation action.

## Human intensity gate

Prepare a simple physical comparison that the user can perform later.

Use the same actuator/waveform and otherwise identical conditions. Provide three conservative, bounded requested strength values that are sufficiently separated to be worth comparing. Present/request individual pulses in varied order rather than an automatic vibration sequence.

The observation to collect is whether the user can repeatedly distinguish an ordered strength difference under comparable finger contact.

This gate is not passed by:
- successful symbol loading;
- a successful return code;
- values reaching `MTActuatorActuate`;
- screenshots;
- automated tests;
- the agent reporting that values "should" differ.

If the physical trial is not performed, leave the result explicitly as something like `mechanism implemented; physical intensity unverified`. If the user cannot distinguish the values reliably, record that result rather than redefining the numerical parameter as proven intensity.

Do not wake, impersonate, or answer for the user.

## Ownership, documentation, and continuation

The receiving chat has exclusive write ownership for the affected haptic/settings/app/tests, `Customization.md`, the relevant integration-history entry, and corresponding primary documentation mirrors. Its predecessor releases those writes after dispatch.

Do not edit unrelated course, vault, or payload data.

Reconcile the final implementation, evidence, limitations, and still-open human gate in the existing documentation owner. Clearly separate:
- source/runtime facts;
- automated verification;
- mechanism inference;
- physical user acceptance.

Source changes, relevant verification, public source research, ordinary signed-in ChatGPT review, and successor local-chat dispatch are authorized. Commit/push, account/security changes, new permissions, and further app installations are not authorized unless separately requested.

After this bounded pass, continue the established review → fresh local Codex chat → execution cycle only for meaningful remaining roadmap units. Use the existing prompt-roundtrip and daisy-chain-work skills and check for an already-created successor before creating another. Transfer exclusive write ownership and observe initial progress.

Current intended ordering remains:
- O7 Today preferences next;
- O8 presets only after those preferences settle;
- O9 Quick Notes remains a separate optional utility.

O5 physical haptic-intensity acceptance may remain pending while genuinely independent roadmap work proceeds. Do not treat that human gate as passed, block unrelated work merely because it is pending, or create successors after the requested roadmap is exhausted.

If this pass reaches a real user-only or external block, save an exact resume state and stop at that boundary rather than substituting an API/model judgment for the missing physical evidence.
