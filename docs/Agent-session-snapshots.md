# Agent session snapshots

Type: CHRONOLOGICAL. Dated evidence, not current installation or acceptance authority.

Preserved verbatim from CLAUDE.md during the October 19, 2026 instruction audit.

## Current state and resume point

As of October 14, 2026:
- `main` (local only, **not pushed**) holds everything: the October 9 upstream/dev merge as a real two-parent merge (`8cb7662`, upstream side `dee29a6`), then O5 haptics, O6 compact glance, O7 Today preferences and O8 presets (`67c11ce`), then docs, the haptic-modifier revert (`19093e8`) and the battery-efficiency pass (`817d7fb`). The primary checkout at this path is on `main` and is the build source again. D-hall remains a separate fourth tab. Battery evidence: `docs/Battery-efficiency-2026-10-14.md`.
- `codex/atoll-fixes` gained a snapshot commit of its old uncommitted edits; an audit on Oct 14 found every Today feature from them (reminder ledger, focus, `NSClipView` scroll keeper, deadlines, Today sizing) already in `main`. The worktree `/Users/weiwei/.codex/worktrees/absorb-upstream-oct09/boring-notch-today` (`codex/absorb-upstream-2026-10-09` at `5018a28`, behind `main` only by this CLAUDE.md update) is now redundant; it was not removed.
- Installed: unsigned Release of `main` with actuator-backed notch haptics and a Tap strength slider (default 0.70), executable SHA-256 `402f2d87ce3f3259e6b6a3530f53781dca319ed3859b3be1ba5a6c98dbe36587`, Oct 14 ~22:30 EDT; launched with no crash report, rollback deleted, synthetic hover logged `cue actuator`. Includes the battery-efficiency changes.
- Oct 14 gates from `main`: 10/10 Python, MCP smoke, standalone TodayPayload and TodaySchedule pass; Release build 0 errors (`work/main-release.log`). XCTest was not rerun on the committed tree; latest slices are in `docs/Customization.md`.
- Open: daily-use check of hover haptics at 0.70 and anything above 1.30 (Oct 14 physical trial: 0.70 chosen, 0.70→1.30 scaled up; see docs/Customization.md O5 October 14); signed-build actuator access; human visual acceptance of O6–O8; push to `origin`; absorbing the 35 newer `upstream/dev` commits in a separate pass.


## 2026-10-26 upstream absorb (overnight pass)

- Branch `codex/absorb-upstream-2026-10-20` (worktree `work/absorb-1020`) merged `upstream/dev` through `8041b26` as a two-parent merge, local commit `f09e99f`. Upstream delta was 6 commits, only `updater/appcast-dev.xml` changed; no conflicts, no Today wiring touched, fork updater change intact.
- Verification on that branch: 10/10 Python tests, standalone TodayPayload suite pass, unsigned Release build `** BUILD SUCCEEDED **` (log `work/absorb-1020/work/build.log`). MCP smoke and XCTest not run. Not installed, not pushed, not merged into `main`.
- Recovery copy before work: `~/.local/share/codex-recovery/boring-notch-today-2026-10-26/` (all-refs bundle, untracked tar, dirty-main patch). Main checkout still has 8 uncommitted files, untouched.
- Remaining gate: Weibao's decision to fast-forward/merge the branch into `main` and install.

## 2026-10-26 commit consolidation and follow-up

The user authorized local commits for the six overnight lanes. The upstream absorb is already committed at `f09e99f` on `codex/absorb-upstream-2026-10-20` in `work/absorb-1020`; it is not merged into main or installed. This documentation commit preserves the moved October 14 snapshot and the October 26 receipt together with its CLAUDE.md resume pointer. It includes no app-source changes. Six unrelated dirty source/battery paths in the primary checkout remain outside this commit.

Resume by comparing the absorb worktree with current main, reviewing the pending D-hall/Today/audio/battery work separately, then preparing the combined candidate only after the relevant merge/update decision. Reuse the recorded payload/Release evidence for unchanged inputs; rerun the relevant checks after integration. Installation and live notch/Today acceptance remain separate gates. No push, install, worktree removal or new chat dispatch follows from this checkpoint.
