# Atoll comparison and selective adaptations

**2026-10-09 integration:** The adaptations are carried into the staged upstream
integration on `codex/absorb-upstream-2026-10-09`. See
[the current integration evidence](Upstream-integration-2026-10-09.md). Historical
pending-candidate statements below no longer describe this checkout.

**2026-09-23 update:** The gesture and timing adaptations are now integrated into
the upstream candidate, with explicit clipboard capture and Shelf improvements.
The previously linked combined-candidate worktree is no longer present. Treat
that integration note as historical until the candidate is located and verified.
The remainder of this file preserves the original 2026-09-19 source audit;
its horizontal-swipe placeholder and pending-integration findings are superseded.

Reviewed on 2026-09-19 against our `eda4f07` baseline and
[Atoll `bbf3397b46e4e2da9d03bd346b9c5a29bd8543f5`](https://github.com/Ebullioscopic/Atoll/tree/bbf3397b46e4e2da9d03bd346b9c5a29bd8543f5).
This is a source audit. It does not establish installed-app or hardware acceptance.

## What we already have

| Area | Existing implementation | Atoll difference |
| --- | --- | --- |
| Media | Controller selection, transport, seek, lyrics, favorites, configurable buttons, artwork and live activity in `MusicManager.swift` and `components/Notch/NotchHomeView.swift` | More gesture options and a larger media state implementation. Our horizontal-media setting is still a disabled placeholder. |
| Calendar, reminders and Shelf | EventKit calendar/reminders, file and promised-file drops, persistence, sharing and AirDrop | The main workflows already overlap. Our Today projection is separate from the existing editable Reminders integration. |
| Camera, battery and HUD | Camera mirror, charge activity, volume/brightness HUD and vertical opening/closing gestures | No reason to duplicate these implementations. |
| Lock screen | Existing window show/hide and SkyLight behavior | Atoll's separate weather, timer and device widgets are additional features, not something we already have. |
| Additional utilities | Clipboard copy helpers; unused download UI scaffolding | No actual clipboard history, user timer, system-stats dashboard or Bluetooth activity. The download scaffolding has no producer, so it is not a working feature. |

The existing Today behavior remains the compatibility boundary: Today is the
default view, its data is a read-only projection, and its exact scroll position
persists. The planning vault and live payload are not part of this adaptation.

## Adapted now

- **Ignore inertial scroll input for discrete notch gestures.** Atoll's
  [PanGesture.swift](https://github.com/Ebullioscopic/Atoll/blob/bbf3397b46e4e2da9d03bd346b9c5a29bd8543f5/DynamicIsland/extensions/PanGesture.swift)
  rejects the momentum tail after a touch gesture. Our adapter retains its
  existing axis filtering, mouse-wheel scaling, timeout, and event pass-through.
  Real touch completion/cancellation also cancels the pending timeout; momentum
  completion does not emit a duplicate end callback.
- **Keep media position and timestamp paired.** Atoll's
  [NowPlayingController.swift](https://github.com/Ebullioscopic/Atoll/blob/bbf3397b46e4e2da9d03bd346b9c5a29bd8543f5/DynamicIsland/MediaControllers/NowPlayingController.swift)
  treats elapsed position and sampling time as a pair and uses the adapter's
  microsecond fields. This prevents a new position from inheriting an old
  sampling time. The bundled adapter already supports `stream --micros`.
  Legacy second-based payloads remain supported. This does not import Atoll's
  full artwork handoff or stale-sample heuristics.
  Pause/resume/rate changes without a position sample re-anchor the projected
  active position at receipt, so paused time is not counted on resume.

Attribution is retained in the modified source files and `THIRD_PARTY_LICENSES`.
No Atoll assets or additional dependencies are needed.

## Options worth considering next

1. **Opt-in horizontal media swipes.** Finish the existing disabled setting,
   restrict the interaction to the player, and verify one action per swipe.
   It must not compete with Today scrolling, calendar navigation or sliders.
2. **A small local focus timer.** Add only if a visible countdown in the notch
   would be useful. It can be independent of Today task state and vault writes.
   Atoll's full timer also has external timer and lock-screen integration.
3. **Explicit clipboard-to-Shelf capture.** Reuse the existing Shelf for a
   deliberate capture action. Continuous clipboard history is a separate
   product choice with retention, exclusions and clear-history controls.
4. **Bluetooth battery status.** A compact peripheral status display would add
   something new. The parallel upstream review is already considering this;
   avoid implementing it twice. Actual device verification is required.
5. **System stats or dedicated lock-screen widgets.** Real additions, but lower
   priority unless the user wants those readings in the notch. Avoid importing
   Atoll's sensor, weather and lock-screen managers as one large bundle.

The download activity is deferred: it needs a reliable data source, not only UI.
The clipboard helper already overlaps; the Shelf cache change requires a storage
migration. Neither justifies an import in this pass.

## Parallel upstream integration

The active task **Find feature parity gaps** is importing `upstream/dev` into
`codex/absorb-upstream-dev` in a separate worktree. At review time it still lacks
these two Atoll fixes. This patch is against `eda4f07`, not that uncommitted merge.
When combining them, preserve its helper lifecycle work and gesture-direction
normalization, then carry over the momentum guard, timing resolver, decoder
fields, `--micros` argument, notices and regression tests. Do not overwrite the
newer controller or gesture file wholesale.

## Verification commands

Results on 2026-09-19: gesture and timing regression suites passed, all nine
Python publisher/bridge tests passed, `TodayPayloadTests` passed, and the unsigned
Release build succeeded. Independent code review passed. A read-only `get
--micros` probe against the bundled adapter returned all three timing fields as
integers. No installed app, current playback, or live Today payload was changed.

The gesture test feeds synthetic AppKit scroll events through the actual private
coordinator. Concatenation keeps its implementation private in production.

```sh
mkdir -p work
python3 tests/run_pan_gestures.py
swiftc -D NOW_PLAYING_TIMING_TEST boringNotch/MediaControllers/NowPlayingController.swift boringNotch/MediaControllers/NowPlayingStreamSupport.swift tests/NowPlayingTimingTests.swift -o work/now-playing-timing-tests
work/now-playing-timing-tests
python3 -m unittest -v tests/test_publisher.py tests/test_bridge.py
swiftc boringNotch/components/Today/TodayPayload.swift boringNotch/components/Today/TodayBridgeStatus.swift tests/TodayPayloadTests.swift -o work/atoll-today-tests
work/atoll-today-tests
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release -derivedDataPath work/atoll-build CODE_SIGNING_ALLOWED=NO build
git diff --check
```

Unit tests and a successful build do not establish physical trackpad behavior or
live Spotify/Apple Music timing. The installed application is not replaced by
these commands.
