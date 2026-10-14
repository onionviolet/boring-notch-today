Here is a tighter replacement that preserves O7 while making the ambiguous filter, reminder, persistence, and chain boundaries explicit.

You are implementing the bounded **O7 Today presentation-preferences pass** for the personal macOS Boring Notch fork.

## Mission

Complete O7 as one coherent implementation unit: add the remaining Today presentation preferences, integrate them into the existing Today behavior without duplicating O6 controls or changing scheduling semantics, prove the important behavior with focused automated and native build evidence, reconcile the project documentation, and leave a precise terminal state.

This is implementation authorization for O7, not a general Today redesign, renderer rewrite, settings framework, vault integration, notification overhaul, or invitation to generate an indefinite chain of successor chats.

The user's requested O7 outcomes are:

1. configurable focus duration for **new** focus sessions;
2. All vs Required-only Today presentation;
3. Current vs Compact text density;
4. a small reminder-prominence preference affecting the existing in-scroll reminder presentation.

The O6 deadline horizon is already a separate control. Do not recreate it or change its meaning.

O5 physical haptic-intensity acceptance is independent of O7. Do not modify that backend, install a build to test it, or gate O7 completion on physical hardware verification.

---

## Repository and write boundary

Authoritative implementation checkout:

`/Users/weiwei/.codex/worktrees/absorb-upstream-oct09/boring-notch-today`

Expected branch:

`codex/absorb-upstream-2026-10-09`

The normal project path:

`/Users/weiwei/code/boring-notch-today`

is reported to be an older source checkout and is **not** an authorized workdir for source, test, build, or app actions in this pass.

Before doing anything consequential, verify at execution time:

- `pwd`;
- repository root;
- current branch;
- worktree identity;
- `git status --short`;
- staged and unstaged diffs relevant to Today/settings/tests/docs;
- applicable repository instruction files;
- whether another live successor/owner already claims overlapping writes.

If the recovered checkout or branch does not match the supplied description, stop before edits and record the discrepancy rather than silently switching repositories.

Preserve the resolved staged-but-uncommitted upstream merge and all existing unstaged O5/O6 work. Do not reset, discard, stash destructively, stage, commit, push, install, create another worktree, change permissions, publish payloads, or edit vault/course data.

Read before editing:

- live `CLAUDE.md`;
- every applicable `AGENTS.md`;
- `docs/Today.md`;
- `docs/Customization.md`;
- `docs/Upstream-integration-2026-10-13.md`;
- the live code and tests that actually own Today presentation, focus persistence, reminder presentation, preferences, and scroll restoration.

Treat the behavioral descriptions below as supplied observations. Verify consequential implementation details against live source rather than assuming paths, type names, or storage ownership.

Record this chat/session identity and the initial repository state in the project's existing ownership mechanism if the live project instructions require it. Do not invent a second ownership system.

---

## Existing behavior to preserve

Supplied observations to reconcile with live source:

- Product tabs are Home, Shelf, Today, and D-hall.
- Today consumes a validated schema-v1/v2 snapshot.
- Today does not speak MCP or read the planning vault directly.
- The planning vault remains task authority.
- Today performs no completion writes.
- O6 already provides:
  - Today glance Automatic/Hidden visibility;
  - Compact/Full label mode;
  - Compact/Balanced side width;
  - 1h/6h/24h/All routine deadline horizon.
- Compact side width reportedly caps each side at 56 points including padding while keeping the hardware center fixed.
- Full reminder controls remain inside Today's scroll area.
- O5 reportedly adds default-on Hover and Action haptic switches plus an experimental guarded private-actuator single-pulse test for requested 0.20/0.45/0.70 and Off.
- Physical haptic intensity remains unverified.
- The installed application remains an O6 build; O5/O7 source state and installed-app state therefore differ.
- `TodayStore.startFocus(row:)` reportedly creates a hard-coded 25-minute session and persists row/work/`endsAt`.
- Today currently visibly describes that action as a 25-minute focus action.
- Snapshot rows render in supplied order.
- Today includes DisclosureGroup details, associated deadlines, top focus state, in-scroll reminders, upcoming deadline presentation, refresh/status behavior, and quiet-hours controls.
- Exact scrolling reportedly uses an `NSClipView` scroll keeper keyed by `today.scrollOffset`.
- Existing quiet-hours persistence reportedly uses `today.quiet.enabled`, `start`, `end`, and `allowRequired`.
- Reminder scheduling already accounts for snooze, acknowledgments, restart catch-up, and stale/changed/removed deadlines.

Verify these facts before relying on their exact implementation shape.

Do not replace exact `NSClipView` restoration with an anchor-only SwiftUI approximation.

---

# O7 implementation

## 1. Focus duration

Add one bounded, local presentation/action preference for the duration of **new** Today focus sessions.

Default: **25 minutes**.

Prefer a small fixed set of genuinely useful durations over a free-form numeric field unless the existing settings architecture makes a bounded stepper clearly simpler and safer.

A reasonable default fixed set is:

- 15 min
- 25 min
- 45 min
- 60 min

Use the repository's existing preference-storage conventions.

Requirements:

- normalize missing, malformed, unsupported, or out-of-range stored values to a supported value;
- preserve 25 minutes as the migration/default behavior;
- update the visible focus action so it truthfully reflects the selected duration;
- apply the preference only when creating a **new** focus session;
- once a focus session exists, changing the preference must not change its persisted `endsAt`, work identity, associated row, elapsed/remaining calculation, or restart behavior;
- do not rewrite existing persisted sessions merely to migrate the preference.

If live source reveals another duration concept already exists, reuse it only if its semantics are actually compatible. Do not create two competing Today focus-duration authorities.

### Observable acceptance

Prove at minimum:

- clean/default preference → action says 25 minutes and a new session ends approximately 25 minutes after its supplied/test clock start;
- selecting another supported duration changes both the visible new-session action and subsequently created session timing;
- changing the preference during an active session does not alter that session's stored end;
- the next session uses the new value;
- invalid persisted preference values are normalized deterministically without damaging unrelated defaults.

Use controllable clocks/fixtures where the current tests support them. Do not turn timing assertions into sleep-based tests.

---

## 2. Required-only presentation

Add a Today presentation preference with:

- **All** — default/current behavior;
- **Required only**.

This is a **presentation filter**, not a scheduling filter, snapshot transform, completion operation, or change to published course data.

Determine requiredness only from the snapshot's explicit published `deadline.required` metadata. Never infer it from course names, titles, text, ordering, color, task type, or other heuristics.

### Row rule

Use this semantic unless live schema evidence proves it impossible:

- row has **no deadlines** → keep visible;
- row has at least one required deadline → keep visible;
- row has deadlines and **all are optional** → normally hide in Required-only mode;
- row has mixed required and optional deadlines → keep the row.

Within a retained mixed row in Required-only mode, suppress optional deadline presentation where doing so is consistent with the existing Today hierarchy, while preserving the row's non-deadline work content and required deadlines.

Do not mutate the underlying snapshot or ledger.

### Active-target exception

A presentation filter must never make an active state impossible to reach or understand.

If an otherwise hidden optional-only row is currently associated with:

- the active focus session; or
- a currently actionable reminder that the UI is responsible for exposing,

retain enough presentation of that row and target to make the active state visible and operable.

Do not fake requiredness to achieve this. Treat it as an explicit "active target retained despite current filter" condition.

If useful, expose restrained explanatory copy or existing secondary treatment indicating why the row remains visible. Do not imply completion or that optional work has become required.

### Sections and summaries

Apply the same semantic consistently anywhere O7's presentation choice controls Today material, including any relevant next/upcoming/start presentation found in live source.

Do **not** make independent filtering rules for multiple sections unless their data models genuinely require it.

A filtered empty state must not look like "all work complete."

It should communicate that the current presentation filter has no matching deadline-bearing work while non-deadline/current-state information may still exist.

### Scheduling boundary

Changing All/Required-only must not:

- schedule or cancel notifications/reminders;
- acknowledge reminders;
- alter snooze state;
- modify quiet hours;
- rewrite deadlines;
- mutate payload data;
- modify active focus persistence.

Reminder scheduling must continue to operate from authoritative snapshot/ledger state rather than from whatever happens to be visible.

---

## 3. Text density

Add a small Today density preference:

- **Current** — default and equivalent to the current rendering;
- **Compact**.

This is intentionally not a general layout editor.

Compact may reduce secondary copy, vertical spacing, padding, or redundant metadata, but it must preserve:

- primary work titles;
- enough deadline information to understand due state;
- required/optional state where it is materially relevant;
- primary row actions;
- access to disclosure/details;
- active focus/reminder state;
- keyboard/focus usability already supported by the app;
- accessibility labels/values/hints needed to recover information that is visually condensed.

Do not:

- reduce type below existing accessibility-safe conventions merely to fit more content;
- hide required status solely behind color;
- eliminate disclosure access;
- create a general widget/layout framework;
- move hardware-notch geometry;
- modify closed-notch width settings from O6.

Where Compact removes visible secondary text, verify that equivalent critical meaning remains discoverable through the normal interaction/accessibility path.

---

## 4. Reminder prominence

Add one small, clearly named preference affecting only the **existing in-scroll Today reminder presentation**.

Default must reproduce current behavior.

Prefer two modes rather than a multi-level styling framework. For example, if consistent with live terminology:

- **Standard** — current behavior;
- **Quiet** — reduced visual prominence.

Choose final user-facing names to match the repository's established vocabulary.

Quiet presentation may reduce visual weight, secondary explanation, padding, or automatic expansion, but it must **not** suppress the reminder itself.

Preserve:

- reminder visibility;
- snooze actions;
- acknowledgment actions;
- association with the correct work/deadline;
- required/critical due-state discoverability;
- quiet-hours behavior;
- restart/catch-up semantics;
- stale/changed/removed deadline handling.

Use actual reminder-kind and explicit required metadata where these distinctions already exist.

Do not:

- restore the removed/closed-notch lower banner behavior;
- create overlays over another product tab;
- convert visual quieting into notification suppression;
- auto-acknowledge reminders;
- make required/critical due state available only inside an undiscoverable collapsed region.

If Quiet uses disclosure/collapse, ensure an actionable required reminder still visibly signals its existence and state before expansion.

---

# Settings placement

First inspect the live customization/settings architecture.

Place O7 controls on the smallest natural existing Today-specific surface.

Preferred decision order:

1. reuse an existing Today settings/customization section if one exists;
2. extend an existing Today popover if it is already the established home for comparable controls and remains usable;
3. create a small Today subsection within the existing settings architecture if necessary.

Do not create:

- a fifth product tab;
- a second O6 deadline-horizon control;
- a parallel preferences framework;
- an all-purpose Today editor.

Keep O6 controls under their existing ownership and semantics.

Avoid gratuitous storage-key renames. If an O7 key must change during implementation before release, migrate it explicitly and test the migration rather than silently abandoning the old value.

---

# Persistence and separation requirements

Treat presentation preferences, focus-session state, reminder ledger state, snapshot data, and quiet-hours state as distinct concerns.

Changing any O7 presentation preference must not accidentally:

- overwrite an active focus session;
- reset `endsAt`;
- acknowledge/snooze/reschedule a reminder;
- rewrite snapshot data;
- rewrite quiet-hours preferences;
- reset O5 haptic preferences;
- reset O6 glance/horizon preferences;
- move notch geometry;
- reset unrelated application preferences.

Verify fresh-default behavior independently from migration behavior.

Where the app uses `UserDefaults` or an equivalent shared store, write isolated tests using a temporary suite/domain rather than deleting or mutating the developer's live preferences.

Do not use private live Today payloads, planning-vault state, or personal course data for tests.

---

# Scroll and stale-data behavior

O7 must preserve exact Today scrolling behavior.

Exercise preference changes while the Today scroll view is away from its top, including at least:

- a density change;
- an All ↔ Required-only change;
- reminder-prominence change where it causes measurable layout change.

The important acceptance condition is not that every filtered layout can retain the same raw pixel offset regardless of removed content. It is:

- no arbitrary jump to the top caused by preference plumbing;
- the existing exact scroll-restoration mechanism remains intact;
- persistence/restoration across the existing supported lifecycle continues to work;
- filtering or compaction does not replace the `NSClipView` mechanism with a weaker SwiftUI-only substitute.

If the live scroll keeper has defined clamping semantics after content shrinks, preserve and test those semantics.

Also verify that presentation changes do not crash or corrupt state when the snapshot is stale, changed, or refreshed during normal Today operation.

Do not claim stale-snapshot correctness merely from static rendering tests if the relevant behavior belongs to store/scheduling integration.

---

# Verification

Use the recovered checkout as `workdir` for every source/test/build command.

Run the smallest relevant checks while developing, then the appropriate existing regression set.

At minimum, obtain evidence for:

### Preference/storage tests

- O7 defaults;
- persistence through a fresh isolated defaults instance;
- malformed/invalid stored values;
- migration/normalization behavior;
- no reset of unrelated Today/O5/O6 preferences.

### Focus tests

- default 25-minute new session;
- alternate configured duration;
- preference change during active focus preserves the active session;
- next session uses updated duration;
- restart/reload behavior remains consistent with stored `endsAt`.

### Filtering tests

Include fixtures representing:

- schema v1 if still supported by the live owner;
- a row with no deadlines;
- optional-only row;
- required-only row;
- mixed required/optional row;
- multiple rows preserving supplied ordering;
- optional-only row retained because it owns active focus;
- optional reminder/target retained when needed for actionable active state;
- filtered-empty presentation that does not imply completion.

### Density tests

Verify behavior rather than snapshotting arbitrary pixel trivia:

- essential primary text/actions remain;
- required/due semantics remain available;
- disclosure access remains;
- accessibility information remains sufficient where visual secondary text is removed.

Use existing accessibility inspection/test helpers if present. Do not introduce a broad new testing framework merely for O7.

### Reminder-prominence tests

Prove:

- Standard matches current/default behavior;
- Quiet changes presentation but not existence or actionability;
- required/critical state remains visible/discoverable;
- snooze and acknowledgment behavior is unchanged;
- preference changes do not alter ledger/scheduling state.

### Regression/integration

Exercise relevant existing tests for:

- Today snapshot parsing/payload handling;
- reminder scheduling;
- quiet hours;
- snooze;
- acknowledgment;
- stale/changed/removed deadlines;
- restart/catch-up;
- existing focus persistence;
- O6 Today customization where overlap makes regression plausible;
- scroll restoration.

Do not claim native restart coverage from pure model/unit tests.

Do not claim human visual or accessibility acceptance solely from XCTest.

---

# Native evidence and build

Produce an actual **unsigned Release build** from the recovered checkout using the repository's supported build path.

Do not install it.

Keep these states explicitly separate in reporting:

- source implemented;
- automated tests passing/failing;
- Release build passing/failing;
- offscreen/screenshot evidence produced;
- installed application state;
- native human acceptance;
- physical haptic acceptance.

The installed application is not automatically updated by a successful source build.

Where repository tooling permits without installation, capture useful screenshots, previews, or offscreen renders demonstrating O7 states. Prefer a small evidence matrix showing materially different states rather than dozens of nearly identical images.

Useful state combinations include:

- All + Current + Standard;
- Required-only with mixed required/optional fixture;
- Required-only retaining an active optional focus/reminder target;
- Compact density;
- Quiet reminder prominence;
- filtered-empty state.

Do not use screenshots as a substitute for state/behavior tests.

---

# Documentation and evidence

Update the existing canonical documentation rather than creating parallel O7 truth files unless live project instructions explicitly require a new artifact.

Reconcile at minimum the relevant portions of:

- `docs/Today.md`;
- `docs/Customization.md`;
- `docs/Upstream-integration-2026-10-13.md`;
- any primary mirror that repository instructions identify as canonical.

Clearly distinguish:

1. **verified live-source facts**;
2. **implemented O7 behavior**;
3. **automated evidence actually run**;
4. **native build/render evidence actually obtained**;
5. **open native/human gates**;
6. **independent O5 hardware gate**.

Do not document unrun checks as passing.

Record exact useful commands and summarized outcomes.

If blocked, record:

- the blocker;
- what remains complete;
- exact dirty/staged state;
- relevant failing command and concise error;
- safe resume point.

---

# Completion gate

O7 is technically complete only when all of the following are true, or an external/user-only block is explicitly documented:

- all four requested O7 preferences exist on a natural existing settings surface;
- deadline horizon remains the O6 control rather than a duplicate;
- preference defaults and invalid-value behavior are deterministic;
- focus duration affects only newly created sessions;
- active focus timing survives preference changes;
- Required-only follows explicit `deadline.required` metadata and the defined row semantics;
- active focus/reminder targets remain reachable under filtering;
- filtering does not alter scheduling, acknowledgement, snooze, quiet hours, or payload state;
- Compact preserves essential content/actions/accessibility;
- reminder prominence changes presentation without suppressing reminders;
- unrelated O5/O6 and app preferences survive O7 changes;
- existing exact scroll restoration remains in place;
- relevant focused and regression tests have actually been run;
- an unsigned Release build from the recovered checkout has actually succeeded, or the concrete build blocker is recorded;
- canonical docs describe what is implemented and what remains unverified;
- no installation has occurred;
- O5 physical intensity is still reported separately rather than falsely accepted through O7.

A first passing unit test or first visible settings control is not completion.

---

# Scope exclusions

Do not use O7 to implement:

- notification-policy changes;
- new reminder scheduling semantics;
- focus completion writes;
- vault reads/writes;
- MCP integration;
- task editing;
- a fifth tab;
- a general dashboard/widget editor;
- a new rendering architecture;
- notch geometry redesign;
- O5 haptic backend changes;
- physical haptic claims;
- O8 presets;
- O9 Quick Notes;
- stock updater restoration;
- unrelated cleanup merely encountered along the way.

Small prerequisite fixes are allowed only when necessary to make O7 correct. Keep them narrowly scoped and explain why they were required.

---

# Successor/chain discipline

Use the project's prompt-roundtrip/daisy-chain workflow only as far as needed to finish this authorized unit cleanly.

Before transferring writes, inspect the live ownership/recent-chat inventory rather than relying solely on the supplied statement that no successor currently exists.

Do not spawn parallel agents that can edit overlapping O7 files.

Useful parallel/subagent work is appropriate only when repository instructions permit it and the work can be made read-only or assigned genuinely disjoint ownership.

Do not generate an endless sequence of "next improvement" chats.

**O7 implementation and verification are the objective of this chat.**

After O7 reaches its completion gate:

- do not implement O8 or O9 as part of this pass;
- preserve O8 as the previously identified possibility of small named Study/Quiet/Media/custom presets with a strict preference whitelist, preview, and revert;
- preserve O9 Quick Notes as optional rather than mandatory;
- keep O5 physical hardware acceptance pending independently.

If the established chain workflow requires a successor to continue already-authorized work, create at most the next concrete, bounded handoff after checking the live inventory and transferring exclusive writes correctly. Otherwise leave a decision-ready resume packet and stop.

Do not manufacture successor work merely to keep the chain alive.

Finish with a concise terminal report containing:

- files materially changed;
- behavioral decisions made;
- tests/commands actually run and outcomes;
- Release build result;
- screenshots/render evidence, if any;
- installed-app status;
- open human/native gates;
- O5 physical gate status;
- exact repository/ownership/resume state.

Material changes:

- **Made filtering deterministic.** Rows without deadlines remain visible, optional-only rows hide, mixed rows stay, and active focus/reminder targets explicitly override hiding without being relabeled as required.
- **Separated presentation from stateful systems.** The prompt now makes preferences, focus persistence, reminder ledger, scheduling, quiet hours, and payload data distinct and requires regression evidence against accidental cross-writes.
- **Refined scroll acceptance.** It no longer demands impossible identical pixel offsets after content removal; it instead preserves the existing `NSClipView` mechanism, clamping semantics, and no-arbitrary-jump behavior.
- **Bounded the design choices.** Focus defaults to a small 15/25/45/60 set unless live architecture favors a bounded stepper; density and reminder prominence are two-state controls rather than new frameworks.
- **Separated evidence levels.** XCTest, unsigned Release build, screenshots, installed-app status, human/native acceptance, and O5 physical haptic acceptance can no longer be conflated.
- **Closed the chain loophole.** O7 must finish before further product work, O8/O9 are excluded from implementation, and successor creation is limited to a concrete authorized handoff rather than indefinite daisy-chaining.