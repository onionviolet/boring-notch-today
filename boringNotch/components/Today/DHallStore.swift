import Foundation
import Combine

@MainActor
final class DHallStore: ObservableObject {
    static let shared = DHallStore()
    static let horizon = 7
    static let historyDays = 60
    static let todayInterval: TimeInterval = 1800
    static let futureInterval: TimeInterval = 6 * 3600
    static let retryInterval: TimeInterval = 300
    private static let favoritesKey = "dhall.favorites"
    private static let keywordsKey = "dhall.keywords"
    /// Seeded from the Oct 27-Nov 2 menus and the September food log; carne asada and roast beef rarely say "steak".
    static let defaultKeywords = ["steak", "cheesesteak", "carne asada", "barbacoa", "bulgogi", "roast beef", "roasted beef", "beef roast",
                                  "beef tips", "prime rib", "short rib", "brisket", "pork belly", "salmon", "shrimp", "crab", "lobster",
                                  "scallop", "lamb", "wings", "carving"]
    static let source = URL(string: "https://netnutrition.cbord.com/nn-prod/WLU")!
    @Published private(set) var menus: [DHallMenu] = [] { didSet { staples = Self.staples(in: menus) } }
    /// Lowercased names that show up at most saved meals, e.g. Grilled Chicken Breast.
    private(set) var staples: Set<String> = []
    @Published private(set) var refreshing = false
    @Published private(set) var notice: String?
    /// Lowercased item names the user starred.
    @Published private(set) var favorites: Set<String> = Set(UserDefaults.standard.stringArray(forKey: DHallStore.favoritesKey) ?? [])
    /// Lowercased words that mark an item as key wherever it appears, e.g. "steak" for "Grilled Flank Steak".
    @Published private(set) var keywords: [String] = UserDefaults.standard.stringArray(forKey: DHallStore.keywordsKey) ?? DHallStore.defaultKeywords
    private var lastAttempt = Date.distantPast
    private var lastFutureFetch = Date.distantPast
    private let cache = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("boring.notch/DHall/menu.json")

    init() {
        if let data = try? Data(contentsOf: cache), data.count < 16_777_216 {
            let decoder = JSONDecoder()
            if let saved = try? decoder.decode([DHallMenu].self, from: data) { menus = Self.merged(saved, with: []) }
            else if let single = try? decoder.decode(DHallMenu.self, from: data) { menus = [single] }
        }
        // didSet doesn't run for assignments inside init.
        staples = Self.staples(in: menus)
    }

    static func key(_ name: String) -> String { name.lowercased() }
    func isFavorite(_ name: String) -> Bool { favorites.contains(Self.key(name)) }
    func toggleFavorite(_ name: String) {
        let key = Self.key(name)
        if favorites.contains(key) { favorites.remove(key) } else { favorites.insert(key) }
        UserDefaults.standard.set(favorites.sorted(), forKey: Self.favoritesKey)
    }
    func isWatched(_ word: String) -> Bool { keywords.contains(Self.key(word)) }
    func toggleKeyword(_ word: String) {
        let key = Self.key(word.trimmingCharacters(in: .whitespaces))
        guard !key.isEmpty else { return }
        if let index = keywords.firstIndex(of: key) { keywords.remove(at: index) } else { keywords.append(key) }
        UserDefaults.standard.set(keywords, forKey: Self.keywordsKey)
    }

    /// Keywords skip condiment-like stations, topping bars and bare sauces so "steak" doesn't flag A-1 Steak Sauce.
    static func matchesKeyword(_ item: DHallMenu.Item, _ keywords: [String]) -> Bool {
        let station = item.station.lowercased(), name = item.name.lowercased()
        if ["condiment", "topping", "dressing", "spread", "addition"].contains(where: station.contains) { return false }
        if name.contains("topping bar") { return false }
        let dish = name.contains(" with ") || name.contains("w/") || name.contains("&")
        if !dish, ["sauce", "seasoning", "dressing", "gravy", "marinade"].contains(where: name.hasSuffix) { return false }
        return keywords.contains { word in
            name.range(of: "\\b" + NSRegularExpression.escapedPattern(for: word), options: .regularExpression) != nil
        }
    }
    func isKey(_ item: DHallMenu.Item) -> Bool { score(item) >= 2 }
    func isStaple(_ item: DHallMenu.Item) -> Bool { staples.contains(Self.key(item.name)) }

    /// Greatness: starred 3, watched word 2, staple -1. Ties keep posted order.
    func score(_ item: DHallMenu.Item) -> Int {
        let name = Self.key(item.name)
        if favorites.contains(name) { return 3 }
        if Self.matchesKeyword(item, keywords) { return 2 }
        return staples.contains(name) ? -1 : 0
    }
    func ranked(_ items: [DHallMenu.Item]) -> [DHallMenu.Item] {
        items.enumerated().sorted { a, b in
            let (sa, sb) = (score(a.element), score(b.element))
            return sa != sb ? sa > sb : a.offset < b.offset
        }.map(\.element)
    }

    /// Needs at least 6 saved meals so a short cache doesn't call everything a staple.
    static func staples(in menus: [DHallMenu]) -> Set<String> {
        let meals = menus.flatMap(\.meals)
        guard meals.count >= 6 else { return [] }
        var seen: [String: Int] = [:]
        for meal in meals { for name in Set(meal.items.map { key($0.name) }) { seen[name, default: 0] += 1 } }
        let threshold = Int((Double(meals.count) * 0.6).rounded(.up))
        return Set(seen.filter { $0.value >= threshold }.keys)
    }

    /// A food emoji for keyword items; nil for plain or starred-only items.
    static func emoji(_ item: DHallMenu.Item) -> String? {
        let name = item.name.lowercased()
        let table: [(String, [String])] = [
            ("🦐", ["shrimp"]), ("🦀", ["crab"]), ("🦞", ["lobster"]), ("🐟", ["salmon", "scallop"]),
            ("🍗", ["wings"]), ("🥓", ["pork belly"]), ("🍖", ["lamb", "short rib", "prime rib", "brisket"]),
            ("🥩", ["steak", "asada", "barbacoa", "bulgogi", "beef", "carving"]),
        ]
        return table.first { $0.1.contains(where: name.contains) }?.0
    }

    /// Self-serve lines (salad bar, drinks, condiments) fold behind one row; the hot line shows first.
    static func isSelfServe(_ station: String) -> Bool {
        let name = station.lowercased()
        return ["salad", "fruit", "yogurt", "topping", "cereal", "fountain", "beverage", "condiment", "coffee",
                "milk", "spread", "allergen", "ice cream"].contains(where: name.contains)
    }
    /// Key items for a day, one entry per name, best first and then in meal order.
    func keyItems(_ menu: DHallMenu) -> [(meal: String, item: DHallMenu.Item)] {
        var seen: Set<String> = []
        let found = menu.meals.flatMap { meal in
            meal.items.filter { isKey($0) && seen.insert(Self.key($0.name)).inserted }.map { (meal: meal.name, item: $0) }
        }
        return found.enumerated().sorted { a, b in
            let (sa, sb) = (score(a.element.item), score(b.element.item))
            return sa != sb ? sa > sb : a.offset < b.offset
        }.map(\.element)
    }

    /// Newer menus replace same-date ones; older days are kept as history and trimmed after `historyDays`.
    static func merged(_ old: [DHallMenu], with new: [DHallMenu]) -> [DHallMenu] {
        var byDay: [String: DHallMenu] = [:]
        for menu in old + new { byDay[menu.date] = menu }
        let cutoff = DHallMenu.shifted(DHallMenu.day(), by: -historyDays) ?? ""
        return byDay.values.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    func menu(for day: String) -> DHallMenu? { menus.first { $0.date == day } }

    func refreshIfNeeded() async {
        let now = Date()
        guard now.timeIntervalSince(lastAttempt) > Self.retryInterval else { return }
        let today = menu(for: DHallMenu.day())
        let todayDue = today == nil || now.timeIntervalSince(today?.checkedAt ?? .distantPast) > Self.todayInterval
        let futureDue = now.timeIntervalSince(lastFutureFetch) > Self.futureInterval
        if todayDue || futureDue { await refresh(includeFuture: futureDue) }
    }

    /// `includeFuture` fetches the coming week; routine refreshes only re-read today.
    func refresh(includeFuture: Bool = true) async {
        guard !refreshing else { return }
        refreshing = true
        lastAttempt = Date()
        defer { refreshing = false }
        let day = DHallMenu.day()
        do {
            let days = DHallMenu.upcomingDays(from: day, count: includeFuture ? DHallStore.horizon : 1)
            let fetched = try await Task.detached(priority: .utility) {
                try DHallClient.fetch(days: days)
            }.value
            // Don't publish a yesterday snapshot as today's menu across midnight.
            guard day == DHallMenu.day() else { throw MenuError.dayChanged }
            if includeFuture { lastFutureFetch = Date() }
            let updated = Self.merged(menus, with: fetched)
            menus = updated
            notice = nil
            do {
                try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(updated).write(to: cache, options: .atomic)
            } catch { notice = "Menu loaded; couldn't save an offline copy." }
        } catch {
            notice = (error as? MenuError)?.description ?? "Couldn't refresh: \(error.localizedDescription)"
        }
    }

    fileprivate enum MenuError: Error {
        case notPosted, changed, dayChanged
        var description: String {
            switch self {
            case .notPosted: return "No menu posted for today yet. Try NetNutrition."
            case .changed: return "The menu source couldn't be read. Try NetNutrition."
            case .dayChanged: return "The date changed while loading. Refresh for today's menu."
            }
        }
    }
}

// CFNetwork loses the connection to this source on the development Mac; the
// system curl route matches the working public collector. No shell is involved.
private enum DHallClient {
    /// Today's menu is required; later days are best effort and skipped when unposted or unreadable.
    static func fetch(days: [String]) throws -> [DHallMenu] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("boring-dhall-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let cookies = directory.appendingPathComponent("cookies")
        FileManager.default.createFile(atPath: cookies.path, contents: Data(), attributes: [.posixPermissions: 0o600])
        _ = try request(path: "", cookies: cookies)
        let list = try panel(path: "/Unit/SelectUnitFromUnitsList", body: "unitOid=7", id: "menuPanel", cookies: cookies)
        var result: [DHallMenu] = []
        for (index, day) in days.enumerated() {
            do {
                let references = DHallParser.menus(list, day: day)
                guard !references.isEmpty else { throw DHallStore.MenuError.notPosted }
                let meals = try references.map { reference in
                    let html = try panel(path: "/Menu/SelectMenu", body: "menuOid=\(reference.id)", id: "itemPanel", cookies: cookies)
                    let items = DHallParser.items(html)
                    guard !items.isEmpty else { throw DHallStore.MenuError.changed }
                    return DHallMenu.Meal(id: reference.id, name: reference.name, items: items)
                }
                result.append(DHallMenu(date: day, checkedAt: Date(), meals: meals))
            } catch where index > 0 {
                continue
            }
        }
        return result
    }

    static func request(path: String, body: String? = nil, cookies: URL) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        var arguments = ["--silent", "--show-error", "--fail", "--location", "--max-redirs", "5",
                         "--max-time", "20", "--max-filesize", "2097152", "--proto", "=https", "--proto-redir", "=https",
                         "--cookie", cookies.path, "--cookie-jar", cookies.path]
        if let body { arguments += ["--data", body] }
        arguments.append("https://netnutrition.cbord.com/nn-prod/WLU" + path)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, data.count < 2_097_152 else { throw DHallStore.MenuError.changed }
        return data
    }

    static func panel(path: String, body: String, id: String, cookies: URL) throws -> String {
        let data = try request(path: path, body: body, cookies: cookies)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let panels = object["panels"] as? [[String: Any]],
              let panel = panels.first(where: { $0["id"] as? String == id }),
              let html = panel["html"] as? String else { throw DHallStore.MenuError.changed }
        return html
    }
}
