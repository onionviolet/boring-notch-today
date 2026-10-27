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
        func item(_ name: String, _ station: String = "Lex Grill") -> DHallMenu.Item { .init(id: 1, station: station, name: name, serving: "") }
        let words = ["steak", "short rib"]
        precondition(DHallStore.matchesKeyword(item("Grilled Flank Steak"), words))
        precondition(DHallStore.matchesKeyword(item("Braised Short Ribs"), words))
        precondition(DHallStore.matchesKeyword(item("Steak Fajitas with Chimichurri Sauce"), words))
        precondition(DHallStore.matchesKeyword(item("Philly Steak & Cheese"), words))
        precondition(!DHallStore.matchesKeyword(item("A-1 Steak Sauce", "Condiments"), words))
        precondition(!DHallStore.matchesKeyword(item("A-1 Steak Sauce"), words))
        precondition(!DHallStore.matchesKeyword(item("Steak Strips", "Daily Dish Toppings"), words))
        precondition(!DHallStore.matchesKeyword(item("Caribbean Rice"), ["rib"]))
        // Real Oct 27-Nov 2 Marketplace names against the shipped defaults.
        let defaults = DHallStore.defaultKeywords
        for hit in ["Santa Maria Steak", "Philly Cheesesteak", "Carne Asada", "Roasted Beef", "Tuscan Beef Roast",
                    "Beef Barbacoa", "Popcorn Shrimp", "Shrimp & Andouille Sausage Gravy", "Citrus Marinated Flank Steak"] {
            precondition(DHallStore.matchesKeyword(item(hit), defaults), hit)
        }
        for miss in ["Burger & Steak Sandwich Topping Bar", "Beef Gravy", "Taco-Seasoned Ground Beef", "Grilled Chicken Breast"] {
            precondition(!DHallStore.matchesKeyword(item(miss), defaults), miss)
        }
        precondition(!DHallStore.matchesKeyword(item("A-1 Steak Sauce", "Condiments"), defaults))
        let chicken = item("Grilled Chicken Breast"), special = item("Santa Maria Steak")
        let week = (0..<3).map { day in
            DHallMenu(date: DHallMenu.shifted("2026-10-27", by: day)!, checkedAt: midnight, meals: [
                .init(id: 1, name: "Lunch", items: [chicken]), .init(id: 2, name: "Dinner", items: day == 2 ? [chicken, special] : [chicken])])
        }
        precondition(DHallStore.staples(in: week) == ["grilled chicken breast"])
        precondition(DHallStore.staples(in: Array(week.prefix(2))).isEmpty)
        precondition(DHallStore.isSelfServe("Salad Bar - Dressings") && !DHallStore.isSelfServe("Lex Grill") && !DHallStore.isSelfServe("Deli - Cheese & Proteins"))
        precondition(DHallStore.emoji(special) == "🥩" && DHallStore.emoji(item("Popcorn Shrimp")) == "🦐")
        let today = DHallMenu.day()
        let old = DHallMenu(date: DHallMenu.shifted(today, by: -61)!, checkedAt: midnight, meals: [])
        let kept = DHallMenu(date: DHallMenu.shifted(today, by: -3)!, checkedAt: midnight, meals: [])
        let fresh = DHallMenu(date: kept.date, checkedAt: midnight.addingTimeInterval(1), meals: [])
        let merged = DHallStore.merged([old, kept], with: [fresh])
        precondition(merged.count == 1 && merged[0].checkedAt == fresh.checkedAt)
        print("D-hall parser, missing-date, entity, Eastern midnight, cache roundtrip, keyword and history merge checks passed")
        if CommandLine.arguments.contains("--live") {
            let store = DHallStore()
            await store.refresh()
            precondition(store.notice == nil, store.notice ?? "")
            guard let menu = store.menu(for: DHallMenu.day()) else { fatalError("No menu fetched") }
            precondition(menu.date == DHallMenu.day() && !menu.meals.isEmpty)
            print("Live menu fetch: \(menu.date), \(menu.meals.count) meals, \(menu.meals.reduce(0) { $0 + $1.items.count }) items")
        }
    }
}
