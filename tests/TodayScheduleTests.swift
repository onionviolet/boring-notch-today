import Foundation

@main struct TodayScheduleTests {
    static func main() throws {
        let now = ISO8601DateFormatter().date(from: "2026-10-12T23:00:00Z")!
        let row = TodayRow(id: "lab", work: "Lab", purpose: "Practice", studyMethod: "Build", doneWhen: "Receipt", time: "25 min", whyNow: "Deadline", basis: .official)
        let source = TodayAction(id: "site", label: "Submit", kind: .source, url: "https://example.edu/submit")
        let prep = TodayReminder(id: "prep", at: now.addingTimeInterval(-3600), kind: .preparation)
        let check = TodayReminder(id: "check", at: now, kind: .checkpoint)
        let deadline = TodayDeadline(id: "lab-due", rowID: row.id, dueAt: now.addingTimeInterval(3600), required: true, actionID: source.id, reminders: [prep, check])
        var payload = TodayPayload(schemaVersion: 2, generatedAt: now, rows: [row], next: nil, protectedTime: nil, start: nil, anki: nil, actions: [source], deadlines: [deadline])
        _ = try payload.validated(at: now)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let roundTrip = try TodayPayload.decodeValidated(from: encoder.encode(payload), at: now)
        precondition(roundTrip == payload)
        // Sleep/restart catch-up returns every missed reminder in one batch, with exact boundary behavior.
        var ledger = TodayReminderLedger()
        let due = TodaySchedule.due(payload: payload, at: now, ledger: ledger, quiet: .init())
        precondition(due.count == 2)
        precondition(TodaySchedule.due(payload: payload, at: now.addingTimeInterval(-1), ledger: ledger, quiet: .init()).count == 1)
        for item in due { ledger.delivered[item.id] = now }
        let restored = try JSONDecoder().decode(TodayReminderLedger.self, from: JSONEncoder().encode(ledger))
        precondition(TodaySchedule.due(payload: payload, at: now, ledger: restored, quiet: .init()).isEmpty)
        ledger.snoozed[due[0].id] = now.addingTimeInterval(600)
        precondition(TodaySchedule.due(payload: payload, at: now.addingTimeInterval(599), ledger: ledger, quiet: .init()).isEmpty)
        precondition(TodaySchedule.due(payload: payload, at: now.addingTimeInterval(600), ledger: ledger, quiet: .init()).count == 1)
        // Quiet periods wrap midnight in the user's timezone; optional work cannot bypass them.
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/New_York")!
        var quiet = TodayQuietHours(enabled: true, startMinute: 18 * 60, endMinute: 8 * 60, allowRequiredDeadlines: false)
        precondition(quiet.contains(now, calendar: calendar))
        precondition(TodaySchedule.due(payload: payload, at: now, ledger: .init(), quiet: quiet, calendar: calendar).isEmpty)
        quiet.allowRequiredDeadlines = true
        precondition(TodaySchedule.due(payload: payload, at: now, ledger: .init(), quiet: quiet, calendar: calendar).count == 2)
        let optional = TodayDeadline(id: "optional", rowID: row.id, dueAt: now.addingTimeInterval(60), required: false, actionID: source.id, reminders: [check])
        payload.deadlines = [optional, deadline]
        precondition(TodaySchedule.nextDeadline(payload: payload, at: now) == deadline)
        precondition(TodaySchedule.due(payload: payload, at: now, ledger: .init(), quiet: quiet, calendar: calendar).count == 2)
        // Changed due dates get new reminder identities; removed deadlines cannot fire.
        let changed = TodayDeadline(id: deadline.id, rowID: row.id, dueAt: now.addingTimeInterval(7200), required: true, actionID: source.id, reminders: [prep, check])
        payload.deadlines = [changed]
        precondition(TodaySchedule.due(payload: payload, at: now, ledger: restored, quiet: .init()).count == 2)
        payload.deadlines = []
        precondition(TodaySchedule.due(payload: payload, at: now, ledger: .init(), quiet: .init()).isEmpty)
        payload.deadlines = [deadline]
        precondition(TodaySchedule.due(payload: payload, at: deadline.dueAt.addingTimeInterval(3601), ledger: .init(), quiet: .init()).isEmpty)
        precondition(TodaySchedule.due(payload: payload, at: now.addingTimeInterval(13 * 3600), ledger: .init(), quiet: .init()).isEmpty)
        precondition(TodaySchedule.nextDeadline(payload: payload, at: now.addingTimeInterval(13 * 3600)) == nil)
        precondition(TodaySchedule.countdown(to: now.addingTimeInterval(60), at: now) == "1m left")
        precondition(TodaySchedule.countdown(to: now, at: now) == "Deadline passed")
        // Strict v2 reader rejects unknown scheduling inputs and v1 extensions.
        var object = try JSONSerialization.jsonObject(with: encoder.encode(payload)) as! [String: Any]
        object["schemaVersion"] = 1
        precondition((try? TodayPayload.decodeValidated(from: JSONSerialization.data(withJSONObject: object), at: now)) == nil)
        object["schemaVersion"] = 2; object["deadlines"] = NSNull()
        precondition((try? TodayPayload.decodeValidated(from: JSONSerialization.data(withJSONObject: object), at: now)) == nil)
        print("TodayScheduleTests passed: catch-up, restart, snooze, quiet hours, changed/removed/stale deadlines, countdown and schema")
    }
}
