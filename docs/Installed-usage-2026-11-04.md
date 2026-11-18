# Installed CPU and power observation, November 4, 2026

The installed Boring Notch is quiet in the observed workload. Further notch optimizations are unlikely to materially change this Mac's current battery demand while unrelated worker processes are this busy. This is an observation of current use, not an unplugged battery-runtime test or a matched before/after comparison.

## Identity and method

Installed executable: `/Applications/Boring Notch.app/Contents/MacOS/Boring Notch`, PID 39816, SHA-256 `448a9b8389b3bbb611d2c5cc85e0eb28228146b976186b7104bfea3d22083987`, matching today's verified installation.

Collected a 120-second process-counter interval and a separate 60-second follow-up including the discovered Perl Now Playing child. Counters came from `proc_pid_rusage`, version 6. CPU times were converted using this Mac's Mach timebase, 125/3 ns per tick, rather than treating raw CPU counters as nanoseconds. Percentages use 100% for one fully occupied CPU core.

The user authenticated a dedicated, bounded `powermetrics` command in Terminal. Its 12 five-second delta samples cover 60.72 seconds, approximately 11:16:42-11:17:43 EST. The final cumulative summary was excluded from aggregation. No password was read or recorded. Neither the foreground notch UI nor feature preferences were changed. An independent five-second stack sample found the main thread waiting for events, the Now Playing reader blocked on pipe input, and worker threads waiting. This does not establish that every music/camera/drag scenario is inexpensive.

## Measured results

| Code | Process or group | Average CPU, one core = 100% | End task footprint | Interrupt wakeups |
|---|---|---:|---:|---:|
| M1 | Installed app, 120 s | 0.033% | 48.9 MiB | 60 total, 0.50/s |
| M2 | Nine Today MCP Python processes, 120 s | 0.089% combined | 461.4 MiB aggregate charged footprint | 216 total, 1.80/s |
| M3 | Installed XPC helper, 120 s | 0 measured CPU increment | 3.6 MiB | 0 |
| M4 | Perl Now Playing child, separate 60 s | 0.0021% | 6.4 MiB | 2 total |

The app's independent `powermetrics` coalition measurement was **0.0259% CPU**, **0.230 energy-impact units/s**, and 27 interrupt wakeups during 60.72 seconds. Energy impact is a relative score, not watts. The two process-counter intervals also agreed broadly on app CPU: 0.033% and 0.028%.

The app and XPC helper recorded no disk-write counter increase. The nine MCP processes recorded 96 KiB of disk-write accounting and 920 KiB of logical writes over 120 seconds. These are different OS accounting counters, not two measurements of the same physical disk traffic. All observed package-idle-wakeup counters stayed zero; the machine was busy, so that does not prove the processes would never wake an idle CPU.

Aggregate task footprint is an OS accounting measure and can include compressed/charged memory; it is not a claim of 461 MiB of unique resident physical RAM. Process samples retained the same PIDs/start identities throughout their compared endpoints.

## Battery and wider system context

**M5:** The Mac was on AC, reporting 67% and charging at the initial check. No unplugged discharge rate or hours-of-battery estimate is established. IORegistry charging/current telemetry was not used to invent an app watt figure.

`powermetrics` estimated mean CPU power at **32.09 W** (28.97-37.03 W), GPU power at **0.34 W**, and CPU/GPU/ANE combined power at **32.43 W**. These estimates exclude other whole-machine loads such as display and charging losses. Thermal pressure was Moderate throughout the profile.

**M6:** The Claude resource coalition averaged **640% CPU**, approximately 6.4 cores, across the power interval. Its busy tasks included several Node workers and a Playwright-launched Chrome renderer; that renderer alone averaged about 105% CPU. The Codex coalition averaged about 39.5%, including the current inspection and its connected processes. These coalition figures should not be added to the special dead-task bucket, which is not another independent running application. No outside process was stopped.

`pmset -g assertions` showed an unrelated shell-owned `caffeinate` assertion held for over 15 hours, plus other app/system assertions. It showed no assertion named Boring Notch keep awake. Sleep prevention is relevant when the Mac would otherwise sleep; it does not explain all active-use power draw. Its intended ownership should be checked before stopping it.

## Further improvements, ranked proposals

| Code | Proposal | Evidence, constraint and acceptance |
|---|---|---|
| O1 | Investigate busy automation workers and long-lived sleep prevention if unexpected | Highest potential battery return under this workload. Identify their owning chats/jobs first; keep useful work running. A comparable power interval after authorized job cleanup would establish the change. No process cleanup was authorized or performed here. |
| O2 | Reduce unnecessary MCP client instances through connection lifecycle ownership | Nine stdio transports belong to the Codex host and collectively exceed the notch app's CPU/footprint. They can serve separate active chats, so do not kill them as apparent duplicates. First establish which sessions can release idle connections. A shared multi-client service would require an explicit design, not simply reusing one stdio process. |
| O3 | Reduce follower heartbeat lock retries and transient-status write work | Every follower retries leadership every five seconds (`scripts/boring-notch-today-mcp.py:93-105`). One leader durably rewrites status; `today_bridge.py:198-218` fsyncs both the file and directory. Consider bounded follower backoff and atomic but non-durable heartbeat status writes while preserving payload durability, private storage and prompt leader takeover. Test takeover within the existing 15-second stale allowance. Current absolute cost is small. |
| O4 | Stop or coalesce redundant maintenance timers | KeepAwake polls every 15 seconds even when agent monitoring is disabled (`KeepAwakeManager.swift:78`, `:199-207`); battery/thermal/settings already have observers. Start that poll only when monitoring needs it, with an immediate enable evaluation and retained safety recovery. Add measured timer tolerance/coalescing to noncritical fallback checks. Do not delay reminder deadlines or active focus updates. |
| O5 | Avoid semantic Today evaluation on status-only heartbeat reloads | `TodayStore.reload():127-128` always calls `tick()`. The payload identity cache already prevents repeated plan decoding, but each status event still reconstructs scheduling state and reschedules its timer. Skip semantic work only when payload, settings and the next semantic transition are unchanged. Verify reminders, snooze, quiet hours and wake catch-up before claiming savings. |

No new application implementation, reinstall, preferences, payload, power policy or process lifetime changes were made during this investigation. The pre-existing uncommitted runtime changes remain intact. Next authoritative battery gate: a controlled unplugged comparison with matched workloads and feature states. A short AC profile cannot establish battery duration or isolate display/GPU/window-server costs caused by the notch.

## Local evidence

Raw counters, stack sample, root-authenticated power profile, scripts and derived summary are under `work/installed-usage-20261104/`: `measurements.json`, `followup-measurements.json`, `app-sample.txt`, `system-power.plist`, `measure.py`, `measure_followup.py`, `summarize.py`, `summary.json`. Scratch is gitignored; this report preserves the material results.
