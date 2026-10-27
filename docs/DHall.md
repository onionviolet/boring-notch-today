# D-hall menu tab

**Restored 2026-10-09:** D-hall is the fourth tab after Home, Shelf and Today in
the upstream integration. The existing `codex/dhall-menu` working-tree sources
were carried into the integration without rewriting the original worktree. Its
pane now fills the height left below the tab row, and scrolling is excluded from
notch-close gestures. Parser/date/cache checks and a live October 9 fetch passed
(three meals, 604 listed items); the integrated unsigned Release build passed.


The D-hall tab reads today's public W&L Marketplace menu from [NetNutrition](https://netnutrition.cbord.com/nn-prod/WLU). It selects breakfast, lunch or dinner based on Eastern time, lets you switch meals and filter by station, and shows the date and last check time. Hover over a food for its posted serving; open NetNutrition for nutrition and allergens.

It fetches when opened if the saved menu is older than 30 minutes or belongs to another day. While the pane stays open it checks that condition each minute. Refresh fetches immediately. The app retains the last complete menu when fetching fails and labels older dates explicitly. It never treats a missing menu as a closed dining hall. Changes or substitutions at service may differ from the posted menu.

## History, lookahead and highlights

- **Lookahead:** while the pane is open, today is re-read every 30 minutes and the next 7 days every 6 hours; failed fetches retry after 5 minutes. Later days are best effort. Today's menu is required, so a day with no posted menu (break) also skips the week.
- **History:** past days are only what was saved while they were today or upcoming. Nothing is backfilled. A same-date fetch replaces the saved copy; days older than 60 days are trimmed. Fetching is view-scoped, so days the tab never opened on are never recorded.
- **Search** covers the saved week and history, upcoming first.
- **Highlights:** an item is key when its exact name is starred or a watched word matches at a word start (default words include steak, cheesesteak, carne asada, roast beef, barbacoa, salmon, shrimp). Condiment, topping, dressing, spread and addition stations are skipped, as are topping bars and names ending in sauce, seasoning, dressing, gravy or marinade unless they read as a dish ("with", "w/" or "&"). So A-1 Steak Sauce and Beef Gravy are skipped, while Shrimp & Andouille Sausage Gravy is kept. Key items show in yellow, in a strip above the meal picker, and mark days ★ in the picker. Watch or unwatch a word from search; with an empty search, the watched words are listed for removal. Stars live in `dhall.favorites`, words in `dhall.keywords` (UserDefaults).

### Keyword audit, 2026-10-27

Corpus: the official W&L menu feed (Oct 27 to Nov 2, the only days it serves; no history) and NetNutrition (Oct 27 to 30 posted), plus September dishes in the vault Food_Log. The first default list caught only Santa Maria Steak and Popcorn Shrimp. It missed Philly Cheesesteak (no word start at "steak"), Carne Asada, Roasted Beef, Tuscan Beef Roast, Beef Barbacoa and Shrimp & Andouille Sausage Gravy, and the feed's "Burger & Steak Sandwich Topping Bar" (a recurring Lex Grill line) would have been a false hit. Defaults and rules were widened accordingly; `tests/DHallMenuTests.swift` pins these names. Ground beef and gravies stay unflagged. One week is a small sample: brunch, carving or holiday menus may need more words.

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

`--dhall-preview-window` (restored 2026-10-27) renders `DHallView` alone in a dark 640x300 window, like `--today-preview-window`. The scroll gesture guard includes this tab so scrolling does not close the notch.

**Layout (2026-10-27):** hot-line stations come first, as pinned headers with wrapped item chips. Station buttons jump within the list. Self-serve stations (salad bar, drinks, condiments, allergen-friendly) fold behind one "Salad bar, drinks & more" row. Items rank by greatness: starred 3, watched word 2, staple -1 (on at least 60% of saved meals, once 6 or more meals are saved). Stations holding key items move up, and the day picker shows a ★ count. ‹ › step through saved days.

October 8, 2026: parser/date/entity/cache checks and the live fetch passed. All 618 items across three meals matched the independent Python collector, including station and posted serving. The nine existing publisher/bridge tests passed. The first unsigned preview verified meal switching and Daily Dish filtering; final main-based build and installed verification are recorded in `HANDOFF.md`.

The integrated app is installed at `/Applications/Boring Notch.app`. Installed
inspection confirmed the fourth tab opens today's Lunch menu with the correct
selection highlight. Source remains staged/uncommitted.
