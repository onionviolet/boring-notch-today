# D-hall: menu notes and UI proposals (2026-10-27)

Proposals, not accepted decisions. Evidence: the W&L menu feed (Oct 27 to Nov 2), NetNutrition exports (Oct 27 to 30), the vault Food_Log (September), and the current source.

## Menu findings

| Code | Finding | Evidence |
|---|---|---|
| F1 | Steak-type dinners on 3 of 7 days: Carne Asada (Thu 10/29), Santa Maria Steak (Fri 10/30), Philly Cheesesteak (Sat 10/31). Roast beef Wed 10/28 and Sun 11/1 dinner, Beef Barbacoa Mon 11/2 lunch. | feed |
| F2 | Weekends have no breakfast. Lunch is brunch (Omelet MTO at the Pizza & Pasta station; Sat shrimp and grits). | feed 10/31, 11/1 |
| F3 | Lunch and dinner repeat a lot. Pizza & Pasta and Soup are identical at both meals every day. Global Kitchen ran the same Irish lunch Wed to Fri and the same Mexico dinner Sun and Mon. | feed |
| F4 | Grilled Chicken Breast is at Lex Grill every lunch and dinner. It is the reliable protein fallback, not news. | feed |
| F5 | A meal lists about 230 items. Only about 60 are hot line or deli (`access: queued` in the collector); the rest are salad bar, cereal, drinks, coffee add-ins and condiments. | NetNutrition 10/28 |
| F6 | NetNutrition had 4 days posted while the official feed had 7. The app's 7-day horizon therefore gets about 4. The feed is simpler JSON (no session) but has no item IDs or servings. | both sources, 10/27 |
| F7 | Thu 10/29 dinner is a themed Mexican night across stations (with Mexican Coca-Cola and candy). Inference: a themed event. | feed |

## UI findings

| Code | Finding | Consequence |
|---|---|---|
| U1 | The panel is 640x300 (`sizing/matters.swift`). After the header, the key strip and the pickers, the list shows roughly 10 rows of about 230. | Hot food can need several screens of scrolling. |
| U2 | One item per row, in source order, with self-serve stations mixed in. | Wasted width; condiments and drinks dilute the list. |
| U3 | The station is chosen from a dropdown. Station headers scroll away. | You lose track of where you are. |
| U4 | Days switch only through a dropdown. | No quick next/previous. |
| U5 | `--dhall-preview-window` in `docs/DHall.md` no longer exists. Only `--today-preview-window` remains in `boringNotchApp.swift`. | UI changes cannot be checked visually without adding it back. |
| U6 | Fetching is view-scoped. A closed-notch glance would have no fresh data unless the tab was opened. | Any "bar" feature needs app-level refresh first (see battery F6). |

## Proposals

Scroll and layout, ranked:

1. **O1 Hot line first.** Default to the queued stations (Lex Grill, Global Kitchen, Daily Dish, Pizza & Pasta, Soup, Deli). Collapse self-serve stations into one tappable "Salad bar, drinks & more" row. Reuse the collector's QUEUED/SELF_SERVE split.
2. **O2 Inline items per station.** Write a station's items as one wrapped line ("Hamburger · Grilled Chicken Breast · Crinkle Cut Fries"), so the hot line fits in about 8 lines without scrolling.
3. **O3 Station chips with pinned headers.** Swap the dropdown for a horizontal chip row that jumps with `ScrollViewReader`, and pin section headers with `LazyVStack(pinnedViews:)`.
4. **O4 Staples dimmed, new items plain.** Gray out items that appear in most saved meals (F3, F4). Keep "Same as lunch" as one line for stations that repeat.
5. **O5 Day chevrons.** Add ‹ › around the day label. Avoid horizontal swipes, because the notch already uses horizontal gestures for media.

Pictures:

- **O6 Icons, not photos.** Use an SF Symbol per station (flame for the grill, globe for Global Kitchen, a pizza wedge) and food emoji on key items (🥩 🍤 🐟). Offline, free, and never the wrong dish.
- Photos are not recommended. NetNutrition has none in the exported data (assumption: not rechecked in the raw HTML). A web image search would add network calls and copyright and wrong-dish risk.

Closed notch ("bar"):

- **O7 Key-item peek before a meal.** Example: "🥩 Santa Maria Steak · Dinner" in the closed notch for a window before the meal. Needs (a) app-level refresh instead of view-scoped refresh (U6), (b) Marketplace meal hours, which neither source provides, and (c) a priority below Today deadlines and notifications. Make it a transient peek, not a persistent pill.
- **R1 Keep D-hall out of the Today payload and rows.** The vault owns Today, and the app never mixes sources.
- **O8 Menu bar alternative.** If "bar" meant the macOS menu bar, a status item with today's key items is a separate, simpler surface.

Data:

- **O9 Feed as lookahead fallback.** Use the official feed for days 5 to 7 that NetNutrition hasn't posted (F6). Label them as feed-sourced, since they have no servings.
- **O10 App-level refresh.** Recording history without opening the tab is the same change as U6, with bounded backoff per battery F6.
