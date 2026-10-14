I tightened the unit around one typed preset service and one Settings surface, removed acceptance that would require inventing runtime success, and made preview/apply/revert semantics more deterministic.

Implement one bounded **O8 named-presets** unit in this personal macOS SwiftUI Boring Notch fork.

The outcome is deliberately small: in existing **Settings → Notch**, provide three built-in named presets (**Study, Quiet, Media**), one locally saved **Custom** preset, an explicit human-readable preview before **Apply**, and a one-level **Restore previous settings** action. A preset is only a typed collection of approved existing preference values. Do not turn O8 into a settings framework, account/profile system, automation engine, app-wide reset, import/export feature, or mode that continuously enforces values.

O9 Quick Notes is optional. Finishing O8 does not authorize another successor.

## Repository, ownership, and action limits

For every source, test, build, and app command, explicitly use:

`/Users/weiwei/.codex/worktrees/absorb-upstream-oct09/boring-notch-today`

Expected branch from supplied context:

`codex/absorb-upstream-2026-10-09`

`/Users/weiwei/code/boring-notch-today` is reported to be an older checkout and is not an authorized workdir for this unit.

Before editing, verify at execution time:

- repository root and current branch;
- staged, unstaged, and untracked state;
- that the reported resolved staged-but-uncommitted upstream merge is still present;
- relevant O5/O6/O7 changes and current ownership/successor records;
- applicable `AGENTS.md` / `CLAUDE.md`;
- current `docs/Today.md`, `docs/Customization.md`, `docs/Upstream-integration-2026-10-13.md`;
- live settings, Today, storage, and test owners rather than assuming the filenames below remain authoritative.

Preserve all pre-existing staged and unstaged work. Do not reset, discard, clean, stash over, stage, commit, push, install, publish snapshots, alter account/security/permission state, touch planning-vault/course data, or use private live payloads as fixtures.

The supplied predecessor ID is:

`01a133e3-265d-79e0-8c08-f8c61eec5127`

Treat its ownership transfer as valid only if the live handoff/owner records confirm it. Once confirmed, take write ownership only for the O8-affected settings/preset/tests and corresponding existing documentation owners. Do not expand ownership merely because adjacent files are convenient.

Keep the project's existing primary documentation mirrors synchronized where the live project contract requires that. Do not mutate any separate upstream/reference source checkout.

A successful source build is not installation or human/native acceptance.

## Preserve the existing product contract

Verify consequential details against live source before relying on them, then preserve them.

Reported current contract:

- Tabs are Home, Shelf, Today, D-hall.
- Today consumes validated schema-v1/v2 display snapshots.
- Today does not read the vault, speak MCP from inside the app, or write task completion.
- Payload actions remain bounded to their existing HTTPS source and fixed Itembank bundle ID.
- Preserve updater-feed disablement, fullscreen hiding, gesture behavior, closed hardware-notch anchoring, and notification/HUD/battery precedence.

Reported O6 behavior:

- Settings → Notch includes Closed Notch Glance:
  - visibility: Automatic / Hidden
  - label: Compact / Full
  - side width: Compact / Balanced
  - deadline horizon: 1h / 6h / 24h / All
- Hidden affects routine Today glance only.
- Horizon affects display, not scheduling.
- Compact and Balanced use their existing capped geometry while retaining the hardware center.
- Glance navigation can select a Today row and reveal/expand it despite presentation filtering.

Reported O7 behavior:

- **New focus sessions:** 15 / 25 / 45 / 60 minutes, default 25. Preference affects only newly created sessions; persisted active `endsAt` survives preference changes/restart.
- **Work shown:** All / Required-only, default All. Only explicit `deadline.required` drives filtering. No-deadline rows, mixed rows, active focus/reminder targets, and explicit glance-navigation targets remain available. Start/Next remain visible unlinked strings. Retained optional targets are labeled honestly.
- **Text density:** Current / Compact, default Current. Compact changes spacing/padding without deleting content/actions.
- **In-scroll reminders:** Standard / Subtle, default Standard. Subtle reduces presentation emphasis but preserves required/due information and Today/Site/Snooze/Dismiss/checkpoint controls.
- Quiet hours remain a separate feature.
- Today scroll position uses exact `NSClipView` pixel offsets with clamping. Do not replace that mechanism with SwiftUI anchor restoration.

Reported O5 behavior is explicitly outside O8:

- existing Hover/Action cue controls;
- private single-pulse actuator experiment with Off and requested 0.20 / 0.45 / 0.70 values;
- physical haptic intensity remains unverified.

Do not modify, expose through presets, invoke, or reopen that actuator experiment.

Reported relevant owners include:

- `NotchSettingsView.swift`
- `TodayView.swift`
- `TodayStore.swift`
- `TodaySchedule.swift`
- `Constants.swift`
- `TodayPresentationTests.swift`
- `TodayGlanceTests.swift`

Do not edit all of them by default. Inspect dependencies and touch only what O8 actually requires.

O7 reportedly uses `AppStorage` with dotted `UserDefaults` keys because the project's Defaults abstraction rejects those KVO key names, while O6 uses its existing storage convention. Verify this before extending storage. Do not rename existing keys or force all eight preferences behind a new abstraction merely for uniformity.

## The only preset-controlled preferences

O8 may read and write only this typed whitelist:

| Key | Allowed representation | Effective default |
| --- | --- | --- |
| `today.focus.duration` | String enum: `15`, `25`, `45`, `60` | `25` |
| `today.presentation` | String enum: `all`, `required` | `all` |
| `today.density` | String enum: `current`, `compact` | `current` |
| `today.reminder.prominence` | String enum: `standard`, `subtle` | `standard` |
| `today.glance.visibility` | String enum: `automatic`, `hidden` | `automatic` |
| `today.glance.label` | String enum: `compact`, `full` | `compact` |
| `today.glance.width` | String enum: `compact`, `balanced` | `compact` |
| `today.glance.horizon` | String enum: `hour`, `sixHours`, `day`, `all` | `all` |

At execution time, reconcile these reported key names and encoded values against the actual O6/O7 source before writing anything. If a key/value differs, use the live product representation and record that reconciliation rather than creating a duplicate preference.

Implement the whitelist as a closed typed model with explicit validation. Do not use a generic arbitrary-key dictionary whose API could write any `UserDefaults` key.

Preset data, Custom storage, preview, apply, and restore bookkeeping must all pass through the same closed whitelist and validation rules.

Explicitly excluded:

- active focus/session state;
- `today.reminderLedger`;
- quiet-hour preferences;
- payload/bridge files;
- scroll offsets;
- permissions/privacy/account settings;
- updater configuration;
- vault paths;
- all haptic/cue/experimental strength settings;
- notification-delivery configuration;
- gestures;
- notch height or geometry;
- tab configuration;
- unrelated application preferences.

Applying or restoring a preset must not start/restart focus, invoke haptics, acknowledge/snooze/dismiss reminders, mutate ledger/payload data, or behave as a factory reset.

## Built-in presets

Keep built-ins intentionally modest.

Use these mappings unless live UI semantics reveal a concrete contradiction. If you change one, document the reason and keep preview/apply/tests consistent.

### Study

- focus duration: 25
- work shown: Required-only
- text density: Compact
- reminder prominence: Standard
- glance visibility: Automatic
- glance label: Compact
- glance width: Compact
- glance horizon: 24h

### Quiet

- focus duration: 25
- work shown: All
- text density: Compact
- reminder prominence: Subtle
- glance visibility: Hidden
- glance label: Compact
- glance width: Compact
- glance horizon: All

“Quiet” means quieter **Today presentation only**. It does not activate quiet hours, stop reminder scheduling/delivery, mute the app, or alter haptics.

### Media

- focus duration: 25
- work shown: All
- text density: Current
- reminder prominence: Standard
- glance visibility: Hidden
- glance label: Compact
- glance width: Compact
- glance horizon: All

Do not make built-ins partial merely to avoid writing values that happen to be visually irrelevant while a glance is hidden. A built-in preset should have one deterministic full-whitelist state. Preview must make all actual changes visible; unchanged values need not be presented as changes.

## Custom preset

Provide exactly one local Custom slot.

**Save Custom**:

- happens only through an explicit control;
- captures the current effective values of the full whitelist;
- validates/normalizes each value through the same typed model;
- does not apply any values;
- does not create, clear, or replace the Restore-previous-settings record;
- does not touch unrelated preferences.

Before a Custom preset has been saved, present an honest unavailable/empty state and do not pretend that selecting Custom is an actionable preset.

Persist Custom in a bounded, versioned representation. Store only the closed O8 whitelist and required schema/version metadata.

On corrupt, unknown-version, incomplete, or unsupported Custom data, fail the Custom preset as a unit. Do not partially apply whichever fields happened to decode. The UI should expose a bounded unavailable/invalid state and allow the user to overwrite it with a fresh **Save Custom**.

Do not add import/export, arbitrary editing, multiple Custom slots, preset renaming, file sharing, URLs, scripts, commands, or paths.

## Preview and Apply semantics

Selecting Study, Quiet, Media, or a valid saved Custom preset must not write preferences.

Show a human-readable preview of exactly the values the selected preset would write.

For each changed setting, show enough information to understand:

`Setting: current value → preset value`

Do not rely solely on raw storage keys or encoded strings.

The preview is descriptive, not a captured transaction. Manual preference changes elsewhere while the preview is open must not be overwritten based on stale “before” values.

On **Apply**:

1. re-read and validate the current effective whitelist values;
2. recompute the delta against the selected preset;
3. refresh the visible preview if it is now stale;
4. apply only the selected preset's deterministic whitelist values;
5. create the one-level restore record from the immediately pre-Apply state and the values actually applied.

Do not require a second confirmation solely because the preview changed. The authoritative operation is “apply this named preset to the current settings now”; the Apply path must use freshly read values and the UI must immediately reflect the resulting before/after truth.

If applying would change nothing:

- perform no preference writes;
- show a clear no-settings-changed outcome;
- preserve any existing useful restore record.

Selection, preview rendering, Settings startup, and app startup must have no preset side effects.

## Restore previous settings

Provide exactly one persistent undo level labeled **Restore previous settings** or equivalently explicit language. Never call it reset/factory reset.

After a successful Apply that changed at least one preference, persist a bounded versioned record containing only:

- the whitelist keys written by that Apply;
- each key's validated pre-Apply storage state/value needed for restoration;
- the validated value that Apply wrote;
- required schema/version metadata.

Preserve absent-versus-explicitly-stored state where the live storage semantics make that distinction observable. Effective defaults may be used for comparison, but restoring a previously absent key should remove the explicit value rather than manufacturing one where practical with the existing storage mechanism.

A later successful Apply replaces the prior restore level with the immediate pre-later-Apply state.

Restoration is conflict-aware per key:

- If the current stored/effective value still matches the value O8 applied, restore that key to its recorded previous state.
- If it no longer matches, treat it as a manual/subsequent edit and leave it untouched.
- Report that such a key was retained rather than silently overwriting it.

Do not interpret unrelated key changes as conflicts.

A restore operation may therefore result in:

- all eligible keys restored;
- some keys restored and some retained because they changed afterward;
- no keys changed because every affected setting conflicts.

After one valid restore attempt, consume the record after reconciliation, including the all-conflict case. This preserves a true one-level undo instead of allowing an old snapshot to overwrite later edits on a future attempt.

Malformed, unsupported-version, or non-whitelist restore data must disable restoration safely. Never use malformed data to select arbitrary keys, and never partially restore a record whose structure or values fail validation.

A no-op Apply must not consume or replace the existing restore record.

## Implementation shape

Use the smallest natural structure supported by the live codebase.

Prefer:

- one closed typed representation for the eight preset values;
- small preset/storage/apply/restore helpers that can be tested independently;
- a compact Settings → Notch section that reuses existing controls and terminology.

Avoid:

- a general settings registry;
- arbitrary `[String: Any]` write APIs;
- protocol/framework layers created only for hypothetical future presets;
- a new tab/window/widget;
- background execution;
- continuous preset enforcement;
- mode switching triggered by media/focus/system state.

Keep O8 separable from O5 physical-haptic acceptance.

## Verification

Use isolated/synthetic preference stores or test suites. Never clear or mutate the user's live preference domain to make tests pass.

Add focused tests that make the following observable where supported by the live test architecture:

1. **Whitelist and built-ins**
   - each built-in resolves to its documented full-whitelist mapping;
   - only approved keys/values can enter a preset operation;
   - invalid live values resolve according to the existing preference's effective-default behavior rather than expanding the accepted domain.

2. **Custom**
   - explicit save/load survives a fresh storage instance;
   - no-saved state is distinct from a valid Custom preset;
   - corrupt, incomplete, unsupported-version, or invalid-valued Custom data cannot be partly applied;
   - Save Custom neither applies values nor alters an existing restore record.

3. **Preview/apply**
   - selecting/rendering a preset writes nothing;
   - preview descriptions derive from the same typed target values used by Apply;
   - changing a current preference after initial preview but before Apply causes Apply to use the newly read current state;
   - no-op Apply performs no preference mutation and retains the existing undo;
   - changed Apply writes only approved preference keys plus bounded O8 bookkeeping.

4. **Restore**
   - restore survives reconstruction with a fresh storage/defaults instance;
   - absent and explicitly saved prior values are restored appropriately where the storage API permits that distinction;
   - Apply A → Apply B → Restore yields the immediate pre-B state, not the pre-A state;
   - a manually modified post-Apply key is retained while unaffected applied keys restore;
   - an all-conflict restore makes no setting change and consumes the undo;
   - malformed/unsupported restore records cannot cause arbitrary or partial writes;
   - unrelated sentinel keys remain unchanged.

5. **Behavioral boundaries**
   - changing focus-duration preference through Apply/Restore does not mutate persisted active-focus state or `endsAt`;
   - existing filtering retention for focus/reminder/navigation targets remains intact;
   - Quiet/Media preset application does not acknowledge, snooze, dismiss, or suppress scheduled reminder state and does not modify quiet-hour settings;
   - no O5 haptic preference/actuator, updater setting, notch geometry, gesture, payload, scroll-offset, or tab setting is written by O8.

Run the smallest relevant regression set covering the affected O6/O7 settings/navigation/filtering behavior, then the project's applicable broader check if required by live project instructions.

Attempt an unsigned Release build using the project's existing procedure. Do not install it.

If the project already supports safe offscreen/non-installed Settings rendering, use it to inspect:

- Study/Quiet/Media selection;
- Custom unavailable and saved states;
- readable before/after preview;
- explicit Apply;
- available Restore previous settings;
- no-op state;
- conflict/partial-restore messaging if naturally renderable.

Do not invent, simulate as fact, or claim successful runtime/native/UI acceptance when the available environment cannot produce it. Record unavailable checks as pending gates rather than weakening them.

## Finish and evidence

Before stopping:

- inspect the final diff against the initial dirty state so pre-existing work is distinguishable from O8;
- verify no forbidden files/keys/actions entered the change;
- preserve the pre-existing staged merge rather than staging new O8 work;
- synchronize the existing Today/Customization/integration documentation mirrors only to the extent required by their live ownership contract.

Record, in the existing project owners/history rather than creating a new reporting framework:

- source/repository/branch checks and any supplied-context discrepancies;
- O8 files changed;
- exact relevant test/build commands and results;
- failures and reconciliation;
- any safe offscreen inspection performed;
- unsigned candidate path and hash if a candidate was successfully produced;
- installed/native/human acceptance as explicitly **not performed / pending**;
- O5 physical-haptic acceptance as separate and unchanged;
- any remaining O8 issue that materially prevents this unit from being considered source-complete.

Stop when O8 is source-complete or when a concrete blocker is documented. Do not open O9, create another implementation chain, or manufacture follow-up work merely because O8 finished.

Material changes:

- **Made built-ins deterministic full-whitelist presets.** The draft entertained partial built-ins, which complicates preview, undo, and user expectations. Custom and built-ins now share one clear state model.
- **Resolved the stale-preview contradiction.** Apply re-reads current values and recomputes the delta. The preview is informational rather than a transaction snapshot, so intervening manual changes are not overwritten from stale state.
- **Defined restore consumption and conflicts precisely.** Partial and all-conflict restores now have deterministic behavior, and an attempted restore consumes the single undo level after reconciliation.
- **Separated effective values from stored state.** Comparison may use effective defaults, while undo preserves absence when meaningful, avoiding accidental creation of explicit defaults.
- **Reduced framework pressure.** The prompt asks for a closed typed model and small helpers, not a generalized settings registry or future-facing preset architecture.
- **Made acceptance evidence honest.** Offscreen UI inspection is conditional on an existing safe mechanism, Release build is attempted rather than presumed successful, and installed/native/human gates cannot be fabricated.
- **Narrowed file ownership.** The listed files are leads to inspect, not an implicit requirement to edit every O6/O7 owner.
