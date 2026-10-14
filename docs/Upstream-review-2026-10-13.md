# Upstream review, 2026-10-13

**Integration update:** The user subsequently authorized absorption and a local app
update. The missing worktree was recovered from its surviving index. O1 and O2
are integrated and installed; see [October 13 integration](Upstream-integration-2026-10-13.md). The original review below records the pre-implementation state.

Fresh `git fetch upstream` succeeded. Reviewed changes since the October 9
integration target `dee29a6`, against current dev `30dd715` and main `64b5459`.
Compared candidate source with the primary checkout at `f994829` plus its
existing working-tree edits. This is a recommendation, not an accepted change.

## Ranked findings

| Code | Disposition | Finding | Integration and acceptance |
| --- | --- | --- | --- |
| O1 | Adapt first | [Battery notice centering, PR 1675](https://github.com/TheBoredTeam/boring.notch/pull/1675): `60c0c26`, `7453790`, `8178f3e`, `d29360e`. New PowerStatusNotice gives both sides equal measured width using hidden copies of the label and battery, keeping the black center aligned with the physical notch. Current checkout still uses unequal sides and a fixed 76-point right width. | Small layout adaptation; preserve this fork's battery arguments and effectiveClosedNotchHeight. Carry localization keys if adopting translations. Build, then inspect plugged/unplugged and charging labels on the physical notch; hidden duplicate content also needs an accessibility check. |
| O2 | Conditional | [Legacy non-notch height migration, PR 1686](https://github.com/TheBoredTeam/boring.notch/pull/1686): `4f13437`, `dd3e329`. Converts saved heights between 0 and 15 to 15 before initial view-model creation, preserving 0 and values at least 15. | Useful on the newer integrated app, whose slider excludes 1–14. Do not impose it on the older primary checkout without checking its settings contract. Verify migration boundaries and initialization order, then external-display startup. |
| O3 | Already covered | [Artwork downsampling, PR 1427](https://github.com/TheBoredTeam/boring.notch/pull/1427): `996c01a`. Upstream now caps the averaging buffer's longest side at 64 pixels. | The primary checkout already implements this mechanism through the earlier Atoll adaptation. No second absorption is needed. |
| O4 | Low priority | Remaining merged changes are localization cleanup, menu-bar spelling, Sparkle 2.10.0, swift-collections 1.7.2, release appcasts and CI artifact actions. | Localization is useful if other app languages are used; dependency updates need their own build justification. Keep stock updater feeds disabled as recorded in the integration report. No new substantial feature family appeared in this interval. |

## Evidence and limits

Reviewed fresh upstream commit histories and diffs, local battery layout,
artwork averaging and sizing code. The diff since `dee29a6` touches 17 files,
dominated by localization changes. Newly fetched shelf-temp-file, XPC-auth and
file-drop-concurrency branch refs have no unique commits against current dev;
they are not additional changes to absorb beyond the previously reviewed base.

The October 9 integration report records a broader absorption and installation,
but its worktree path no longer exists. `git worktree list` marks it prunable;
this chat has no attached worktree artifact. Therefore its present source state
and the installed executable's contents were not verified in this review.
Treat that report as historical evidence, not a live checkout.

No app sources were edited, and no build, runtime test, install, commit or push
was performed. Existing edits were preserved. Recommendation: take O1 next;
include O2 only when working from the newer integration source.
