import Foundation

enum TodayPayloadError: LocalizedError {
    case unsupportedSchema(Int)
    case tooManyRows
    case invalidText(String)
    case unsafeAction(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version): return "Today schema version \(version) is not supported."
        case .tooManyRows: return "Today accepts at most five ranked rows."
        case .invalidText(let field): return "Today has an invalid \(field) value."
        case .unsafeAction(let label): return "Today action \"\(label)\" is not allowed."
        }
    }
}

struct TodayPayload: Codable, Equatable {
    static let supportedSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date
    let rows: [TodayRow]
    let next: String?
    let protectedTime: String?
    let start: String?
    let anki: TodayAnki?
    let actions: [TodayAction]

    enum CodingKeys: String, CodingKey {
        case schemaVersion, generatedAt, rows, next, protectedTime = "protected", start, anki, actions
    }

    func validated() throws -> TodayPayload {
        guard schemaVersion == Self.supportedSchemaVersion else { throw TodayPayloadError.unsupportedSchema(schemaVersion) }
        guard rows.count <= 5 else { throw TodayPayloadError.tooManyRows }
        for row in rows { try row.validate() }
        guard Set(rows.map(\.id)).count == rows.count else { throw TodayPayloadError.invalidText("duplicate row id") }
        for pair in [("next", next), ("protected", protectedTime), ("start", start)] {
            if let value = pair.1, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw TodayPayloadError.invalidText(pair.0)
            }
        }
        try anki?.validate()
        for action in actions { try action.validate() }
        guard Set(actions.map(\.id)).count == actions.count else { throw TodayPayloadError.invalidText("duplicate action id") }
        return self
    }

    func isStale(at date: Date = Date(), after interval: TimeInterval = 12 * 60 * 60) -> Bool {
        date.timeIntervalSince(generatedAt) > interval
    }
}

struct TodayRow: Codable, Equatable, Identifiable {
    let id: String
    let work: String
    let purpose: String
    let studyMethod: String
    let doneWhen: String
    let time: String
    let whyNow: String
    let basis: TodayBasis

    enum CodingKeys: String, CodingKey {
        case id, work, purpose, studyMethod, doneWhen, time, whyNow, basis
    }

    func validate() throws {
        for pair in [("id", id), ("work", work), ("purpose", purpose), ("studyMethod", studyMethod), ("doneWhen", doneWhen), ("time", time), ("whyNow", whyNow)] {
            let value = pair.1.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value.count <= 500 else { throw TodayPayloadError.invalidText(pair.0) }
        }
    }
}

enum TodayBasis: String, Codable, Equatable { case official = "OFFICIAL", plan = "PLAN", inference = "INFERENCE" }

struct TodayAnki: Codable, Equatable {
    let status: TodayAnkiStatus
    let reviewedToday: Int?
    let newCards: Int?

    func validate() throws {
        switch status {
        case .available:
            guard let reviewedToday, let newCards, reviewedToday >= 0, newCards >= 0 else {
                throw TodayPayloadError.invalidText("anki counts")
            }
        case .unavailable:
            guard reviewedToday == nil, newCards == nil else { throw TodayPayloadError.invalidText("unavailable anki counts") }
        }
    }
}

enum TodayAnkiStatus: String, Codable, Equatable { case available, unavailable }

struct TodayAction: Codable, Equatable, Identifiable {
    let id: String
    let label: String
    let kind: TodayActionKind
    let url: String?

    func validate() throws {
        guard !id.isEmpty, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TodayPayloadError.invalidText("action")
        }
        switch kind {
        case .source:
            guard let url, let parsed = URL(string: url), parsed.scheme == "https", parsed.host != nil, parsed.user == nil, parsed.password == nil else {
                throw TodayPayloadError.unsafeAction(label)
            }
        case .itembank:
            guard url == nil else { throw TodayPayloadError.unsafeAction(label) }
        }
    }
}

enum TodayActionKind: String, Codable, Equatable { case source, itembank }
