# Next customization pass: compact Today-glance controls

Prepared from the October 13 roundtrip and subsequent width feedback. This packet
is ready for an authorized implementation request; its preparation is not itself
an instruction to install, commit or push.

Read AGENTS.md/CLAUDE.md and verify the live source first. The installed app's source
was last verified at /Users/weiwei/.codex/worktrees/absorb-upstream-oct09/boring-notch-today,
branch codex/absorb-upstream-2026-10-09, with a resolved, staged, uncommitted upstream
merge. The primary /Users/weiwei/code/boring-notch-today is older architecture.
Preserve staged integration and unrelated edits. Do not reset or build the older
checkout accidentally. Reconcile current changes before editing.

Implement a bounded O6 slice: reduce Today's lateral obstruction and add local
controls for its closed-notch glance. Current TodayNotchGlance uses two fixed
90-point frames, a full work title, a clear center of notchWidth+10, and countdown
text. The user accepts normal closed height but finds the side extensions too wide.

Product requirements:
- Keep the hardware-notch center fixed at its screen position. Wings fit compact
  content independently with strict caps; removing one does not shift the center.
- Show a conservative short title/identity and compact stable-width countdown.
  Preserve the full title in help/accessibility. Do not infer structured course
  identity from arbitrary prose; inspect the model/payload examples first.
- Proposed Settings → Notch → Closed Notch Glance controls: Automatic/Hidden,
  Compact/Full label, Compact/Balanced width cap, and 1h/6h/24h/All deadline horizon.
  Defaults: Automatic, Compact, Compact, All. Proposed per-side caps are 56 and
  80 points including actual text padding; verify legibility before settling.
- Horizon filters routine countdown visibility only. Hidden suppresses the Today
  glance, preserving reminder state/details inside Today and other existing
  activities. Do not alter vault state or authoritative deadline timestamps.
- Reminders/focus retain current documented priority within Today; preserve
  existing notifications, HUD and battery precedence. Full controls stay inside
  Today rather than overlaying other tabs. No lower routine strip.
- Preserve all four tabs, exact Today scroll restore, click-to-card, fullscreen
  hiding, zero-height behavior, gesture rules and disabled stock updater feeds.
- No automatic menu-item collision detection in v1; manual caps/Hidden provide
  control without new permissions. No full widget/extension/preset framework.

Inspect ContentView render routing, closedNotchContent, computedChinWidth,
background/shape/hover/click bounds, TodayView/TodayNotchGlance, NotchWindowManager's
centered backing window, Constants and NotchSettingsView. Keep one coherent
presentation decision for affected geometry and routing using existing idioms.
For a truly centered row with symmetric outer padding, (rightWidth-leftWidth)/2
compensates its hardware-center displacement, but verify this hierarchy before
using that formula. Width of the transparent backing window is not visible width.

Evidence gates: meaningful geometry/preference tests; short/long labels;
left-only/right-only/hidden; countdown representation boundaries; reminder/focus/
media/HUD transitions; actual center and outer bounds; valid click hit regions;
restart/invalid-default fallback; card navigation/scroll; fullscreen suppression.
Build the actual unsigned Release candidate. Runtime and installation need the
current request's authorization. Old 105-test counts do not prove this slice.
For an authorized update, verify launch from /Applications/Boring Notch.app before
removing only that update's temporary rollback copy. No commit/push unless asked.

Save results in docs/Customization.md and the existing integration history. Report
source edits, tests, build, runtime/install and human acceptance as separate gates.

Retain O5 genuine haptic intensity research, O7 Today preferences, O8 presets and
O9 Quick Notes in the roadmap. They are separate subsequent scopes. A source-backed
Tactile actuator candidate is recorded in docs/Customization.md; no physical
intensity result is established. Do not replace that request with a pattern picker
or add unsupported controls while implementing this bounded geometry slice.
