import Foundation

struct DHallMenu: Codable {
    struct Meal: Codable, Identifiable {
        var id: Int
        var name: String
        var items: [Item]
    }
    struct Item: Codable, Identifiable {
        var id: Int
        var station: String
        var name: String
        var serving: String
    }
    var date: String
    var checkedAt: Date
    var meals: [Meal]

    static func day(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// NetNutrition returns JSON panels containing HTML, rather than a menu JSON API.
// These selectors mirror the vault's netnutrition_marketplace.py collector.
enum DHallParser {
    struct MenuReference { var id: Int; var name: String }
    static func matches(_ pattern: String, _ text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (0..<match.numberOfRanges).map { index in
                let range = match.range(at: index)
                return range.location == NSNotFound ? "" : ns.substring(with: range)
            }
        }
    }

    static func text(_ html: String) -> String {
        var value = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for match in matches("&#(x[0-9a-f]+|[0-9]+);", value) {
            let digits = match[1]
            let number = digits.lowercased().hasPrefix("x") ? UInt32(digits.dropFirst(), radix: 16) : UInt32(digits)
            if let number, let scalar = UnicodeScalar(number) { value = value.replacingOccurrences(of: match[0], with: String(scalar)) }
        }
        for (entity, replacement) in [("&nbsp;", " "), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&")] {
            value = value.replacingOccurrences(of: entity, with: replacement)
        }
        return value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func menus(_ html: String, day: String) -> [MenuReference] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: day) else { return [] }
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        let wanted = formatter.string(from: date)
        var currentDate = ""
        var result: [MenuReference] = []
        for token in matches("<header\\b[^>]*>(.*?)</header>|<a\\b[^>]*menuListSelectMenu\\((-?[0-9]+)\\)[^>]*>(.*?)</a>", html) {
            if !token[1].isEmpty { currentDate = text(token[1]) }
            else if currentDate == wanted, let id = Int(token[2]) {
                result.append(MenuReference(id: id, name: text(token[3])))
            }
        }
        return result
    }

    static func items(_ html: String) -> [DHallMenu.Item] {
        var station = "Other"
        var result: [DHallMenu.Item] = []
        for row in matches("<tr\\b([^>]*)>(.*?)</tr>", html) {
            let cells = matches("<td\\b[^>]*>(.*?)</td>", row[2]).map { text($0[1]) }
            if row[1].contains("cbo_nn_itemGroupRow"), let first = cells.first { station = first }
            else if row[1].contains("cbo_nn_itemPrimaryRow") || row[1].contains("cbo_nn_itemAlternateRow") {
                guard cells.count >= 3,
                      let call = matches("getItemNutritionLabelOnClick\\([^,]+,\\s*(-?[0-9]+)\\)", row[2]).first,
                      let id = Int(call[1]), !cells[1].isEmpty else { continue }
                result.append(.init(id: id, station: station, name: cells[1], serving: cells[2]))
            }
        }
        return result
    }
}
