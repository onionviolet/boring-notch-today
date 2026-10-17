# Upstream integration, 2026-10-09

**Fourth-tab restoration, 2026-10-09:** The lunch menu was already implemented in
the separate `codex/dhall-menu` worktree and was missed during the upstream
reinstall. Its menu/store/view sources and parser tests are now carried into the
integration. Home, Shelf, Today and D-hall are four separate top tabs; D-hall uses
`fork.knife`, meal/station selectors and the bounded panel height. Scroll-close
and horizontal-media gestures do not take over its menu scrolling.

Final unsigned Release build and D-hall parser/date/cache tests passed. Live
fetch on October 9 returned three meals and 604 items. The installed executable
matches the final build. Native installed inspection confirmed the fourth tab
selects D-hall, its own selection pill is highlighted and Lunch displays today's
menu. Stable tab identities, an explicit selection background and header refresh
corrected a stale Today highlight observed during this integration.

Rollback for the final install: `/Users/weiwei/.Trash/Boring-Notch-before-lunch-tab-20261009-144434.app`.
The original D-hall worktree is preserved. This update is staged/uncommitted and
not pushed. The earlier 102-test result predates this menu restoration; no new
full-suite claim is made.


**Installation update, 2026-10-09:** The user authorized reinstalling the fix.
The tested unsigned upstream-integrated product is now installed and running at
`/Applications/Boring Notch.app`. Its executable SHA-256 matches the verified
candidate. The previous app is retained at `/Users/weiwei/.Trash/boringNotch-before-upstream-20261009-141507.app`.
Native installed-app inspection confirmed Today's separate top tab, all four
ranked rows at scroll position 0, and complete footer buttons at the bottom.
Stock update feed remains absent. Source remains staged/uncommitted; no push
occurred. Older statements below about the app not being installed are historical.


Integrated source is in the attached worktree on `codex/absorb-upstream-2026-10-09`:
`/Users/weiwei/.codex/worktrees/absorb-upstream-oct09/boring-notch-today`.
Base is `f994829`; the pending merge target is upstream dev `dee29a6`.
The two CodeQL action updates unique to upstream main `e2654ee` are also carried.
All eleven merge conflicts are resolved. The merge is staged and uncommitted.
Primary checkout, main, remote branches and the installed app were not replaced.

## What changed

| Code | Implemented source |
| --- | --- |
| D1 | Upstream dev's complete app changes, including Settings-on-reopen, Apple Music streamed-artwork fallback, active-display mode, camera selection/lifecycle and authorization-loop correction, notification capture, audio routing, compact player and Settings rework. Release automation and dependencies are carried; hosted CI and signing are not verified. |
| D2 | Today remains the default read-only tab beside Home and Shelf. Preserved current user layout edits, exact native scroll persistence, bounded bridge status/refresh, 640 × 300 Today sizing and ordinary tab resizing. Compact Home has a small top tab strip; Today and Shelf remain separate panes. Tab accessibility labels identify Today rather than the calendar symbol. |
| D3 | Atoll momentum guards and paired playback timing are adapted onto upstream's managed media stream. Microsecond decoder fields and `stream --micros` are retained; runtime recovery and process lifecycle use upstream's implementation. Shared playback timelines pause when media is paused. Promised-file handling and bounded artwork color sampling are retained. |
| D4 | Stock Sparkle feed and automatic updates are disabled in the built fork; Settings explains manual updates. This prevents stock upstream binaries from replacing Today. No fork release feed was invented. |
| D5 | Preview mode renders Today in an isolated window and closes cleanly. Runtime checking found an `objc_release` crash on preview close; setting `isReleasedWhenClosed = false` corrected ownership, with exit 0 verified afterward. |

## Verified gates

| Gate | Result and evidence |
| --- | --- |
| Python publisher/bridge | 9/9 methods pass |
| Official-SDK MCP stdio smoke | Pass |
| Standalone Today Swift | Pass |
| Paired media-timing decoder/resolver | Pass using production controller and shared stream payload source |
| Synthetic AppKit gesture regressions | Pass against production PanGesture and built Defaults module; preference key uses an isolated suite with normalization disabled for the original gesture cases |
| Final unsigned Release build | Pass, `work/release-build-final.log`; built `Boring Notch.app`, scheme `boringNotch` |
| Final full XCTest | 102/102 pass, 0 failed, 0 skipped. Authoritative summary: `work/DerivedData/Logs/Test/Test-boringNotch-2026.10.09_12-20-17--0400.xcresult` |
| Candidate runtime | Today preview renders the existing snapshot. Actual notch Home → Today round trip passes; compact Home → Today round trip passes with top tabs and selected labels. Corrected preview close exits 0. Runtime copy has identifier `boring.notch.integration-preview` to distinguish it from the installed app. |
| Merge hygiene | No unresolved conflicts or conflict markers; staged and unstaged diff checks pass |

The first Release build and XCTest pass were followed by a final build/test after
preview ownership and compact-tab/accessibility corrections. Tests are local;
no hosted CI result is claimed. Live payload and planning-vault files were not
edited. Existing user changes remain in the primary checkout; copies are
included and adapted where upstream replaced their surrounding implementation.

## Remaining release gates

Commit/merge placement, push and installation remain separate actions. External
monitor behavior, real camera/device switching, streamed Apple Music playback,
physical media swipes and Finder reopen are not runtime-accepted by these tests.
Signed distribution and helper identity need their own verification before a
signed release. Local unsigned preview is not installed-app acceptance.

## Reproduce the focused checks

```sh
python3 -m unittest -v tests/test_publisher.py tests/test_bridge.py
uv run --with 'mcp>=2,<3' python tests/mcp_smoke.py
swiftc boringNotch/components/Today/TodayPayload.swift boringNotch/components/Today/TodayBridgeStatus.swift tests/TodayPayloadTests.swift -o work/today-tests
work/today-tests
swiftc -D NOW_PLAYING_TIMING_TEST boringNotch/MediaControllers/NowPlayingController.swift boringNotch/MediaControllers/NowPlayingStreamSupport.swift tests/NowPlayingTimingTests.swift -o work/now-playing-timing-tests
work/now-playing-timing-tests
python3 tests/run_pan_gestures.py
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release -derivedDataPath work/DerivedData -jobs 2 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug -derivedDataPath work/DerivedData -jobs 2 CODE_SIGNING_ALLOWED=NO test
```

## Today clipping follow-up, 2026-10-09

The installed October 8 app still used the older Today layout. Follow-up source
changes top-align the primary checkout's panel, remove implicit spacing between
its header and pane, and bound Today's height to panel height minus header and
bottom inset. The integrated branch also uses that explicit height allocation.
Both unsigned Release builds passed (`work/today-clipping-build.log` in their
respective checkouts). Native inspection of an isolated runtime copy confirmed
that Home/Shelf/Today tabs stay visible at scroll positions 0 and 1, and footer
buttons fit at the bottom. The existing live snapshot was read without edits.
The earlier 102-test result precedes this layout follow-up; the new checks are
build and visible-layout gates. Source edits remain uncommitted and the installed
app was not replaced.
