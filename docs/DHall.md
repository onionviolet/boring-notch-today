# D-hall menu tab

**Restored 2026-10-09:** D-hall is the fourth tab after Home, Shelf and Today in
the upstream integration. The existing `codex/dhall-menu` working-tree sources
were carried into the integration without rewriting the original worktree. Its
pane now fills the height left below the tab row, and scrolling is excluded from
notch-close gestures. Parser/date/cache checks and a live October 9 fetch passed
(three meals, 604 listed items); the integrated unsigned Release build passed.


The D-hall tab reads today's public W&L Marketplace menu from [NetNutrition](https://netnutrition.cbord.com/nn-prod/WLU). It selects breakfast, lunch or dinner based on Eastern time, lets you switch meals and filter by station, and shows the date and last check time. Hover over a food for its posted serving; open NetNutrition for nutrition and allergens.

It fetches when opened if the saved menu is older than 30 minutes or belongs to another day. While the pane stays open it checks that condition each minute. Refresh fetches immediately. The app retains the last complete menu when fetching fails and labels older dates explicitly. It never treats a missing menu as a closed dining hall. Changes or substitutions at service may differ from the posted menu.

## Source and storage

The parser mirrors the station and menu selectors from the planning vault's `.claude/scripts/netnutrition_marketplace.py`. The app does not read the vault or Today payload, and it needs no agent or scheduled collector. NetNutrition's session is stateful, so meal requests run sequentially in a temporary session.

CFNetwork lost connections to this source on this Mac. The implementation uses `/usr/bin/curl` directly through `Process` on a background task, with fixed HTTPS endpoints and numeric menu IDs parsed from the source. There is no shell or arbitrary command/URL input. Each request has a 20-second limit and a 2 MiB response cap. A private temporary cookie directory is removed after the fetch. The offline menu lives in the app's Application Support directory under `boring.notch/DHall/menu.json`, separate from Today. A signed sandboxed launch remains unverified.

## Checks

```sh
swiftc boringNotch/components/Today/DHallMenu.swift boringNotch/components/Today/DHallStore.swift tests/DHallMenuTests.swift -o /tmp/dhall-tests
/tmp/dhall-tests
# Optional public network check, which also saves the offline menu:
/tmp/dhall-tests --live
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release CODE_SIGNING_ALLOWED=NO build
```

`--dhall-preview-window` renders the actual notch ContentView with D-hall selected. The scroll gesture guard includes this tab so scrolling does not close the notch.

October 8, 2026: parser/date/entity/cache checks and the live fetch passed. All 618 items across three meals matched the independent Python collector, including station and posted serving. The nine existing publisher/bridge tests passed. The first unsigned preview verified meal switching and Daily Dish filtering; final main-based build and installed verification are recorded in `HANDOFF.md`.

The integrated app is installed at `/Applications/Boring Notch.app`. Installed
inspection confirmed the fourth tab opens today's Lunch menu with the correct
selection highlight. Source remains staged/uncommitted.
