import Foundation

@main
struct DHallMenuTests {
    @MainActor static func main() async throws {
        let list = """
        <header class='card-title'>Thursday, October 8, 2026</header>
        <a onclick='NetNutrition.UI.menuListSelectMenu(42);'>Lunch</a>
        <header class='card-title'>Friday, October 9, 2026</header>
        <a onclick='NetNutrition.UI.menuListSelectMenu(43);'>Dinner</a>
        """
        let refs = DHallParser.menus(list, day: "2026-10-08")
        precondition(refs.count == 1 && refs[0].id == 42 && refs[0].name == "Lunch")
        precondition(DHallParser.menus(list, day: "2026-10-10").isEmpty)
        precondition(DHallParser.menus("Login required", day: "2026-10-08").isEmpty)
        let html = """
        <tr class='cbo_nn_itemGroupRow'><td>Pizza &amp; Pasta</td></tr>
        <tr class='cbo_nn_itemPrimaryRow'><td>Checkbox text</td><td><a onclick='NetNutrition.UI.getItemNutritionLabelOnClick(event,-322);'>Chef&#39;s Pasta</a></td><td>1 cup</td></tr>
        <tr class='cbo_nn_itemAlternateRow'><td></td><td>Unrecognized item</td><td></td></tr>
        """
        let items = DHallParser.items(html)
        precondition(items.count == 1 && items[0].id == -322)
        precondition(items[0].station == "Pizza & Pasta" && items[0].name == "Chef's Pasta" && items[0].serving == "1 cup")
        precondition(DHallParser.text("Cr&#xE8;me &amp; <b>rice</b>") == "Crème & rice")
        let midnight = ISO8601DateFormatter().date(from: "2026-10-09T03:59:00Z")!
        precondition(DHallMenu.day(midnight) == "2026-10-08")
        precondition(DHallMenu.day(midnight.addingTimeInterval(60)) == "2026-10-09")
        let snapshot = DHallMenu(date: "2026-10-08", checkedAt: midnight, meals: [.init(id: 42, name: "Lunch", items: items)])
        let decoded = try JSONDecoder().decode(DHallMenu.self, from: JSONEncoder().encode(snapshot))
        precondition(decoded.meals[0].items[0].name == "Chef's Pasta")
        print("D-hall parser, missing-date, entity, Eastern midnight and cache roundtrip checks passed")
        if CommandLine.arguments.contains("--live") {
            let store = DHallStore()
            await store.refresh()
            precondition(store.notice == nil, store.notice ?? "")
            guard let menu = store.menu else { fatalError("No menu fetched") }
            precondition(menu.date == DHallMenu.day() && !menu.meals.isEmpty)
            print("Live menu fetch: \(menu.date), \(menu.meals.count) meals, \(menu.meals.reduce(0) { $0 + $1.items.count }) items")
        }
    }
}
