import Foundation
import CoreFoundation

/// O8's closed whitelist. Values retain the existing O6/O7 string encodings.
enum TodayPresetKey: String, CaseIterable, Codable {
    case duration = "today.focus.duration"
    case presentation = "today.presentation"
    case density = "today.density"
    case prominence = "today.reminder.prominence"
    case visibility = "today.glance.visibility"
    case label = "today.glance.label"
    case width = "today.glance.width"
    case horizon = "today.glance.horizon"

    var allowed: [String] {
        switch self {
        case .duration: return ["15", "25", "45", "60"]
        case .presentation: return ["all", "required"]
        case .density: return ["current", "compact"]
        case .prominence: return ["standard", "subtle"]
        case .visibility: return ["automatic", "hidden"]
        case .label: return ["compact", "full"]
        case .width: return ["compact", "balanced"]
        case .horizon: return ["all", "hour", "sixHours", "day"]
        }
    }
    var fallback: String { self == .duration ? "25" : allowed[0] }
    var title: String {
        switch self {
        case .duration: return "New focus sessions"
        case .presentation: return "Work shown"
        case .density: return "Text density"
        case .prominence: return "In-scroll reminders"
        case .visibility: return "Today glance"
        case .label: return "Glance label"
        case .width: return "Side width limit"
        case .horizon: return "Upcoming deadlines"
        }
    }
    func display(_ value: String) -> String {
        if self == .duration { return "\(value) min" }
        if self == .horizon { return ["all": "All", "hour": "1h", "sixHours": "6h", "day": "24h"][value] ?? "All" }
        if self == .presentation && value == "required" { return "Required-only" }
        return value.capitalized
    }
    func effective(_ raw: Any?) -> String {
        guard let value = raw as? String, allowed.contains(value) else { return fallback }
        return value
    }
}

enum TodayPresetName: String, CaseIterable, Identifiable {
    case study = "Study", quiet = "Quiet", media = "Media", custom = "Custom"
    var id: String { rawValue }
    var builtIn: TodayPresetValues? {
        switch self {
        case .study: return .init(["25", "required", "compact", "standard", "automatic", "compact", "compact", "day"])
        case .quiet: return .init(["25", "all", "compact", "subtle", "hidden", "compact", "compact", "all"])
        case .media: return .init(["25", "all", "current", "standard", "hidden", "compact", "compact", "all"])
        case .custom: return nil
        }
    }
}

struct TodayPresetValues: Equatable {
    private let values: [String]
    init?(_ values: [String]) {
        guard values.count == TodayPresetKey.allCases.count,
              zip(TodayPresetKey.allCases, values).allSatisfy({ $0.allowed.contains($1) }) else { return nil }
        self.values = values
    }
    subscript(_ key: TodayPresetKey) -> String { values[TodayPresetKey.allCases.firstIndex(of: key)!] }
}

struct TodayPresetChange: Equatable, Identifiable {
    let key: TodayPresetKey
    let before: String
    let after: String
    var id: TodayPresetKey { key }
    var description: String { "\(key.title): \(key.display(before)) → \(key.display(after))" }
}

/// Reads persistent-domain state, excluding registered defaults. No startup writes.
struct TodayPresetStore {
    static let customKey = "today.presets.custom"
    static let restoreKey = "today.presets.restore"
    private static let maximumBytes = 4096
    let defaults: UserDefaults
    let domain: String

    init(defaults: UserDefaults = .standard, domain: String = Bundle.main.bundleIdentifier!) {
        self.defaults = defaults
        self.domain = domain
    }
    private var persistent: [String: Any] { defaults.persistentDomain(forName: domain) ?? [:] }
    var current: TodayPresetValues {
        let raw = persistent
        return TodayPresetValues(TodayPresetKey.allCases.map { $0.effective(raw[$0.rawValue]) })!
    }
    private struct Entry: Codable {
        let key: TodayPresetKey
        let value: String
        // nil means absent, never an unvalidated property-list value.
        let previous: String?
    }
    private struct Record: Codable { let version: Int; let entries: [Entry] }

    // Validate whole records before decoding or selecting any writable key.
    // Entry arrays make duplicate whitelist keys observable and rejectable.
    private func record(_ storageKey: String, restore: Bool) -> Record? {
        guard let data = persistent[storageKey] as? Data, data.count <= Self.maximumBytes,
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              Set(root.keys) == ["version", "entries"],
              let version = root["version"] as? NSNumber,
              CFGetTypeID(version) != CFBooleanGetTypeID(), version.intValue == 1, version.doubleValue == 1,
              let entries = root["entries"] as? [[String: Any]],
              !entries.isEmpty, entries.count <= 8, restore || entries.count == 8 else { return nil }
        var seen = Set<TodayPresetKey>()
        for entry in entries {
            let keys = Set(entry.keys)
            guard keys == ["key", "value"] || (restore && keys == ["key", "value", "previous"]),
                  let rawKey = entry["key"] as? String, let key = TodayPresetKey(rawValue: rawKey),
                  seen.insert(key).inserted,
                  let value = entry["value"] as? String, key.allowed.contains(value) else { return nil }
            if let previous = entry["previous"] {
                guard restore, let value = previous as? String, key.allowed.contains(value) else { return nil }
            }
        }
        return try? JSONDecoder().decode(Record.self, from: data)
    }
    private func save(_ entries: [Entry], to key: String) {
        // Closed entries bound the encoded data well below maximumBytes.
        if let data = try? JSONEncoder().encode(Record(version: 1, entries: entries)), data.count <= Self.maximumBytes {
            defaults.set(data, forKey: key)
        }
    }
    var custom: TodayPresetValues? {
        guard let record = record(Self.customKey, restore: false) else { return nil }
        return TodayPresetValues(TodayPresetKey.allCases.map { key in record.entries.first { $0.key == key }!.value })
    }
    var customStatus: String {
        custom != nil ? "Custom saved locally." : (persistent[Self.customKey] == nil ? "No Custom preset saved." : "Saved Custom is invalid or unsupported. Save Custom to replace it.")
    }
    var canRestore: Bool { record(Self.restoreKey, restore: true) != nil }
    var restoreInvalid: Bool { persistent[Self.restoreKey] != nil && !canRestore }
    func target(_ name: TodayPresetName) -> TodayPresetValues? { name.builtIn ?? custom }
    func preview(_ name: TodayPresetName) -> [TodayPresetChange] {
        guard let target = target(name) else { return [] }
        return changes(from: current, to: target)
    }
    private func changes(from before: TodayPresetValues, to after: TodayPresetValues) -> [TodayPresetChange] {
        TodayPresetKey.allCases.compactMap { key in
            before[key] == after[key] ? nil : TodayPresetChange(key: key, before: before[key], after: after[key])
        }
    }
    func saveCustom() {
        let values = current
        save(TodayPresetKey.allCases.map { Entry(key: $0, value: values[$0], previous: nil) }, to: Self.customKey)
    }
    @discardableResult func apply(_ name: TodayPresetName) -> [TodayPresetChange] {
        guard let target = target(name) else { return [] }
        let raw = persistent // Fresh immediately pre-Apply state, never preview's snapshot.
        let before = TodayPresetValues(TodayPresetKey.allCases.map { $0.effective(raw[$0.rawValue]) })!
        let delta = changes(from: before, to: target)
        guard !delta.isEmpty else { return [] } // Keep existing undo on a no-op.
        let entries = delta.map { change in
            Entry(key: change.key, value: change.after,
                  previous: raw[change.key.rawValue] == nil ? nil : change.before)
        }
        save(entries, to: Self.restoreKey)
        for change in delta { defaults.set(change.after, forKey: change.key.rawValue) }
        return delta
    }
    struct RestoreResult {
        let restored: [TodayPresetKey]
        let retained: [TodayPresetKey]
        var message: String {
            let kept = retained.map(\.title).joined(separator: ", ")
            return "Restored \(restored.count) settings." + (retained.isEmpty ? "" : " Kept later edits: \(kept).")
        }
    }
    @discardableResult func restore() -> RestoreResult? {
        guard let record = record(Self.restoreKey, restore: true) else { return nil }
        let raw = persistent
        var restored: [TodayPresetKey] = [], retained: [TodayPresetKey] = []
        for entry in record.entries {
            // Strict raw match: absence/invalid values are subsequent-edit conflicts.
            guard let stored = raw[entry.key.rawValue] as? String, stored == entry.value else {
                retained.append(entry.key); continue
            }
            if let previous = entry.previous { defaults.set(previous, forKey: entry.key.rawValue) }
            else { defaults.removeObject(forKey: entry.key.rawValue) }
            restored.append(entry.key)
        }
        defaults.removeObject(forKey: Self.restoreKey)
        return RestoreResult(restored: restored, retained: retained)
    }
}
