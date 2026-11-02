# Keep Awake

*Type: CURRENT-STATE. Audience: AGENT-REFERENCE and the user. Fork feature, 2026-10-30; one-click setup, agent matching and lid fade added the same day.*

A cup in the open notch's header, modelled on Amphetamine and KeepingYouAwake.

- **Click:** toggle keep-awake for the default duration (Settings > Battery > Keep Awake).
- **Right-click:** 15 min, 1 h, 2 h, 4 h, until stopped, the two lid-closed switches and the lid fade.
- **Colour:** gray off, white idle keep-awake, orange while system sleep is off.

## Two layers

| Layer | Mechanism | Needs | Can it get stuck on? |
|---|---|---|---|
| Idle keep-awake | In-process `IOPMAssertion` (KeepingYouAwake uses `caffeinate -w` for the same effect) | Nothing | No. macOS drops the assertion when the app exits. |
| Lid-closed keep-awake | `pmset -a disablesleep 1` through `/usr/local/libexec/boringnotch-lidguard` | One-time root setup below | Designed not to: the script's watchdog (own process group) turns sleep back on when the app exits or the battery hits 10%, and the app turns it off at its next launch. Verify after setup (below). |

Lid-closed has two triggers: "Also with lid closed" (rides along with a manual session) and "Lid closed while Claude or Codex works", with a 90 s grace between turns. The helper counts an idle-sleep assertion held by any of these. Evidence as of 2026-10-30:

| Agent | Signal | Evidence |
|---|---|---|
| Claude desktop (`com.anthropic.claudefordesktop`) | Its own `NoIdleSleepAssertion` named "Electron", matched by the app's PID | Observed live during a turn |
| Codex desktop (`com.openai.codex`) | Same, by PID | Not observed; no Codex turn ran during the probe |
| Claude Code CLI | A `caffeinate -i -t 300` child whose parent executable is `claude` (native install; an npm install runs as `node` and is missed) | From the binary's code; parent-name match tested with a stand-in `claude` |
| Codex CLI | `PreventUserIdleSystemSleep` "Codex is running an active turn", held by the `codex` executable | From the binary's strings only |

The app is sandboxed in signed builds, so the XPC helper (unsandboxed) runs `sudo -n`, the setup prompt and the agent check.

## Cutoffs (`KeepAwakePolicy`)

- Battery at or below the threshold (default 20%) on battery ends a session, unless the session started below it. Lid-closed has no such override.
- Low Power Mode ends a session and blocks lid-closed (setting, on by default).
- Thermal state serious or critical blocks lid-closed only. `.serious` can trip during heavy builds with the lid shut, which lets the Mac sleep and stops the work; that is the chosen trade (heat in a closed laptop beats a finished build). Change `runningHot` in `KeepAwakeManager` to `.critical` only if that proves too eager.

## One-time setup for lid-closed

Settings > Battery > Lid Closed > **Set Up…** asks for the administrator password once. The helper then, as root, checks the sudoers line with `visudo -cf` before it lands, installs the script bundled in the app (`boringNotch/components/KeepAwake/boringnotch-lidguard`) to `/usr/local/libexec/boringnotch-lidguard` (root:wheel 755), and installs `/etc/sudoers.d/boringnotch-lidguard` (440) allowing only that script without a password. **Remove** turns sleep back on, then deletes both. **Repair…** appears when the script is not root-owned or the rule is missing, and reinstalls both. Rerun Set Up after the bundled script changes.

The helper refuses to use the rule if the script or any folder above it is not root-owned or is group/world-writable (status "insecure").

Manual equivalent, from the repo root:

```bash
sudo install -d -o root -g wheel -m 755 /usr/local/libexec
sudo install -o root -g wheel -m 755 boringNotch/components/KeepAwake/boringnotch-lidguard /usr/local/libexec/boringnotch-lidguard
echo "$(whoami) ALL=(root) NOPASSWD: /usr/local/libexec/boringnotch-lidguard" | sudo tee /etc/sudoers.d/boringnotch-lidguard >/dev/null
sudo chmod 440 /etc/sudoers.d/boringnotch-lidguard
sudo visudo -cf /etc/sudoers.d/boringnotch-lidguard
```

Verify the crash fail-safe once after setup: turn on "Also with lid closed" and start a session (the cup turns orange), then

```bash
pmset -g | grep SleepDisabled
ps -axo pid,pgid,ppid,command | grep '[b]oringnotch-lidguard-watchdog'
pkill -9 -x "Boring Notch"
```

`SleepDisabled` should read 1, the watchdog's PGID should differ from its parent's, and about 10 s after the kill `pmset -g | grep SleepDisabled` should read 0. Relaunch Boring Notch afterwards.

Manual removal:

```bash
sudo /usr/local/libexec/boringnotch-lidguard off
sudo rm /etc/sudoers.d/boringnotch-lidguard /usr/local/libexec/boringnotch-lidguard
```

## Lid fade

"Fade the screen as the lid closes" (Settings > Battery > Lid Fade, or the cup's menu) dims the built-in screen to black as the hinge closes, Duo-style, and brings it back as it opens. `LidFadeController` reads the lid-angle sensor (SPU HID `0x05AC:0x8104`, usage page 0x20, usage 0x8A, feature report 1, angle in bytes 1-2; this Mac read 131° fully open) and drives a click-through black window over the built-in display. `LidFadeCurve` maps 50° to clear and 12° to black with an ease.

- **Battery:** four feature reads a second when the lid is above 80° or shut below 3°, 30 a second only in between. Off when the toggle is off.
- **Can't get stuck:** it is a window, not a gamma change, so it disappears if the app quits. If the sensor says "closed" for 5 s while the lid switch (`AppleClamshellState`) says open, the fade stands down until the lid reads open again.
- **Later:** prior art (Dimmer, Lid Plane, iFold and others) and directions for a fuller blur/fold effect: `LidFade-ideas-2026-10-30.md`.
- **Sandbox:** the installed ad-hoc build is not sandboxed and opens the sensor. A signed sandboxed build may not; Settings then says the sensor can't be read.

## Tests

```bash
swiftc boringNotch/components/KeepAwake/KeepAwakePolicy.swift tests/KeepAwakePolicyTests.swift -o work/keepawake-tests && work/keepawake-tests
```
