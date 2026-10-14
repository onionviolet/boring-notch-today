import Foundation
import Combine

@MainActor
final class DHallStore: ObservableObject {
    static let shared = DHallStore()
    static let source = URL(string: "https://netnutrition.cbord.com/nn-prod/WLU")!
    @Published private(set) var menu: DHallMenu?
    @Published private(set) var refreshing = false
    @Published private(set) var notice: String?
    private let cache = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("boring.notch/DHall/menu.json")

    init() {
        if let data = try? Data(contentsOf: cache), data.count < 1_048_576 {
            menu = try? JSONDecoder().decode(DHallMenu.self, from: data)
        }
    }

    func refreshIfNeeded() async {
        if menu?.date != DHallMenu.day() || Date().timeIntervalSince(menu?.checkedAt ?? .distantPast) > 1800 {
            await refresh()
        }
    }

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        let day = DHallMenu.day()
        do {
            let meals = try await Task.detached(priority: .utility) {
                try DHallClient.fetch(day: day)
            }.value
            // Don't publish a yesterday snapshot as today's menu across midnight.
            guard day == DHallMenu.day() else { throw MenuError.dayChanged }
            let updated = DHallMenu(date: day, checkedAt: Date(), meals: meals)
            menu = updated
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
    static func fetch(day: String) throws -> [DHallMenu.Meal] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("boring-dhall-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let cookies = directory.appendingPathComponent("cookies")
        FileManager.default.createFile(atPath: cookies.path, contents: Data(), attributes: [.posixPermissions: 0o600])
        _ = try request(path: "", cookies: cookies)
        let list = try panel(path: "/Unit/SelectUnitFromUnitsList", body: "unitOid=7", id: "menuPanel", cookies: cookies)
        let references = DHallParser.menus(list, day: day)
        guard !references.isEmpty else { throw DHallStore.MenuError.notPosted }
        return try references.map { reference in
            let html = try panel(path: "/Menu/SelectMenu", body: "menuOid=\(reference.id)", id: "itemPanel", cookies: cookies)
            let items = DHallParser.items(html)
            guard !items.isEmpty else { throw DHallStore.MenuError.changed }
            return DHallMenu.Meal(id: reference.id, name: reference.name, items: items)
        }
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
