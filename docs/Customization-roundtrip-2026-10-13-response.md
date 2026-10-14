I tightened the draft around evidence, authority boundaries, sequencing, haptic honesty, and observable gates while keeping all five customization areas explicit.

# Boring Notch customization planning pass

Review the current personal Boring Notch fork and produce a source-bound customization plan for the next implementation pass.

This is a **planning and discovery task, not an implementation task**. Complete the investigation and leave behind a reviewable plan plus a bounded implementation prompt for the first slice. Do not implement the customization work yourself.

## 1. Objective

The product goal is a **useful, unobtrusive, customizable closed notch** that surfaces high-value information beside the MacBook hardware notch without becoming a persistent expanded panel that obstructs browser or application controls.

The user has explicitly approved using the horizontal space beside the hardware notch after a previous deadline banner interfered with browser toolbar controls.

Plan customization across all five requested areas:

- **O6: closed-notch wing/content editor**
- **O5: haptics, including a genuine intensity investigation**
- **O7: Today presentation and focus customization**
- **O8: named presets**
- **O9: Quick Notes**

You may recommend staged delivery, defer individual subfeatures for evidence or complexity reasons, or revise their order. Do **not** drop any of the five areas from the roadmap.

Do not silently substitute different pulse patterns, repetition, or cue selection for genuine haptic-strength control. If true adjustable strength is not safely or reliably achievable, say so plainly.

---

## 2. Authorization and boundaries

### Authorized in this pass

You may:

- inspect relevant source, tests, project documentation and Git state read-only;
- inspect the recovered integration and both supplied checkouts;
- research relevant upstream/fork implementations and official platform documentation;
- run non-destructive source/build/test discovery commands when appropriate to understand the current implementation;
- update the project's planning/documentation files where project instructions permit, especially `docs/Customization.md`;
- prepare concrete behavior specifications, dependency maps, test plans, hardware trials and future implementation prompts.

### Not authorized in this pass

Do not:

- change application source code or tests as implementation work;
- install or replace the app;
- download or install third-party applications, packages or tools merely to trial a feature;
- commit, push or publish;
- change permissions or system settings;
- modify global trackpad or haptic settings;
- alter updater feeds;
- create another agent/chat or delegate work unless separately authorized;
- mutate the planning vault or authoritative task data;
- claim runtime, physical-device or implementation evidence that you did not actually obtain.

Ordinary project-documentation updates are planning work, not implementation, but preserve unrelated edits and follow repository instructions before writing anything.

---

## 3. Authority model and product invariants

Treat these as design constraints unless local project instructions or current source establish a more recent explicit decision.

### Planning authority

The planning vault is the authoritative source of task state.

Today is a **one-way, read-only projection** of a validated local JSON snapshot. It is not a task manager and must not become an alternate completion system.

The app:

- does not scan the planning vault;
- does not speak MCP directly;
- consumes snapshots produced by a separate stdio MCP/CLI publisher;
- may consume schema-v1/v2 payloads only after validation.

Opening a card or source site, dismissing or snoozing a reminder, or finishing a focus session must not mark authoritative work complete.

Source actions are validated HTTPS links. Itembank uses its fixed bundle identifier. Do not introduce arbitrary commands, filesystem paths, prompts or executable actions as customization values.

### Closed-notch invariants

Unless evidence justifies a deliberate future decision otherwise:

- preserve normal hardware-notch closed height;
- preserve visual center clearance around the physical notch;
- avoid routine controls occupying application/browser toolbar space below it;
- transient critical system/application states must have explicit precedence rather than colliding visually;
- defaults must preserve the current useful behavior for an existing user after upgrade;
- hidden/fullscreen/quiet states must continue to suppress UI where appropriate;
- customization must remain understandable without becoming a general extension/plugin framework.

---

## 4. Supplied baseline: verify before relying on it

These are **supplied context, not permission to assume the local tree still matches it**. Verify consequential claims in source/Git state before using them in recommendations. Record discrepancies rather than silently normalizing them.

### Checkouts

Two checkouts are believed to exist:

1. Primary repository:

   `/Users/weiwei/code/boring-notch-today`

   supplied branch: `codex/atoll-fixes`

   This may contain older application architecture plus preserved local work.

2. Recovered/newer integration:

   `/Users/weiwei/.codex/worktrees/absorb-upstream-oct09/boring-notch-today`

   supplied branch: `codex/absorb-upstream-2026-10-09`

   This is believed to correspond more closely to the currently installed application.

Read `CLAUDE.md` first and follow it.

Verify repository root, current branch/worktree and relevant Git state before treating either checkout as authoritative. Do not accidentally design against the older implementation simply because the primary path is more obvious.

### Recovered integration history

Supplied history says the former integration directory disappeared. Its surviving Git index contained the resolved October 9 upstream merge plus D-hall changes, and `checkout-index` was used to recreate that staged snapshot.

Therefore:

- staged recovered content may be meaningful;
- missing unstaged or untracked files are **not** known to have been recovered;
- absence from the recovered snapshot does not prove a feature never existed;
- do not reset, clean, restage or otherwise disturb this state;
- do not claim provenance for files beyond what Git/source evidence supports.

The primary checkout's newer Today deadline/focus payload, store, view, schedule, bridge and tests are said to have been carried into the recovered newer architecture. Verify what is actually present.

### Installed application

Supplied installed path:

`/Applications/Boring Notch.app`

Supplied executable:

`Contents/MacOS/Boring Notch`

Supplied current tabs:

- Home
- Shelf
- Today
- D-hall

Upstream settings, display support, camera lifecycle, notification capture and media runtime are believed to remain present.

Stock Sparkle automatic-update/feed behavior is intentionally disabled for this personal fork. Preserve that policy in all recommendations and future implementation prompts.

This is a **personal local customization project**, not a signed distribution/release-engineering project.

---

## 5. Current closed-notch behavior to verify

The supplied current UI behavior is:

- `TodayNotchGlance` uses two fixed approximately 90-point side wings;
- it remains at normal hardware-notch closed height;
- the left side shows work title;
- the right side shows a short countdown, reminder or focus state;
- there is no lower persistent closed-notch strip;
- routine deadline content appears when music is not playing and no inline song-change peek is active;
- due reminders/focus may outrank ordinary deadline content;
- notifications, battery notices and system HUD retain earlier precedence branches;
- hidden fullscreen and zero-height notch states suppress the glance;
- clicking the glance opens Today and expands the matching card;
- detailed reminder controls live inside Today's scrollable UI rather than above other applications.

Supplied native inspection previously observed a 38-point deadline glance and click-to-card behavior.

Treat that as historical evidence only. Verify source behavior before designing around it, and do not represent prior inspection as verification of proposed changes.

---

## 6. Existing customization: do not rediscover it as missing

Supplied customization already includes some combination of:

- notch heights;
- hover delay;
- gesture sensitivity and direction;
- animation speed;
- compact Home;
- accent colors;
- tab visibility.

Verify these against the current tree.

Do not fill the roadmap with already-existing settings unless the task is to integrate or rationalize them with the new customization model.

Known requested gaps are believed to include:

- wing/content-priority customization;
- named presets;
- per-cue haptic controls;
- adjustable Today focus duration.

Today is also believed to have:

- fixed 25-minute local focus;
- persistent focus/reminder ledger state;
- snoozes;
- quiet hours;
- schedule checks.

Verify before depending on those details.

---

# 7. Workstream O6: closed-notch wing editor

Design a bounded closed-notch customization system rather than a general extension architecture.

At minimum investigate and specify control over:

- deadline visibility;
- focus visibility;
- music visibility;
- battery visibility where compatible with existing precedence;
- content priority;
- maximum usable wing width;
- upcoming-deadline visibility horizon;
- hidden/quiet mode behavior.

Resolve rather than merely mention these design questions:

### Wing geometry

Determine whether:

- left and right wings should remain symmetric;
- a hidden source should leave empty reserved width;
- the remaining side should be allowed to grow;
- asymmetry risks making the hardware notch appear visually off-center;
- maximum width should be global, per-wing or derived from screen/notch geometry.

Prefer a small number of explainable layout rules over free-form positioning.

### Content priority

Map the current precedence system before proposing customization.

Explicitly separate:

1. user-selectable routine content;
2. transient application activity such as media changes;
3. urgent Today cues;
4. notification/battery/system HUD behavior;
5. states that must suppress the closed glance entirely.

Do not allow a user priority selector to accidentally disable safety/system/transient behaviors that were never intended to be ordinary selectable content.

If precedence must remain partly fixed, explain exactly which layer is fixed and which layer the user controls.

### Text and interactions

Specify behavior for:

- long task/work titles;
- long countdown/status values;
- localization-sized text if relevant;
- truncation versus replacement with shorter forms;
- one wing hidden;
- both wings hidden;
- music beginning or ending;
- deadline becoming due while media is active;
- focus start/end;
- reminder becoming urgent;
- display/notch geometry changes;
- click targets when only one side contains content.

Maintain valid hit targets without creating invisible clickable regions over unrelated screen content.

### First-slice expectation

Unless evidence points strongly elsewhere, O6 should be the leading implementation candidate because it directly addresses the user's core request for a useful customizable notch.

Produce a deliberately bounded v1 rather than solving every possible combination.

---

# 8. Workstream O5: haptics

Treat this as **two separate problems**:

1. supported cue customization using public/known mechanisms;
2. investigation of genuine physical output strength.

Do not merge them.

## 8.1 Establish the existing implementation

Inventory every app-owned haptic trigger relevant to customization.

At minimum inspect for cues associated with:

- notch alignment/hover;
- notch open;
- notch close;
- gestures;
- sliders or snapping controls;
- calendar/date controls;
- Today interactions;
- any other shared haptic helper.

Determine whether all app cues actually respect the existing global `enableHaptics` preference.

"Off" must eventually mean no app-generated haptic cue from the covered system, not merely no notch-hover cue.

Do not assume trigger names from this prompt. Use actual source symbols.

## 8.2 Public API constraint

Supplied research says:

- the current implementation uses a SwiftUI alignment cue plus `enableHaptics`;
- no intensity setting was found in the previously inspected source/settings;
- absence in current/recovered source does not prove missing unstaged files never had one;
- SwiftUI `sensoryFeedback` / `impact(weight:intensity:)` may compile on macOS while Apple's documentation limits playback support for that form to iOS/watchOS;
- AppKit's public `NSHapticFeedbackPerformer` exposes pattern/timing rather than an amplitude control.

Re-check consequential API claims against current official Apple documentation and the local SDK headers/source interface where useful.

Do not describe pattern choice as amplitude control.

## 8.3 Supported haptic controls

Plan an honest public-API customization model such as:

- global enable/disable;
- cue-by-cue enable/disable;
- where meaningful, supported pattern selection;
- a "Test feedback" action.

Keep the setting vocabulary technically accurate.

Avoid turning each tiny UI interaction into a separate preference if grouping produces a clearer product.

## 8.4 Genuine intensity trial

Investigate whether this particular personal Mac app can access **real actuator-strength/amplitude control** on supported Force Touch hardware.

A private actuator path is not categorically prohibited for this private local fork, but recommending it requires evidence.

For every candidate mechanism establish:

- actual API/mechanism used;
- whether the value controls physical strength or merely pattern/repetition/timing;
- macOS versions and hardware it appears to support;
- architecture/runtime assumptions;
- whether private frameworks, symbols, entitlements or permissions are involved;
- compile/link/runtime risks;
- App Store/signing implications even though this is not an App Store project;
- licensing/provenance if borrowing implementation ideas;
- failure behavior on unsupported devices;
- how the feature can be disabled without destabilizing ordinary haptics.

Do not recommend changing the user's global trackpad strength preference as the implementation of an app-specific slider.

Do not add new security/accessibility/input permissions merely to obtain intensity without explicit later authorization.

### Physical acceptance requirement

Compilation, symbol lookup, screenshots and automated tests cannot prove perceived strength.

A genuine intensity feature must ultimately have a user-observed hardware trial such as:

- Low
- Medium
- High

or equivalent values, played through the **same event and same pattern**, with the user confirming that the physical strength is meaningfully different.

Until then label the outcome:

- `supported and physically verified`,
- `mechanism available but physical effect unverified`,
- `pattern-only`,
- `unsupported`, or
- `unknown`.

Do not use stronger language than the evidence permits.

---

# 9. Workstream O7: Today customization

Plan user controls for Today while preserving the one-way projection model.

At minimum evaluate:

- focus duration;
- deadline horizon;
- required/optional work filtering;
- information density;
- reminder prominence.

### Focus duration

Resolve:

- valid minimum/maximum/step values;
- default preserving the existing 25-minute behavior;
- whether the duration is read only when starting a session;
- what changing the preference does while a focus session is already running;
- ledger/restart implications.

Prefer not to mutate a running timer simply because its default preference changed unless that behavior is explicitly justified.

### Deadline horizon

Clarify the distinction between:

- what exists in the source snapshot;
- what Today displays;
- what the closed-notch glance displays.

A visibility horizon is a presentation filter, not task-state mutation.

### Required versus optional work

If optional work can be hidden:

- keep it discoverable;
- show that a filter is active;
- avoid making users infer that filtered work no longer exists;
- preserve authoritative task data unchanged.

### Density/reminder prominence

Specify concrete layout effects rather than ambiguous labels like "compact" and "comfortable" unless their differences are observable.

Settings must not move detailed reminder controls back into a screen-overlay area that interferes with other applications.

---

# 10. Workstream O8: named presets

Plan presets only after the underlying preference semantics are stable enough that a preset has predictable meaning.

Candidate presets:

- Study
- Quiet
- Media
- Custom/current configuration

Treat names as proposals rather than mandatory implementation labels if better names emerge.

Presets should cover a **small explicit whitelist** of presentation/interaction preferences.

Possible categories include:

- wing content/priority;
- Today display preferences;
- haptic cue preferences;
- visual density;
- other directly related customization settings confirmed during investigation.

Explicitly exclude:

- permissions;
- updater/feed configuration;
- planning-vault paths;
- JSON payload contents;
- task state;
- arbitrary paths/commands;
- unrelated application preferences.

For each preset design:

- exact preferences it changes;
- exact preferences it leaves untouched;
- how the UI exposes the affected set;
- what happens after the user manually diverges from a preset;
- reset/revert behavior;
- whether presets save snapshots of values or represent continuously evolving named policies.

Prefer understandable deterministic behavior over a hidden "magic mode."

---

# 11. Workstream O9: Quick Notes

Treat Quick Notes as optional and lower priority unless discovery reveals a particularly strong fit with the existing application.

Desired concept:

- lightweight local scratchpad;
- explicit copy;
- explicit clear;
- no automatic vault write;
- no task creation;
- no continuous clipboard capture;
- no arbitrary command execution.

Research the comparable feature family in Not So Boring Notch:

`https://github.com/Cris2907/not-so-boring-notch`

Before proposing adaptation, inspect:

- storage mechanism;
- persistence/retention;
- clear/delete semantics;
- keyboard/focus behavior;
- interaction with notch expansion;
- whether notes can accidentally obscure media/Today controls;
- relevant source license and attribution obligations.

Do not import or recreate its whole extension framework merely to obtain a scratchpad.

Also ask whether a notch-resident scratchpad genuinely advances this project's core value or whether it creates a second notes silo. A "later/not yet" recommendation is acceptable, but O9 must remain visible in the roadmap.

---

# 12. Entry points to verify

Supplied likely source entry points include:

- `boringNotch/ContentView.swift`
  - activity precedence
  - notch shape
  - hover/input routing

- `components/Today/TodayView.swift`
  - `TodayNotchGlance`
  - reminder UI
  - cards

- `TodayStore.swift`
- `TodaySchedule.swift`
  - timing
  - persistence/ledger
  - focus behavior

- `components/Settings/Views/NotchSettingsView.swift`
- `components/Settings/Views/AppearanceSettingsView.swift`

- `models/Constants.swift`
  - defaults/preferences

Treat these as navigation hints, not guaranteed current paths or symbol names.

Search before inventing new type names or assuming ownership.

Likely project documentation:

- `CLAUDE.md`
- `docs/Today.md`
- `docs/Customization.md`
- `docs/Upstream-integration-2026-10-13.md`

Follow repository instructions and preserve local/concurrent edits.

---

# 13. External research and forks

Prior scouting reportedly considered:

- Atoll
- Not So Boring Notch
- BoringNotchPlus
- servitola
- QuotaNotch

Useful fixes already said to be adapted include:

- artwork downsampling;
- gesture momentum guards;
- paired media timing;
- invalid-duration slider protection;
- battery centering;
- an IOKit resource-release fix.

Do not re-present these as proposed new customization wins unless they materially affect one of the five requested workstreams.

Treat all other fork features as **leads**, not verified local capabilities or accepted designs.

For changing upstream/tool/API facts, prefer:

1. current source in the relevant upstream project;
2. official Apple documentation/SDK interface;
3. maintained fork source;
4. issues/discussions or secondary reporting as supporting evidence.

Record the source and relevant revision/date for consequential external findings where practical.

Check licensing before recommending code adaptation.

---

# 14. Required analysis

Produce a source-bound capability and dependency map rather than a feature wishlist.

For each requested area capture:

| Field | Required content |
|---|---|
| Current behavior | What the verified current tree actually does |
| User problem | Why the customization matters |
| Proposed v1 | Smallest coherent useful behavior |
| Later possibilities | Worthwhile expansions not required initially |
| Preferences/state touched | Actual or proposed settings |
| Integration points | Verified files/symbol areas |
| Dependencies | Work that must precede it |
| Conflicts | Interaction with media, Today, transient HUD, displays, etc. |
| Risk/cost | Low/medium/high plus reason |
| Evidence | Source/API/fork basis |
| Unknowns | Questions that remain genuinely unresolved |
| Acceptance | Observable pass/fail behavior |

Do not mark a feature "easy" merely because its settings UI is simple. Include the state, precedence, persistence and interaction cost.

---

# 15. Rank by user value and coupling

After investigation, produce a recommended sequence.

Start from, but do not blindly preserve, this supplied hypothesis:

1. O6 wing editor
2. O5 public haptic controls plus genuine intensity investigation
3. O7 Today customization
4. O8 presets
5. O9 Quick Notes

Separate **research order** from **implementation order** where useful.

For example, the genuine haptic mechanism investigation may happen early even if shipping an intensity control happens later.

Explain any reordered dependency.

Prefer several complete, reviewable slices over one customization mega-pass.

---

# 16. Design the first implementation slice

Choose the strongest first implementation slice after source inspection.

Unless evidence suggests otherwise, prefer a bounded O6 slice.

The first slice must have a specific product contract.

For an O6-first slice, define something approximately as bounded as:

- a small fixed set of supported left/right content selections or modes;
- a well-defined routine-content precedence model;
- a maximum-width control or a small width choice;
- deadline-horizon control if it fits cleanly;
- an explicit hidden option;
- preserved current layout as the default.

Do not turn v1 into arbitrary drag/drop widgets, plugin slots or free-form layout composition.

Specify:

- exact Settings placement;
- exact user-facing controls;
- default values;
- persistence;
- migration behavior for existing users;
- invalid-state handling;
- interaction with existing media/notification/battery/Today branches;
- accessibility considerations;
- testable geometry rules;
- runtime inspection scenarios.

If an alternative first slice has materially higher value or lower coupling, justify the change with verified evidence.

---

# 17. Acceptance contract for future implementation

The future implementation prompt must require observable outcomes, not just compilation.

At minimum cover the applicable items below.

## Preferences

- New preferences survive application restart.
- Existing users receive defaults that preserve the current useful layout and behavior.
- Invalid/stale stored values fall back safely.
- Reset/default behavior is explicit.

## Closed-notch geometry

For every supported combination in the first slice:

- physical-notch center clearance remains correct;
- ordinary closed-notch height remains within the intended normal height;
- configured width limits are respected;
- no lower routine strip covers application/browser toolbar controls;
- long text is bounded predictably;
- hiding one or both routine sources has defined geometry;
- click targets correspond to visible content;
- hidden UI does not leave inappropriate invisible click interception.

Do not assert geometry from screenshots alone where source/runtime inspection can test it more directly.

## Activity precedence

Exercise relevant transitions, such as:

- idle to deadline;
- deadline to media;
- media back to deadline;
- normal deadline to due reminder;
- focus start/end;
- battery/system HUD paths;
- hidden/fullscreen/zero-height suppression.

Document expected precedence before implementation testing.

## Today navigation

Where the first slice touches Today integration:

- click-to-Today still selects/expands the intended item;
- card navigation remains valid;
- scroll behavior does not regress;
- detailed controls remain in their intended Today space rather than covering unrelated application content.

## Haptics

For any shipped haptic-control slice:

- global Off suppresses all covered app-generated cues;
- per-cue settings affect the documented trigger set;
- unsupported hardware/API paths degrade without crashes or repeated errors;
- a test action exercises the actual configured mechanism.

For true amplitude/intensity:

- automated tests may validate configuration and routing;
- the feature cannot be marked physically accepted until a user performs a real-hardware comparison.

## Today controls

- focus-duration settings do not corrupt or silently rewrite an active session;
- presentation filters do not mutate authoritative task/deadline state;
- optional work remains discoverable;
- deadline horizons are presentation logic only;
- restart/persistence behavior is tested.

## Presets

- only the documented whitelist changes;
- unrelated preferences remain untouched;
- the user can see what a preset affects;
- manual divergence has defined behavior;
- reset/revert is testable.

## Quick Notes

If eventually implemented:

- data location and persistence are explicit;
- clear actually clears;
- no implicit vault/task write occurs;
- no continuous clipboard collection occurs;
- keyboard focus and notch open/close behavior are tested.

---

# 18. Build/test/runtime gates for future implementation

Do not inherit historical test counts as current proof.

Supplied historical evidence says:

- 105/105 XCTest tests passed before the most recent compact-UI change;
- that subsequent UI version built as unsigned Release and received installed native inspection.

Treat those as historical checkpoints only.

For each future implementation slice:

1. run the meaningful changed-unit/logic tests;
2. run the repository-prescribed broader test/check gate;
3. build the actual Release configuration intended for local use;
4. report exact results rather than "tests pass";
5. only perform replacement/install/runtime inspection if separately authorized.

Do not claim:

- old tests cover new customization;
- signed distribution works;
- physical haptics work;
- camera/display-switching behavior remains valid after changes;

unless those things were actually tested in the relevant pass.

For a later authorized local install, preserve a temporary rollback of the currently working `/Applications/Boring Notch.app` until the replacement launches successfully from Applications. Remove only that update's rollback copy after successful launch, following the user's recorded local-update preference.

Do not broaden that instruction into general cleanup of older backups.

---

# 19. Required deliverables for this planning pass

Complete the planning work, not merely an outline for planning it.

Produce all of the following:

### A. Verified capability map

A concise map of:

- relevant existing preferences;
- current closed-notch content/precedence;
- Today/focus state;
- haptic trigger architecture;
- persistence mechanism;
- Settings structure;
- relevant test coverage.

Clearly distinguish:

- verified in current source;
- supplied historical context;
- external research;
- unresolved.

### B. Five-area roadmap

Cover O5 through O9.

For each give:

- v1 recommendation;
- dependencies;
- cost/risk;
- user value;
- deferral rationale if any;
- observable acceptance.

### C. First-slice product specification

Give the concrete first implementation slice enough detail that a fresh implementation session can execute it without re-deciding basic product behavior.

### D. Haptic investigation packet

Provide:

- public supported controls;
- trigger inventory;
- genuine-intensity candidates investigated;
- mechanism/evidence for each;
- compatibility/risk assessment;
- exact physical hardware acceptance procedure;
- current conclusion status: verified / unverified / unsupported / unknown.

### E. Later sequence

Show which slices follow and why.

Presets should normally follow stabilization of the preferences they operate on.

### F. Documentation update

Where repository instructions allow, update `docs/Customization.md` with the planning results.

Separate:

- **verified current behavior**;
- **recommendations**;
- **open questions**;
- **accepted decisions**.

Do not silently convert recommendations into accepted decisions.

Preserve existing IDs/owners/conventions if the project already uses them.

### G. Executable first-slice implementation prompt

Finish by writing one self-contained prompt for a fresh local implementation session.

That prompt must:

- identify the correct checkout selection/verification procedure rather than assuming a path blindly;
- require reading project instructions;
- protect the staged recovered integration and unrelated edits;
- state exact first-slice scope and exclusions;
- identify verified likely integration areas without inventing types;
- include observable tests and Release-build gates;
- prohibit install/commit/push unless independently authorized;
- preserve updater-disabled behavior;
- preserve the planning-vault/Today authority boundary;
- include rollback requirements only for a separately authorized future install.

The implementation prompt is a handoff artifact, not authorization to execute it now.

---

# 20. Stopping gate

This planning pass is complete only when:

- both checkout/source-authority ambiguity and relevant Git state have been examined enough to identify the correct basis for future work;
- all five requested customization areas have a source-bound disposition;
- the closed-notch first slice has concrete behavior rather than feature labels;
- current activity precedence has been mapped sufficiently to avoid designing conflicting settings;
- haptic pattern customization and genuine intensity are explicitly separated;
- true-intensity claims are tied to an actual mechanism and marked physically unverified until user comparison;
- dependencies among O6/O5/O7/O8/O9 are explicit;
- acceptance criteria are observable;
- documentation clearly separates evidence, recommendations, unknowns and decisions;
- a fresh implementation session could execute the first slice from the final handoff prompt without needing to reinterpret the overall product direction.

If a consequential fact cannot be established without destructive action, installation, new permissions or physical user input, stop at `unknown` or `requires later authorized trial`. Do not manufacture certainty to close the planning pass.

Material changes: I made the two-checkout situation an explicit **source-authority gate** instead of letting the future agent implicitly trust the newer-looking path; separated haptic **cue customization from genuine actuator amplitude** with evidence/status labels and a physical acceptance protocol; and turned O6 from a feature list into a geometry, precedence, text, and interaction problem with concrete decisions the planning pass must resolve.

I also made the five areas share a consistent capability/dependency/acceptance framework, distinguished research order from implementation order, and constrained presets and Quick Notes to avoid them becoming hidden configuration or extension systems. The stopping gate is stronger: the planning pass cannot finish with vague recommendations, while unknown hardware or lost-file facts may remain explicitly unknown rather than being guessed.