# Lid fade: ideas for a comprehensive version

*Type: CHRONOLOGICAL. Audience: AGENT-REFERENCE and the user. Proposals, not decisions. Current behaviour lives in `KeepAwake.md` § Lid fade.*

## Where it stands (2026-10-30)

The shipped fade is deliberately simple: a click-through black window over the built-in display, eased from clear at 50° to black at 12°, driven by the lid-angle sensor. The user wants a fuller, Duo-style lid effect later, built from the best of the apps below and any newer ones (including effects modelled on folding phones). Not scheduled.

## Prior art found 2026-10-30 (one web search; likely incomplete)

| App | Effect | Mechanism | Permission | License |
|---|---|---|---|---|
| [Dimmer](https://github.com/kalkman-code/dimmer) | Frosted blur by angle (two adjustable angles), screen and keyboard dim (100° to 68° default), "snap to blur" on a quick close, privacy veil | Frosted layer, not screen capture; private DisplayServices (screen) and CoreBrightness (keyboard); sensor over IOKit HID, no polling timer without a sensor | None | GPL-3.0 |
| [Lid Plane](https://github.com/jh3y/lid-plane) | Desktop held at an apparent fixed angle, progressive blur below 110°, more blur at the top | ScreenCaptureKit, Metal shader, MPS blur pyramid; sensor ~30 Hz; capture pauses in clamshell | Screen Recording | GPL-3.0 from v0.3.2 (MIT before) |
| [iFold Mac](https://github.com/maheshj01/ifold-mac/releases) | Bends the live desktop as the lid closes | Screen capture | Screen Recording | Unchecked |
| [foldelight](https://alternativeto.net/software/foldelight/about/) | Perspective, diffused edge, darkened sides, black by the fold limit | Unchecked | Unchecked | Open source, unchecked |
| [Cladofold](https://github.com/Dantease/cladofold/releases) | Blur, darkening and smoothing settings | Unchecked | Unchecked | Unchecked |
| [lidoff](https://github.com/mishamyrt/lidoff) | Display and keyboard backlight to zero below 30° (5° = closed), polls every 300 ms | Brightness controls | None | MIT |
| [flutter_lid_effect](https://pub.dev/packages/flutter_lid_effect) | Perspective, blur, gradient dim inside one Flutter app | Plugin, not system-wide | n/a | Unchecked |

## Directions to weigh

- **I1 Frosted stage, no permission (cheapest).** Add a system blur (`NSVisualEffectView`, behind-window blending) before the black stage: clear, then frosted, then black. Same failsafes and battery as today. Dimmer shows this works without Screen Recording.
- **I2 Real brightness and keyboard dim.** Lower the actual backlight instead of only covering pixels (saves power on the way down). Needs private DisplayServices/CoreBrightness and a restore-on-quit record, which breaks the current "a window can't get stuck" property; Dimmer's restore rules are the model.
- **I3 Angle-held "fold" (Lid Plane, iFold).** Visually striking, but needs Screen Recording and continuous capture plus Metal while visible. Conflicts with the battery work (`Battery-efficiency-2026-10-14.md`); only as an opt-in mode.
- **I4 Snap and veil.** Quick-close detection (angle velocity) and a hotkey privacy veil reuse the same overlay.
- **I5 Tunables.** Start and end angles, curve, tint; per-mode toggles in Settings > Battery > Lid Fade.

Before building: rerun the survey (newer apps, folding-phone-inspired effects), read Dimmer's and Lid Plane's source for sensor quirks by model, and keep borrowed code GPL-compatible with upstream notices.
