# Keep Awake

*Type: CURRENT-STATE. Audience: AGENT-REFERENCE and the user. Fork feature, 2026-10-30.*

A cup in the open notch's header, modelled on Amphetamine and KeepingYouAwake.

- **Click:** toggle keep-awake for the default duration (Settings > Battery > Keep Awake).
- **Right-click:** 15 min, 1 h, 2 h, 4 h, until stopped, plus the two lid-closed switches.
- **Colour:** gray off, white idle keep-awake, orange while system sleep is off.

## Two layers

| Layer | Mechanism | Needs | Can it get stuck on? |
|---|---|---|---|
| Idle keep-awake | In-process `IOPMAssertion` (KeepingYouAwake uses `caffeinate -w` for the same effect) | Nothing | No. macOS drops the assertion when the app exits. |
| Lid-closed keep-awake | `pmset -a disablesleep 1` through `/usr/local/libexec/boringnotch-lidguard` | One-time root setup below | Designed not to: the script's watchdog (own process group) turns sleep back on when the app exits or the battery hits 10%, and the app turns it off at its next launch. Verify after setup (below). |

Lid-closed has two triggers: "Also with lid closed" (rides along with a manual session) and "Lid closed while Claude works", which follows the Claude desktop app's own idle-sleep assertion, matched by Claude's PID, with a 90 s grace. The app is sandboxed, so the XPC helper (unsandboxed) runs `sudo -n` and the Claude check.

## Cutoffs (`KeepAwakePolicy`)

- Battery at or below the threshold (default 20%) on battery ends a session, unless the session started below it. Lid-closed has no such override.
- Low Power Mode ends a session and blocks lid-closed (setting, on by default).
- Thermal state serious or critical blocks lid-closed only. `.serious` can trip during heavy builds with the lid shut, which lets the Mac sleep and stops the work; that is the chosen trade (heat in a closed laptop beats a finished build). Change `runningHot` in `KeepAwakeManager` to `.critical` only if that proves too eager.

## One-time setup for lid-closed

Run from the repo root. It installs a root-owned script and a sudoers rule that allows only that script without a password.

```bash
sudo install -d -o root -g wheel -m 755 /usr/local/libexec
sudo install -o root -g wheel -m 755 scripts/keep-awake/boringnotch-lidguard /usr/local/libexec/boringnotch-lidguard
echo "$(whoami) ALL=(root) NOPASSWD: /usr/local/libexec/boringnotch-lidguard" | sudo tee /etc/sudoers.d/boringnotch-lidguard >/dev/null
sudo chmod 440 /etc/sudoers.d/boringnotch-lidguard
sudo visudo -cf /etc/sudoers.d/boringnotch-lidguard
```

The helper refuses to use the rule if the script or any folder above it is not root-owned or is group/world-writable (status "insecure"). After editing the script in the repo, rerun the second command.

Verify the crash fail-safe once after setup: turn on "Also with lid closed" and start a session (the cup turns orange), then

```bash
pmset -g | grep SleepDisabled
ps -axo pid,pgid,ppid,command | grep '[b]oringnotch-lidguard-watchdog'
pkill -9 -x "Boring Notch"
```

`SleepDisabled` should read 1, the watchdog's PGID should differ from its parent's, and about 10 s after the kill `pmset -g | grep SleepDisabled` should read 0. Relaunch Boring Notch afterwards.

Remove:

```bash
sudo /usr/local/libexec/boringnotch-lidguard off
sudo rm /etc/sudoers.d/boringnotch-lidguard /usr/local/libexec/boringnotch-lidguard
```

## Tests

```bash
swiftc boringNotch/components/KeepAwake/KeepAwakePolicy.swift tests/KeepAwakePolicyTests.swift -o work/keepawake-tests && work/keepawake-tests
```
