# Customization work-prompt review, October 13, 2026

## Request to the reviewing chat

Improve the draft below into one complete replacement work prompt, followed by a short account of material scope, sequencing or tradeoff changes. Challenge consequential assumptions and make acceptance observable. Use supplied context without pretending to inspect local paths. You are reviewing a prompt, not executing it: do not dispatch agents, edit an app or claim implementation evidence. Keep all five requested customization areas visible, even if you recommend staged delivery. Do not silently substitute haptic patterns for true intensity. Keep the user's wish for a useful, unobtrusive, customizable notch central.

## Draft work prompt

Review and plan the next customization pass for a personal Boring Notch fork. The user asked about a haptic intensity slider and broader customization for upcoming updates, then requested this prompt roundtrip. Current authorization is discovery and a reviewable plan. Prepare an actionable first implementation slice and later sequence; do not change app code, install, commit, push, publish, create another agent chat, or change permissions in this planning pass. Ordinary source inspection and project documentation updates are authorized.

### Goal and product behavior

Give the user control over what vital information appears beside the MacBook's hardware notch, how it responds to input, and how Today presents information. Avoid turning the closed notch into a permanently expanded panel over browser controls. The user specifically approved using space along the notch sides after a deadline banner blocked their browser toolbar.

The planning vault is the only task authority. Today is a one-way read-only projection of a validated local JSON snapshot, not a task manager or completion system. The app does not scan the vault or speak MCP. A separate stdio MCP/CLI publisher validates schema-v1/v2 payloads. Opening a card/site, dismissing/snoozing a reminder or finishing a focus timer never completes a task in the vault. Source actions are validated HTTPS links; Itembank has a fixed bundle identifier. No arbitrary command/path/prompt inputs.

### Verified baseline and source boundaries

There are two checkouts. The primary repository is /Users/weiwei/code/boring-notch-today on codex/atoll-fixes, with older app architecture and preserved local edits. The current installed app's source is /Users/weiwei/.codex/worktrees/absorb-upstream-oct09/boring-notch-today on codex/absorb-upstream-2026-10-09. Read CLAUDE.md first and verify the current location rather than using the old primary implementation accidentally.

The integration directory had disappeared. Its surviving Git index contained the resolved October 9 upstream merge and D-hall; checkout-index restored that staged snapshot. Unknown missing unstaged/untracked files are not recovered or claimed. The primary checkout's newer Today deadline/focus payload, store, view, schedule, bridge and tests were carried forward into the recovered newer app architecture. That integration is staged and uncommitted. Do not reset it or stage unrelated work.

The installed unsigned local app is /Applications/Boring Notch.app, executable Contents/MacOS/Boring Notch. It has Home, Shelf, Today and D-hall tabs. Upstream settings, active displays, camera lifecycle, notification capture and media runtime are present in source. Stock Sparkle feed/automatic updates are disabled to protect the fork. This is a personal local customization scope, not a signed release project.

Latest installed UI: TodayNotchGlance uses two fixed 90-point wings at normal hardware-notch height: work title on the left, short countdown/reminder/focus status on the right. No lower closed-notch strip. Routine deadlines show when music is not playing and no inline song-change peek is active. Due reminders/focus can take priority; notifications, battery notices and system HUD retain their earlier branches. Hidden fullscreen and zero-height notches suppress the glance. Clicking opens Today and expands the matching card. Full reminder controls are inside Today's scroll area, not over other tabs. Native inspection verified the current deadline glance at 38-point height and click-to-card navigation.

Current customization already includes notch heights, hover delay, gesture sensitivity/direction, animation speed, compact Home, accent colors and tab visibility. Do not propose these as absent. Missing: a wing/content-priority editor, general named presets, per-cue haptic controls and adjustable focus duration. Today has a fixed 25-minute local focus session, persistent ledger/snoozes, quiet hours and schedule checks.

### Haptic facts and uncertainty

Current notch haptics use a SwiftUI alignment cue with an enableHaptics boolean. Source review found no intensity slider in either checked source or Atoll's current SettingsView/Constants; that does not establish what disappeared unstaged files once contained.

Apple's documented impact(weight:intensity:) compiles on macOS but explicitly says it only plays on iOS/watchOS: https://developer.apple.com/documentation/swiftui/sensoryfeedback/impact(weight:intensity:). The local AppKit SDK's NSHapticFeedbackPerformer exposes a fixed pattern and timing, no amplitude parameter. Pattern choice is not amplitude adjustment. Treat a true Force Touch intensity slider as a separate hardware trial. A private actuator route is not categorically excluded for this personal app, but inspect its actual mechanism, compatibility, licensing and failure behavior before recommending adoption. No unrequested global trackpad setting change or new security permissions. A real strength comparison needs the user's physical observation; don't claim it from compilation or screenshots.

### Requested areas, with recommended sequence rather than accepted decisions

O6, wing editor: choose deadline/focus/music/battery, content priority, maximum width, upcoming-deadline visibility window and hidden mode. Preserve center clearance, normal closed height and interactions. Start with a bounded set of combinations rather than a whole extension system. Resolve whether the present equal wings should remain equal when one source is hidden, and how critical transient activities override user selections.

O5, haptics: investigate true intensity and separately plan honest pattern selection, Test feedback, and independent hover/open-close/gesture cues. Inventory all relevant trigger sites, including calendar and sliders. Off must suppress all app cues. Unsupported hardware must degrade cleanly. Do not rename a pattern picker or repeated pulses as an intensity slider.

O7, Today presentation: local focus duration, deadline horizon, required/optional filtering, density and reminder prominence. Controls must never mutate authoritative deadlines or task state. Consider whether hidden optional work is still discoverable and how settings affect already running focus/reminders.

O8, named presets: Study, Quiet, Media and a custom configuration over an explicit small whitelist of preferences. Show affected preferences, preserve unrelated settings and offer reset/revert. Exclude permissions, updater feeds, payload contents and vault paths. Implement after preference meaning settles.

O9, Quick Notes: optional local scratchpad with explicit copy/clear, no vault auto-write or continuous clipboard capture. Not So Boring Notch has this feature family: https://github.com/Cris2907/not-so-boring-notch. Inspect storage/retention, keyboard behavior and license before adapting; don't import its full extension framework.

Recommendation: O6 first; O5 hardware investigation and supported cue controls next; O7 then O8. O9 is optional. Revise the sequence if evidence suggests a better user outcome, without losing intensity investigation or the broader roadmap.

### Entry points and research

Current integration: boringNotch/ContentView.swift (activity precedence, shape, hover/input routing); components/Today/TodayView.swift (TodayNotchGlance, reminder banner, cards); TodayStore.swift and TodaySchedule.swift (timing, ledger, focus); components/Settings/Views/NotchSettingsView.swift and AppearanceSettingsView.swift; models/Constants.swift (Defaults). Inspect before inventing type names. Owners: CLAUDE.md, docs/Today.md, docs/Customization.md, docs/Upstream-integration-2026-10-13.md. Save recommendations in docs/Customization.md, clearly separate from accepted decisions.

Relevant fork scout examined Atoll, Not So Boring Notch, BoringNotchPlus, servitola and QuotaNotch. Useful fixes already adapted include artwork downsampling, gesture momentum guards, paired media timing, invalid-duration slider protection, battery centering and an IOKit resource-release fix. Other fork features are source/documented references, not verified local app capabilities.

### Acceptance for this planning pass and later execution gates

Deliver a concise source-bound capability map, ranked roadmap with cost/dependencies, a concrete first-slice behavior/Settings design, haptic trial plan and an executable first-slice prompt. Make uncertainty explicit. No app code changes in this pass.

The future implementation prompt should include: saved preferences survive restart; defaults preserve the current useful layout; every supported wing combination keeps the hardware notch centered, stays within chosen width/normal height, handles long text and retains valid clicks; hidden/quiet/fullscreen states behave as intended; Today scroll position/card navigation survives; controls don't cover content; haptic off and unsupported-hardware fallback work; true intensity needs physical comparison. Test meaningful changed logic, build the actual Release candidate, then separately verify runtime/install if authorized. Preserve unrelated edits, upstream notices and updater-disabled behavior.

Previous gates are historical: 105/105 XCTest passed before the latest compact UI change; that later UI passed unsigned Release build and installed native inspection. Do not claim old tests cover new implementation. Signed distribution, camera/display switching and physical haptic acceptance remain unverified. For a future authorized local install, retain a temporary rollback until the replacement launches from Applications, then remove only that update's rollback copy, per the user's recorded preference.
