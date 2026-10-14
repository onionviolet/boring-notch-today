# Customization roadmap

Updated October 13, 2026. The user requested considering haptic intensity and a
broader customization scope for upcoming updates. The options below remain roadmap
proposals except for the bounded O6, O5, O7 and O8 source implementations recorded below.
O6 is installed with native navigation checks; human visual/restart acceptance is open.
O5, O7 and O8 are built but not installed; O5 physical intensity is unverified.
Current app source
is the recovered integration worktree identified in CLAUDE.md.

## Current capabilities and gap

The integrated app already exposes custom notch heights, hover delay, gesture
sensitivity/direction, animation speed, compact Home, accent colors and tab
visibility. Ordinary haptics use SwiftUI alignment cues with master, Hover and Action
preferences in source. An explicit private actuator test is built but not installed;
its physical intensity remains unverified. The bounded O6 source now has local glance visibility, label, width-cap
and deadline-horizon controls with narrower wings. The local app now runs this compact-glance candidate. O8 now provides bounded named Today presets with preview, explicit Apply, one local
Custom slot and persistent conflict-aware Restore. There is no general widget editor.
See the implementation gates below.

An intensity slider was not removed from the recovered staged source: no such
control exists there or in the primary source reviewed. This does not establish
what unknown unstaged files may have contained before the worktree disappeared.
Atoll's current SettingsView/Constants likewise expose only enableHaptics.

Apple's [impact(weight:intensity:) documentation](https://developer.apple.com/documentation/swiftui/sensoryfeedback/impact(weight:intensity:))
says that impact feedback plays only on iOS/watchOS despite the symbol being
available to compile on macOS. The local Xcode SDK confirms that
NSHapticFeedbackPerformer takes a pattern and timing, with no amplitude parameter.
Therefore compiling a SwiftUI intensity slider would not establish adjustable
Force Touch trackpad strength. True intensity needs a separate hardware-capable
route and a physical comparison before product acceptance.

## Ranked next options

| Code | Proposal | What changes | Integration / acceptance |
| --- | --- | --- | --- |
| O6 | Closed-notch wing editor | Choose deadline, focus, music or battery; set priority and maximum width; show upcoming deadlines only within a chosen window; provide a hidden mode. Use terse labels and independently sized, tightly capped wings; preserve the physical-notch center anchor and never add a lower strip. | Best first product change. Reuse TodayNotchGlance and existing media/battery views. Check every supported combination and switching transition for anchoring, height, clicks, long labels and fullscreen hiding. |
| O5 | Haptic customization | Pattern selection and a Test button can use existing trackpad APIs. Keep true intensity as a hardware trial; do not label pattern selection as amplitude control. Separate hover, open/close and gesture cues so hover can be quiet. | Inventory actual trigger sites including calendar and sliders. A successful trial must demonstrate clearly different strength on the user's trackpad, confirm off/zero behavior and graceful unavailable-device fallback. If amplitude needs a private actuator route, inspect its mechanism before choosing it. |
| O7 | Today presentation controls | Choose focus duration, glance deadline horizon, required/optional filtering, compact text density and reminder prominence. Full reminders remain inside the scroll area. | Use explicit local preferences and validated timestamps. Do not change vault task state or rewrite published deadlines. Check restart persistence, quiet hours, stale snapshots and scroll restoration. |
| O8 | Named presets | Study, Quiet and Media presets plus a custom preset, each covering a small named set of display/interaction preferences. Show what will change and offer conflict-aware Restore previous settings. | Explicit preference whitelist; exclude permissions, update feeds, vault paths and payload data. Verify apply/revert and round-trip persistence without replacing unrelated settings. Existing accent-color presets are narrower than these. |
| O9 | Small Quick Notes pane | Optional local scratchpad for a thought, copied text or a link, with explicit copy/clear actions and no automatic vault write. | [Not So Boring Notch](https://github.com/Cris2907/not-so-boring-notch) has a Quick Notes implementation family. Review its storage/retention and keyboard behavior before adapting. Do not import its full extension system or add continuous clipboard collection as part of notes. |

Recommended order: O6, then O5's hardware investigation and supported cue controls,
then O7 and O8. Those source units now have build checkpoints below. O9 is an optional utility,
not a prerequisite for customization.

## Evidence and limits

Source inspection covered the current integration's NotchSettingsView,
AppearanceSettingsView, ContentView and Constants, plus Atoll's live
DynamicIsland SettingsView and Constants. The October 13 fork scout records the
other feature families and revisions in Upstream-integration-2026-10-13.md.
The Apple impact documentation was retrieved as Markdown after the rendered page
required JavaScript. No new app code, installation, haptic hardware experiment,
commit or push was performed for this roadmap.

## Roundtrip reconciliation, October 13

Completed an ordinary signed-in ChatGPT review at the visible High effort setting.
The reviewing UI did not expose a named model. Original packet, full response,
new width feedback and its targeted amendment are saved separately:
[original packet](Customization-roundtrip-2026-10-13-outbound.md),
[review](Customization-roundtrip-2026-10-13-response.md),
[width amendment](Customization-roundtrip-2026-10-13-width-response.md).

The user subsequently reported excessive lateral width. This changes O6's first
acceptance goal: make the compact glance materially narrower than two fixed
90-point wings. Preserving that width is no longer a recommended default.
The reviewer did not inspect local files; the bindings below were checked here.

| Finding | Current source evidence | Planning consequence |
| --- | --- | --- |
| F12 | TodayView.swift:368 onward uses a full work title and two fixed 90-point frames. Countdown omits only the word left. | Use a conservative short identity and a compact countdown; bound the actual rendered background/hit footprint, not only text. |
| F13 | NotchWindowManager.swift:133–179 uses a fixed backing window centered on the screen. ContentView's layout/shape/hit chin are separately sized; computedChinWidth adds a fixed 190 for Today. | Unequal HStack children alone move the central notch region. Explicitly anchor the physical center and derive background/click/hover bounds from the same rendered widths. A transparent 640-point backing window is not the visible footprint. |
| F14 | ContentView.swift:228 selects Today independently from the closedNotchContent routing used elsewhere. Full reminder controls now live within Today. | Inspect all render/geometry/gesture routing together before adding choices. Preserve transient HUD/battery/notification precedence; avoid a speculative plugin framework. |
| F15 | Haptic trigger search found ContentView hover/open/close/media gesture cues, LiveActivityStack selection and Calendar cues; they are guarded by enableHaptics. No direct actuator or adjustable amplitude route exists. | Per-cue settings must cover the actual trigger inventory. Slider haptics were not found in this source slice; do not invent them as existing. |

### Proposed O6 first slice

Keep v1 focused on Today glance customization and narrower defaults, with existing
media/battery branches preserved. Avoid arbitrary mixing of music/battery widgets
until their geometry and actions have a concrete composition contract.

Place a Closed Notch Glance section in Settings → Notch. Propose four controls:
Today glance visibility (Automatic / Hidden), label (Compact / Full), side-width
limit (Compact / Balanced), and upcoming-deadline horizon (1h / 6h / 24h / All).
Suggested defaults: Automatic, Compact, Compact, All. Preserve existing scheduling
visibility by default while fixing excessive width. Hidden suppresses this Today
glance, not unrelated HUD/notification/battery activity or the data inside Today.
The horizon affects routine deadline display, not reminder delivery or vault data.

Compact geometry proposal: fit the left identity to its text with a per-side cap
of 56 points; use a stable countdown/status bucket of at most 56 points on the
right, with actual padding accounted for. Balanced can cap at 80 points. These
are proposed starting bounds, not measured universal guarantees. Verify actual
font variants before fixing them. Keep normal height and existing corner padding.
If no explicit short label exists in the model, use a conservative bounded title;
do not fabricate a course identity by parsing arbitrary prose. A prefix before a
known visual separator may be trialed only against actual payload examples and
must retain full title in accessibility/help.

Anchor the hardware-notch region independently of left/right extension widths.
For a centered row with symmetric outer padding, the mathematical compensation
is (rightWidth - leftWidth)/2; confirm the actual view hierarchy before applying
that formula. Check the rendered center, outer edges and hit bounds rather than
assuming a frame modifier solves all three. Hidden content should not leave a
phantom extension. Use monospaced digits and a few stable time-format buckets so
ordinary countdown updates do not resize the pill on every tick.

Manual width caps and hidden mode are feasible v1 controls. Automatic detection
of arbitrary nearby menu icons is a separate unsolved mechanism, not a promise.
No extra Accessibility access is required merely for the proposed width controls.

Acceptance: short labels visibly narrower than the current allocation; long text
stays capped; center is stable as either side changes; visible and interactive
bounds agree; no lower strip; card navigation and exact Today scroll restore work;
settings survive restart and invalid stored values fall back; HUD/media/reminder
transitions and fullscreen/zero-height suppression retain their defined behavior.
Preserve the other four roadmap areas for subsequent bounded slices.

### Genuine haptic candidate and trial

Inspected [Tactile ActuatorHapticEngine](https://github.com/Mason363/Tactile/blob/a9b02a4e4fae6408058bd876e24accb52a864520/Tactile/Engines/ActuatorHapticEngine.swift),
revision a9b02a4e4fae6408058bd876e24accb52a864520, MIT license. It runtime-loads
MultitouchSupport symbols and opens per-trackpad actuators. Its accent path passes
a bounded strength scale to MTActuatorActuate using one waveform ID. This is a
source-backed candidate for amplitude testing, not evidence of strength changes
on this user's device. Stock tick IDs represent discrete profiles; those alone
are not proof of a continuous intensity slider.

A narrow future probe should isolate the actuator lifetime/device lookup and use
single explicit Test pulses, not import Tactile's global hover monitoring, audio,
phone integration or continuous-vibration worker. Missing symbols/device or an
API failure must leave the app functional. Public patterns remain an honest
fallback; disable a true-intensity control if its route is unavailable. Retain
MIT attribution if code is copied. Private ABI drift and disconnected-device
lifetime require review before adoption.

Physical gate: with the same waveform and the same finger contact, compare three
bounded scale values using individually triggered pulses in a varied order. Ask
the user to judge whether strengths differ consistently. Verify zero/off produces
no pulse, settings persist, and unavailable/disconnected hardware fails cleanly.
Do not claim physical acceptance from a successful return code or compilation.
No actuator was invoked in this planning pass.

### Reconciliation and next action

The initial review was useful but expanded into a 20-section planning checklist.
The executable handoff is deliberately bounded to O6's compact Today-glance slice,
with haptic research retained as a distinct next scope. The second review was
justified by new user screenshot feedback, not repeated polishing.

[Next implementation packet](Customization-next-pass.md) is prepared for a later
authorized implementation request. This roundtrip changed documentation only;
no app code, installation, commit, push or permissions changed.

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


## O5 haptic implementation and acceptance, October 13

O5's bounded source implementation is complete in the recovered checkout. It is
**mechanism implemented; physical intensity unverified**. No experimental pulse
was sent to the real hardware during this pass. The candidate is built but not
installed. The installed compact O6 app and the staged merge remain intact.

### Source facts and mechanism boundary

The minimal backend derives lookup/lifetime ideas from
[Tactile's pinned ActuatorHapticEngine](https://github.com/Mason363/Tactile/blob/a9b02a4e4fae6408058bd876e24accb52a864520/Tactile/Engines/ActuatorHapticEngine.swift),
revision `a9b02a4e4fae6408058bd876e24accb52a864520`. Mason Chen's full MIT notice is
included in THIRD_PARTY_LICENSES. Its accent path uses waveform 6 with a numeric
scale, but its public pattern names and comments do not establish physical
intensity. We did not import monitoring, touch tracking, music, continuous buzz,
phone integration or permissions. Our raw requested values deliberately stay
below 1.0, rather than adopting Tactile's 0.35-to-1.30 mapping.

On this arm64 MacBook Pro, macOS 27.2 build `26B5101f`, dlopen/dlsym resolved the
seven required symbols. Disassembly independently checked register usage and
32-bit floating-point processing. **MTActuatorOpen reads a second 32-bit argument
on this build**, omitted by the pinned Tactile signature. The wrapper explicitly
passes zero. It fails closed outside the inspected build/architecture; it needs
another ABI/lifecycle review after an OS update. This guard is intentionally
conservative and does not claim support for other Macs or OS releases.

| Symbol | Wrapper signature |
| --- | --- |
| MTDeviceCreateList | `() -> Unmanaged<CFArray>?` |
| MTDeviceGetDeviceID | `(pointer, UInt64*) -> Int32` |
| MTDeviceIsBuiltIn | `(pointer) -> Bool` |
| MTActuatorCreateFromDeviceID | `(UInt64) -> pointer?` |
| MTActuatorOpen | `(pointer, UInt32) -> Int32`; second argument explicitly 0 |
| MTActuatorClose | `(pointer) -> Int32` |
| MTActuatorActuate | `(pointer, Int32, UInt32, Float, Float) -> Int32` |

The retained device list is released through takeRetainedValue/ARC. Current
nonzero IDs are read only while their device objects remain alive. Built-in
trackpads are preferred; external candidates use stable ID order. Only one
successfully opened actuator is selected. There is no legacy hardcoded-ID fallback.
A fresh enumeration/create/open occurs for each check or Test, so retained state
cannot outlive a disconnection/re-enumeration. The lease owns the created CF
object and loaded library until it closes the actuator, releases the object and
closes the library, including actuation failure. No retained device cache,
background retry or worker exists. Operations are synchronous on MainActor.

Three actual no-pulse scans found one device, created a CF object (type ID 76),
opened with return 0, closed with return 0 and released it without a crash. This
is observed lifecycle evidence, not a test of actuation or long-term firmware
behavior. The final unsigned XCTest app host also acquired/released the actual
production backend successfully with no pulse. The app declares sandbox
entitlements, but these unsigned checks do not establish private-actuator access
from a signed sandboxed distribution. No entitlement or permission was changed. Nonzero open/actuate/close returns count as failures. Missing library,
symbols, nil/empty enumeration, missing actuator or disconnect leave the experiment
unavailable with a visible reason. Test failure disables its control until an
explicit no-pulse Check availability; no public fallback pulse is substituted.
A device disappearing between enumeration and actuation can still yield an error,
which closes/releases its lease without retrying. ABI changes remain a private-API
risk even with version gating.

### Cue inventory and controls

Settings → Notch → Haptic Feedback now has master Enable, default-on Hover cues
and Action cues. Ordinary cues stay on the existing SwiftUI alignment route.
Master Off gates every cue trigger and all experimental Test requests. (October 14:
a render-time condition closure added to the four `.sensoryFeedback` modifiers
coincided with the user feeling no notch feedback; it was redundant with trigger
gating and was removed to restore the original modifiers.) The groups cover the actual existing sites:

| Site | Existing trigger | Group / duplicate review |
| --- | --- | --- |
| ContentView | Closed-notch hover entry | Hover; doOpen itself has no second cue |
| ContentView | Down/up notch gesture threshold; next/previous media threshold | Actions; horizontal media already has a once-per-gesture latch |
| LiveActivityStack | Valid activity move after horizontal drag | Actions; no extra cue was added to parent opening |
| Day dial calendar | Click, wheel-selected date, snap position change | Actions; existing byClick suppresses the programmatic follow-up position cue |
| Week calendar | Day step, week page, date click | Actions; each uses its own existing trigger |

The calendar has two alternative presentation views/modifiers, rather than a
new parent cue. Stock pointer scrolling and SwiftUI activity dragging use
separate recognizers; no new duplicate route or throttle was introduced. There
is no separate open/close cue, slider feedback or new taxonomy. Physical gesture
journeys and cue perception have not been checked on the new candidate.

The experiment appears only after an actuator successfully opens/closes. It offers
Off, requested 0.20 (default), 0.45 and 0.70, plus **Test single pulse**. Numeric
values mean requested private actuator strength, not measured hardware amplitude.
Unknown stored selections/types fall back to 0.20; the boundary clamps finite
values to 0...0.70 and nonfinite values to the conservative default. Zero and
master Off never acquire or actuate. Startup, Settings availability checks,
preference edits/restoration and ordinary cues never invoke the experimental
pulse. One deliberate Test issues at most one waveform-6 call, flags 0, duration
scale 0, with fresh acquisition and unconditional cleanup.

### Verification

All commands used the recovered checkout as workdir. No source/test/app action
used the older primary checkout; its existing DerivedData cache was reused by
XCTest exactly as in O6. Logs and source snapshots are in recovered `work/`.

| Gate | Evidence and limits |
| --- | --- |
| Affected XCTest | 30/30 pass: HapticExperimentTests (initial 9), TodayGlanceTests (8), PreferenceCompatibilityTests, CalendarBoundaryTests and NotchUIEventTests. Zero failures/skips. `work/o5-tests.log`, `work/o5-regression-result-summary.json`. |
| Final haptic XCTest | 11/11 pass after adding actual nil/empty enumeration lookup fixtures, correcting a test-key naming warning, and checking the real backend acquire/release inside the unsigned XCTest app host. Zero failures/skips/runtime warnings. Persistence, invalid stored values, clamping, off/master silence, actual missing-library/symbol/scan paths, failed actuation cleanup, disconnect/fresh reacquisition, single Test request and no pulse on availability/preference handling. `work/o5-haptic-final-tests.log`, `work/o5-haptic-result-summary.json`. All pulse tests use fake leases. The real backend test only acquires/releases without a pulse. |
| Existing scheduling | Standalone TodayScheduleTests pass for catch-up/restart, snooze, quiet hours, changed/removed/stale deadlines, countdown and schema. `work/o5-schedule.log`. |
| Private ABI/lifecycle | Symbol/disassembly logs `work/o5-abi.log`, `work/o5-abi-detail.log`, `work/o5-abi-tail.log`; actual three-round no-pulse probe `work/o5-lifecycle.log`. Early diagnostic helper attempts hit a non-exported internal symbol and were corrected to inspect the observed branch address. No hardware actuation was performed. |
| Unsigned Release | Build succeeded, `work/o5-release.log`. Candidate `work/DerivedData-o6/Build/Products/Release/Boring Notch.app`. SHA-256 `5ce3e5e67ecb6571389a0b433cd96fbd64d04584613ffb1001aa50c4da6471eb`. |
| Git preservation | Staged binary diff SHA-256 still `11a5a08fd0d1e40efdf487b9643d0fd7b64d69bbef89526d08247452538cb456`, identical to initial snapshot. New source/test changes remain unstaged; no stage/commit/push. |
| Native/human gates | No new installation or manual candidate launch. Physical intensity, installed Settings/persistence, device sleep/disconnect, real gestures and prior O6 native restart/fullscreen/scroll acceptance remain open. |

Reproduce the checks:

```sh
uv run --with capstone python work/o5-abi-probe.py
uv run --with capstone python work/o5-abi-tail.py
swift work/o5-lifecycle-probe.swift
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug -destination 'platform=macOS' -derivedDataPath /Users/weiwei/code/boring-notch-today/work/DerivedData-upstream-oct13 -jobs 2 CODE_SIGNING_ALLOWED=NO -only-testing:boringNotchTests/HapticExperimentTests -only-testing:boringNotchTests/TodayGlanceTests -only-testing:boringNotchTests/PreferenceCompatibilityTests -only-testing:boringNotchTests/CalendarBoundaryTests -only-testing:boringNotchTests/NotchUIEventTests test
# Final test-only addition/corrected fixture names:
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug -destination 'platform=macOS' -derivedDataPath /Users/weiwei/code/boring-notch-today/work/DerivedData-upstream-oct13 -jobs 2 CODE_SIGNING_ALLOWED=NO -only-testing:boringNotchTests/HapticExperimentTests test
swiftc boringNotch/components/Today/TodayPayload.swift boringNotch/components/Today/TodaySchedule.swift tests/TodayScheduleTests.swift -o work/o5-schedule-tests
work/o5-schedule-tests
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release -derivedDataPath work/DerivedData-o6 -jobs 2 CODE_SIGNING_ALLOWED=NO build
```

The first build/TodayGlance-only check also passed (`work/o5-first-tests.log`).
The source/test changes did not touch payload publication/validation or its MCP
bridge; the earlier Python/MCP suite is not claimed as rerun for O5.

### Pending human trial and resume

The user can later authorize installation of the saved candidate or a later
combined build. No installation was inferred from O6's prior authorization.
In Settings → Notch, compare individual waveform-6 Test pulses with the same
finger position/contact, waiting for each to finish. Use requested values in
varied orders, for example 0.45, 0.20, 0.70, then 0.70, 0.45, 0.20. Each selection
requires its own deliberate Test click; there is no automatic sequence. Repeat
and record whether the user can reliably order the felt strengths. Check Off and
master Off are silent. A helper can conceal selected values if a less biased
comparison is desired. If differences cannot be reliably distinguished, record
that result; do not relabel successful calls as verified intensity.

O7 Today preferences can proceed independently through the authorized ordinary
ChatGPT review and fresh local successor. O8 remains after O7 settles; O9 remains
optional. Do not rework O5 or promote its physical gate without new evidence.


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


## O7 Today preferences, October 13

O7 source is implemented; an unsigned Release is built, with installation and
human/native acceptance still open. This unit's owner is
`01a133e3-265d-79e0-8c08-f8c61eec5127`. O5 physical intensity remains independently
unverified; the installed app still has the O6 executable hash.

Settings → Notch → Today Presentation now offers new-session focus duration
15/25/45/60 (default 25), All/Required-only, Current/Compact and Standard/Subtle
in-scroll reminders. O6's existing horizon stays under Closed Notch Glance.
O7 uses AppStorage/UserDefaults strings: `today.focus.duration`,
`today.presentation`, `today.density`, `today.reminder.prominence`. Invalid or absent
values have the effective defaults 25/all/current/standard without rewriting
active sessions or other state. AppStorage follows Today's existing dotted-key
quiet-hours convention; the Defaults library warns on dotted KVO names, so O7
does not declare those names as Defaults.Keys. No key was renamed.

Required-only derives solely from explicit deadline.required: no-deadline rows
and mixed rows stay in source order with their original ranks; optional-only rows
normally hide. Mixed rows expose every required deadline rather than only the
first deadline. Active focus/reminder and explicitly navigated targets stay
reachable with accurate optional labeling. Explicit O6 selectedRowID navigation
retains and expands its target before the selection is cleared; that reveal lasts
until a presentation-mode or snapshot change. Start/Next remain unlinked source
strings. A filter summary and filtered-empty explanation distinguish hidden work
from completion. Scheduling and the ledger still use the full snapshot.

Compact changes padding/spacing only, preserving all copy, disclosure and actions.
Subtle changes reminder heading weight/padding only; Today/Site/Snooze/Dismiss,
checkpoint copy and required/due state remain. The new duration changes new focus
sessions; persisted active endsAt/work/row identity and restart calculation remain.
Exact NSClipView pixel offset storage remains, with explicit range clamping on
restore and existing-view updates as content shrinks. No anchor-only replacement.

| Gate | Evidence / state |
| --- | --- |
| Source | Four controls, metadata projection, new-focus timing and explicit navigation retention implemented. Source patch in work/o7-final-source.patch; new TodayPresentationTests.swift stays untracked. |
| Affected XCTest | 27/27 pass, zero failures/skips/runtime warnings in work/o7-tests-final.log and work/o7-result-summary.json. Includes six O7 tests plus O6 glance, preference compatibility, calendar boundary and notch-event tests. |
| Focus/persistence | Isolated suites cover absent/invalid values, every supported duration, action labels, unchanged active focus bytes/endsAt after preference change, restored session countdown and next-session duration. No live preferences reset. |
| Filtering/scheduling | Synthetic validated v1/v2 no-deadline/optional/required/mixed fixtures, original order, active-target exceptions, suppressed mixed optional details, snooze/dismiss/restart and stale-state suppression. Standalone TodayPayloadTests and TodayScheduleTests pass in work/o7-payload.log and work/o7-schedule.log, including changed/removed schedules and quiet hours. |
| Offscreen Today | Real NSHostingView fixture exercises changes away from the top for density/filter/prominence, retains the same NSScrollView, and navigates/expands a filtered optional target. Native NSClipView exact fractional restore/reattach and shrink-clamp check passes. Renders: work/o7-standard-reminders.png, work/o7-subtle-reminders.png, work/o7-today-render.png. Inspected readable required/optional/due copy, controls and expanded target. These are synthetic offscreen evidence, not installed UI. |
| Accessibility | Exploratory hidden-window AX traversal returned an empty tree. Its failed text assertions were an unsupported offscreen probe, not a passing VoiceOver gate. Compilation first needed NSAccessibilityProtocol rather than the namespace. Logs retained as work/o7-accessibility-tests*.log and work/o7-native-tests.log. O7 does not remove secondary copy or reduce font sizes; native keyboard/VoiceOver usability remains open. |
| Unsigned Release | Final build succeeds at work/DerivedData-o6/Build/Products/Release/Boring Notch.app, executable SHA-256 fdb260c05dba6eb249477ad5d2639e9bb3c0542e13ba8ded35966689df702395. work/o7-release-final.log. |
| Installed/native/human | Not installed or manually launched. Installed executable freshly remains ce3ba0c1b1e868b15694c067261e22521ab1595926fd14d4ff5fe48fa44a2b01. Native Settings selection/restart, filtered navigation under real notch, keyboard/VoiceOver and physical transition/geometry acceptance remain open; no physical haptic pulse. |
| Repository | Initial staged binary patch remains byte-identical, SHA-256 11a5a08fd0d1e40efdf487b9643d0fd7b64d69bbef89526d08247452538cb456. All existing O5/O6 edits preserved. No staging, commit, push or installation. git diff --check passes. |

The first 27-test run passed 26 and exposed out-of-bounds restore after content
shrank; explicit clamping fixed that failed criterion before the passing slice.
Source build warnings elsewhere in the integrated app are not zero-warning runtime
claims. The final 27-test xcresult is
`/Users/weiwei/code/boring-notch-today/work/DerivedData-upstream-oct13/Logs/Test/Test-boringNotch-2026.10.13_02-15-20--0400.xcresult`.
Debug cache location is historical; commands ran with recovered checkout workdir.

Commands (all from recovered source):
```sh
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug -destination 'platform=macOS' -derivedDataPath /Users/weiwei/code/boring-notch-today/work/DerivedData-upstream-oct13 -jobs 2 CODE_SIGNING_ALLOWED=NO -only-testing:boringNotchTests/TodayPresentationTests -only-testing:boringNotchTests/TodayGlanceTests -only-testing:boringNotchTests/PreferenceCompatibilityTests -only-testing:boringNotchTests/CalendarBoundaryTests -only-testing:boringNotchTests/NotchUIEventTests test
swiftc boringNotch/components/Today/TodayPayload.swift boringNotch/components/Today/TodayBridgeStatus.swift tests/TodayPayloadTests.swift -o work/o7-payload-tests
work/o7-payload-tests
swiftc boringNotch/components/Today/TodayPayload.swift boringNotch/components/Today/TodaySchedule.swift tests/TodayScheduleTests.swift -o work/o7-schedule-tests
work/o7-schedule-tests
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release -derivedDataPath work/DerivedData-o6 -jobs 2 CODE_SIGNING_ALLOWED=NO build
```

O7's source/build checkpoint can advance to independent O8 presets while native
and human gates stay open. The next outbound review is bounded to Study/Quiet/Media
and one Custom slot, an explicit O7/O6 preference whitelist, truthful preview and
safe one-level restore. No quiet-hours/ledger/focus-session/actuator/account/security
changes. O9 remains optional; stop after O8 or a real block.


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
