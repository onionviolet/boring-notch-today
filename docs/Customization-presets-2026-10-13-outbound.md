# Request to the reviewing chat

Improve the bounded O8 implementation prompt below. Challenge consequential assumptions, keep it small and executable, and return one complete replacement work prompt plus a short list of material scope/tradeoff changes. You cannot inspect this Mac or its files. Supplied source observations are context, not a claim that you verified them. Do not execute, dispatch, ask for unrelated permissions or invent runtime acceptance. This is the next unit in an explicitly authorized review → fresh local Codex chat → implementation cycle. O9 Quick Notes is optional and no further successor is required after O8.

# Draft work prompt

Implement one bounded O8 named-presets unit in this personal macOS SwiftUI Boring Notch fork. Provide Study, Quiet and Media presets plus one saved Custom preset, a truthful preview of the changes before explicit Apply, and a reversible way to restore the previous values. Add this to existing Settings → Notch. A preset is a local collection of known preference values, not a general settings framework, automation, account mode or app-wide reset.

## Source, ownership and action limits

All source/test/build/app actions must set workdir to `/Users/weiwei/.codex/worktrees/absorb-upstream-oct09/boring-notch-today`, branch `codex/absorb-upstream-2026-10-09`. The project's default cwd `/Users/weiwei/code/boring-notch-today` is older source. No new worktree. Preserve the resolved staged uncommitted merge and all unstaged O5/O6/O7 changes. Read live applicable AGENTS.md/CLAUDE.md, docs/Today.md, docs/Customization.md, docs/Upstream-integration-2026-10-13.md and the live settings/source/test owners. Check branch/root/dirty state and existing successor/ownership before edits. Save initial relevant diffs and identify this chat in the existing Customization/integration owners. Predecessor `01a133e3-265d-79e0-8c08-f8c61eec5127` transfers affected settings/preset/tests and documentation writes only after successful dispatch; then it will stop writing them. Primary documentation mirrors of Today.md, Customization.md and integration history must stay in sync; primary app source stays untouched.

Already authorized: bounded implementation, relevant tests/research, ordinary signed-in ChatGPT review and one useful fresh local successor. Not authorized: stage, commit, push, install, publish snapshots, alter permissions/accounts/security settings, touch planning-vault/course data or use private live payloads as fixtures. Do not generate endless successors. A built candidate is not an installed or human-accepted app.

## Existing product contract and baseline

There are four tabs: Home, Shelf, Today, D-hall. Today consumes validated schema v1/v2 display snapshots; it never reads the vault, speaks MCP inside the app or writes task completion. Payload actions stay bounded to HTTPS source and fixed Itembank bundle ID. Preserve disabled updater feed, fullscreen hiding, gesture behavior, closed hardware-notch anchoring and notification/HUD/battery precedence.

O6 is installed: Settings → Notch has Closed Notch Glance choices visibility Automatic/Hidden, label Compact/Full, side-width Compact/Balanced, and routine deadline horizon 1h/6h/24h/All. Hidden hides only routine Today glance. The horizon does not change scheduling. Compact caps each side at 56 points with the hardware center anchored; Balanced caps at 80. O6 click navigation selects a Today row and expands/reveals it even under presentation filtering.

O5 source is built but not installed. Default-on Hover/Action cue switches use the existing SwiftUI alignment route. A separate explicit private single-pulse actuator experiment supports Off and requested 0.20/0.45/0.70, gated to an inspected arm64 OS build. Physical intensity is unverified. Do not modify or include this private actuator preference, send a pulse or reopen O5.

O7 source is implemented and verified locally, with native installed/human gates separate. Settings → Notch has Today Presentation:
- New focus sessions: 15/25/45/60 minutes, default 25. Only new sessions read this preference; active persisted endsAt survives changes and restart.
- Work shown: All/Required-only, default All. Only explicit deadline.required metadata determines filtering. Keep no-deadline rows, mixed rows, active focus/reminder targets and explicit glance-navigation targets. Start/Next are unlinked strings and stay visible. Optional retained targets are labeled accurately. No ledger/payload mutation.
- Text density: Current/Compact, default Current. Compact reduces spacing and padding without removing text or actions.
- In-scroll reminders: Standard/Subtle, default Standard. Subtle reduces weight/padding but keeps required/due text, Today/Site/Snooze/Dismiss/checkpoint controls. Quiet hours remain separate.

Today uses exact NSClipView pixel offset persistence, with explicit clamping to current scroll bounds as content shrinks. Do not replace it with SwiftUI anchor restoration.

Relevant owners are NotchSettingsView.swift, TodayView.swift, TodayStore.swift, TodaySchedule.swift, Constants.swift, TodayPresentationTests.swift and TodayGlanceTests.swift. O7 uses AppStorage on existing dotted UserDefaults keys because the Defaults library rejects dotted KVO key names. O6 still uses its existing Defaults keys. Do not rename keys gratuitously or reuse an incompatible abstraction.

## Recommended bounded whitelist

Use these eight known preferences only, with an explicit typed whitelist and value validation:

| Storage key | Type / allowed values | Default |
| --- | --- | --- |
| today.focus.duration | String: 15,25,45,60 | 25 |
| today.presentation | String: all,required | all |
| today.density | String: current,compact | current |
| today.reminder.prominence | String: standard,subtle | standard |
| today.glance.visibility | String: automatic,hidden | automatic |
| today.glance.label | String: compact,full | compact |
| today.glance.width | String: compact,balanced | compact |
| today.glance.horizon | String: hour,sixHours,day,all | all |

This covers display and new-session action choices without changing haptics or other interaction settings. Do not use a generic arbitrary-key dictionary as permission to write any UserDefaults key. Custom, preview, apply, revert and saved bookkeeping must all validate against this same whitelist. No imported/exported raw settings, arbitrary paths, commands, URLs, scripts or external sharing.

Explicit exclusions: active today.focus, today.reminderLedger, quiet-hour keys, payload and bridge files, scroll offsets, permissions/privacy/accounts, updater feeds, vault paths, haptic master/cues/experimental strength, notification delivery, gestures, notch height/geometry, tab configuration and unrelated app preferences. O8 is not an app-wide factory reset. Normal preference changes must not call a haptic tester or create/restart focus.

## Preset behavior and suggested values

Choose restrained useful defaults and document them. Suggested initial built-ins (reviewer may improve the reversible taste choices):
- Study: 25 min, Required-only, Compact, Standard reminders, Automatic glance, Compact label/width, 24h horizon.
- Quiet: 25 min, All, Compact, Subtle reminders, Hidden glance, Compact label/width, All horizon.
- Media: 25 min, All, Current, Standard reminders, Hidden glance, Compact label/width, All horizon.

Quiet means reduced Today presentation only; it does not silence scheduling or enable quiet hours. Hidden still preserves reminders/focus inside Today and unrelated transient activity. If resetting focus duration or invisible glance values would be surprising, use a clear partial built-in mapping for meaningful changes while Custom captures the full whitelist. Show omissions honestly. Keep one clear implementation policy; do not let preview and apply disagree.

Custom: save the current effective whitelist values into one local Custom slot only on explicit Save Custom. Saving must not apply changes, reset the revert record or touch unrelated preferences. Provide an honest no-saved-custom state. No arbitrary settings editor is required. Validate corrupt/unsupported stored Custom data and show a bounded fallback instead of partly applying it.

Selecting a preset shows a human-readable before/after preview for exactly the settings that Apply will write. Preview uses current effective values at the time of Apply, including changes made while the preview was open; avoid a stale overwrite. No side effects on selection/preview/startup. Apply needs a visible explicit button. No-op Apply should say no settings change and should not destroy a useful previous revert snapshot.

Revert: one-level undo of the last preset application, clearly labeled Restore previous settings rather than factory reset. Capture prior values before writing and preserve absent-vs-saved state if needed for meaningful restoration. Persist a bounded versioned before/after record so an app restart does not silently lose offered revert. Bookkeeping records only whitelist keys and validated values. Revert should avoid overwriting a manual edit made after Apply: restore keys still equal to the preset's applied value, keep independently changed keys and report conflicts honestly. Apply then Apply again replaces the previous undo level with the immediate pre-second-Apply state. Revert consumes its own record only after reconciliation. Invalid record state must not permit arbitrary key writes or partially restore unrelated state.

Use the smallest natural existing settings structure and key-storage conventions. Keep code local and typed; no preset/widget framework, extra product tab, background executor or continuous mode switching.

## Acceptance evidence

Use isolated UserDefaults suites and synthetic v1/v2 fixtures. Never reset live user preferences or publish payloads. Verify:
1. Built-in mappings and whitelist validation, custom save/load persistence, no-save and corrupt data handling, defaults/invalid preference normalization, no preview/startup writes.
2. Preview exactly matches apply, including a current-value change while preview is open; no-op preserves prior undo; Apply persists the selected values and only whitelist/bookkeeping keys.
3. Restore previous values across a new defaults instance/restart, absent versus saved values, repeated Apply/Apply/Revert, safe conflict handling when one preference changes manually after Apply, invalid stored records, unrelated keys left byte-identical.
4. Applying/reverting focus duration never changes active focus persisted bytes/endsAt; filtering retains focus/reminder/navigation targets; Quiet/Media never acknowledge/snooze/suppress scheduled reminders or change quiet hours; no haptic pulse, geometry or update feed changes.
5. Focused relevant O7/O6 preference/navigation/scroll/schedule/payload regressions and actual unsigned Release. Obtain useful offscreen Settings preview renders when feasible and inspect readable before/after descriptions, controls and no-saved-custom/revert states.

Keep source edits, passing test slice, unsigned candidate, offscreen runtime, installed native and human acceptance separate. No installation. Record exact commands, failures/reconciliation, logs, candidate path/hash and pending native/human gates in existing owners and documentation mirrors. Preserve staged merge hash. O5 physical gate remains independent. Stop after O8 settles; O9 is optional and no new chain is authorized merely by this prompt.
