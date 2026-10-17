# Upstream absorption review, 2026-10-09

**Implementation update:** The user authorized absorbing the complete reviewed
upstream scope. Source integration and verification are recorded in
[Upstream-integration-2026-10-09.md](Upstream-integration-2026-10-09.md). The original
recommendations below are preserved as the pre-implementation review.

Source review against the current checkout, `codex/atoll-fixes` at `f994829`.
Fetched both remotes successfully. Upstream main is `e2654ee`; dev is
`dee29a6`. Relative to this HEAD, main has 46 unique commits and dev has 594;
our branch has 12 unique commits in either comparison. These counts include
merges, translations, appcasts and release automation, not just app changes.

The working tree already contains edits to TodayView, BoringViewModel,
sizing/matters and docs/Today. They were preserved. This report adds no app
implementation, merge, commit, push or installation. Recommendations are
source-reviewed, not tested integration candidates.

## Ranked candidates

| Code | Disposition | Change and source | Fit and integration cost | Acceptance gate |
| --- | --- | --- | --- | --- |
| O1 | Adapt first | [Reopen opens Settings, PR 1673](https://github.com/TheBoredTeam/boring.notch/pull/1673), `c2f19a9` plus `330a4c3` | Small AppDelegate callback. Our app already has SettingsWindowController, but no applicationShouldHandleReopen implementation. Use the reviewed MainActor callback returning false. Preserve Today preview launch behavior. | Unsigned Release build; launch/reopen through Finder and confirm one Settings window; check preview mode still works. |
| O2 | Adapt next if Apple Music is used | [Streamed artwork fallback, PR 1670](https://github.com/TheBoredTeam/boring.notch/pull/1670), `f195049` plus `7bd0c7a` | Our AppleMusicController directly accepts descriptor data as artwork. Upstream rejects text/non-image data and adds cached artist/album lookup through iTunes Search. Our ImageService already exposes the required fetch method. Adapt both commits' final mechanism into this older controller, preserving local media timing work. This adds artist/album search requests to Apple. | Check non-image descriptors, cancellation on album change, same-album track changes, failed lookup retry and unmatched results; build; verify real streamed and library tracks. Upstream matching uses permissive prefix comparisons, so inspect ambiguous titles before adoption. |
| O3 | Trial if multiple displays matter | [Active-display mode, PR 1659](https://github.com/TheBoredTeam/boring.notch/pull/1659), `094d8a8`, `4222408`, `b72d35a` | Adds a persisted display-mode enum and a notch that follows NScreen.main. Our app has screen selection, but upstream's newer NotchWindowManager is absent here. Adapt the behavior into the current window lifecycle; this is not a small standalone cherry-pick. | External-display connect/disconnect, focus transitions, fixed/all/active modes, and Today scroll restoration across window recreation. |
| O4 | Park for a dedicated camera integration | [Camera lifecycle rewrite](https://github.com/TheBoredTeam/boring.notch/commit/33d8b8a4b79a045c9802605b4b46e2ac138da710), plus [authorization-loop fix](https://github.com/TheBoredTeam/boring.notch/commit/79e2182c3a0d380673ea3d46a2101e7c20d858b8) | New CameraSessionEngine/CameraModel, selected-device intent and full session teardown. Our checkout still uses WebcamManager. The authorization-loop fix repairs the newer upstream engine, so it is not evidence that our current app has that exact CPU bug. Carry the corrected final engine only as a coherent lifecycle change. | Camera permission transitions, unavailable/disconnected devices, preview close/reopen, multiple displays and idle CPU; upstream lifecycle tests plus build and real camera verification. |

## What to skip in this pass

Upstream main's unique changes are primarily release/channel automation,
CodeQL configuration, appcasts and the product rename. They offer little
immediate Today benefit. Keep fork updates and signing separate: importing
stock appcasts without a fork release plan risks replacing fork functionality.

Dev also has notification capture, audio routing, compact-player and Settings
reworks. These are broader feature families with dependencies across app,
helper, window and UI code. They are reasonable future integration scopes,
but do not justify a wholesale merge for the small improvements above.
The full source tree comparison spans 255 files, making isolated integration
and explicit preservation of Today wiring essential.

## Recommendation and verification state

Start with O1 and O2 as a bounded integration. O3 is useful when display
switching is a real workflow need. O4 belongs in a separate camera pass.
Existing Atoll gesture/timing adaptations are present in this branch and
should be retained.

Checks performed: remote fetches, branch/working-tree inspection, upstream
commit histories and candidate diffs, local AppDelegate/AppleMusicController/
ImageService/window/camera inspection, and public PR verification for O1/O2.
No build or runtime test was run because this task only reviews candidates.
