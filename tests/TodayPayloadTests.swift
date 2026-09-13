import Foundation

@main struct TodayPayloadTests {
    static func expectInvalid(_ payload: TodayPayload) {
        do { _ = try payload.validated(); fatalError("expected invalid payload") } catch {}
    }
    static func main() {
        let row = TodayRow(id: "one", work: "Work", purpose: "Purpose", studyMethod: "Method", doneWhen: "Done", time: "5 min", whyNow: "Now", basis: .official)
        let base = TodayPayload(schemaVersion: 1, generatedAt: Date(), rows: [row], next: nil, protectedTime: nil, start: nil, anki: TodayAnki(status: .unavailable, reviewedToday: nil, newCards: nil), actions: [])
        precondition((try? base.validated()) != nil)
        precondition(!base.isStale(at: base.generatedAt.addingTimeInterval(60)))
        precondition(base.isStale(at: base.generatedAt.addingTimeInterval(13 * 60 * 60)))
        expectInvalid(TodayPayload(schemaVersion: 2, generatedAt: Date(), rows: [], next: nil, protectedTime: nil, start: nil, anki: nil, actions: []))
        expectInvalid(TodayPayload(schemaVersion: 1, generatedAt: Date(), rows: Array(repeating: row, count: 6), next: nil, protectedTime: nil, start: nil, anki: nil, actions: []))
        expectInvalid(TodayPayload(schemaVersion: 1, generatedAt: Date(), rows: [row, row], next: nil, protectedTime: nil, start: nil, anki: nil, actions: []))
        expectInvalid(TodayPayload(schemaVersion: 1, generatedAt: Date(), rows: [], next: nil, protectedTime: nil, start: nil, anki: TodayAnki(status: .available, reviewedToday: -1, newCards: 0), actions: []))
        expectInvalid(TodayPayload(schemaVersion: 1, generatedAt: Date(), rows: [], next: nil, protectedTime: nil, start: nil, anki: TodayAnki(status: .unavailable, reviewedToday: 0, newCards: nil), actions: []))
        expectInvalid(TodayPayload(schemaVersion: 1, generatedAt: Date(), rows: [], next: nil, protectedTime: nil, start: nil, anki: nil, actions: [TodayAction(id: "bad", label: "Bad", kind: .source, url: "file:///tmp/no")]))
        precondition((try? TodayPayload(schemaVersion: 1, generatedAt: Date(), rows: [], next: nil, protectedTime: nil, start: nil, anki: nil, actions: [TodayAction(id: "itembank", label: "Itembank", kind: .itembank, url: nil)]).validated()) != nil)
        print("TodayPayloadTests passed")
    }
}
