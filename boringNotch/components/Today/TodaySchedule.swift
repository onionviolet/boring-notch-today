import Foundation

// Scheduling uses only validated timestamps. The ledger is local presentation state.
struct TodayReminderLedger: Codable {
    var delivered: [String: Date] = [:]
    var snoozed: [String: Date] = [:]

    mutating func prune(at now: Date) {
        delivered = delivered.filter { now.timeIntervalSince($0.value) < 30 * 86400 }
        if delivered.count > 512 {
            delivered = Dictionary(uniqueKeysWithValues: delivered.sorted { $0.value > $1.value }.prefix(512).map { ($0.key, $0.value) })
        }
        snoozed = snoozed.filter { now.timeIntervalSince($0.value) < 86400 }
    }
}

struct TodayQuietHours {
    var enabled = false
    var startMinute = 22 * 60
    var endMinute = 8 * 60
    var allowRequiredDeadlines = false

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled else { return false }
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        if startMinute == endMinute { return true }
        return startMinute < endMinute ? (startMinute..<endMinute).contains(minute) : minute >= startMinute || minute < endMinute
    }
}

struct TodayDueReminder: Equatable, Identifiable {
    let deadline: TodayDeadline
    let reminder: TodayReminder
    let row: TodayRow
    var id: String {
        // Length-delimited JSON avoids collisions in publisher-supplied identifiers.
        let parts = [deadline.id, deadline.rowID, String(deadline.dueAt.timeIntervalSince1970),
                     String(deadline.required), deadline.actionID ?? "", reminder.id,
                     String(reminder.at.timeIntervalSince1970), reminder.kind.rawValue]
        return String(data: try! JSONEncoder().encode(parts), encoding: .utf8)!
    }
}

enum TodaySchedule {
    static func due(payload: TodayPayload, at now: Date, ledger: TodayReminderLedger,
                    quiet: TodayQuietHours, calendar: Calendar = .current) -> [TodayDueReminder] {
        guard !payload.isStale(at: now) else { return [] }
        return (payload.deadlines ?? []).flatMap { deadline -> [TodayDueReminder] in
            guard let row = payload.rows.first(where: { $0.id == deadline.rowID }),
                  now <= deadline.dueAt.addingTimeInterval(3600),
                  !(quiet.contains(now, calendar: calendar) && !(deadline.required && quiet.allowRequiredDeadlines)) else { return [] }
            return deadline.reminders.compactMap { reminder in
                let item = TodayDueReminder(deadline: deadline, reminder: reminder, row: row)
                if let snooze = ledger.snoozed[item.id] {
                    return snooze <= now ? item : nil
                }
                return reminder.at <= now && ledger.delivered[item.id] == nil ? item : nil
            }
        }.sorted {
            if $0.deadline.required != $1.deadline.required { return $0.deadline.required }
            if $0.deadline.dueAt != $1.deadline.dueAt { return $0.deadline.dueAt < $1.deadline.dueAt }
            return $0.id < $1.id
        }
    }

    static func nextDeadline(payload: TodayPayload, at now: Date) -> TodayDeadline? {
        guard !payload.isStale(at: now) else { return nil }
        return (payload.deadlines ?? []).filter { $0.dueAt > now }.sorted {
            if $0.required != $1.required { return $0.required }
            return $0.dueAt < $1.dueAt
        }.first
    }

    static func countdown(to deadline: Date, at now: Date) -> String {
        let seconds = deadline.timeIntervalSince(now)
        guard seconds > 0 else { return "Deadline passed" }
        let minutes = max(1, Int(ceil(seconds / 60)))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m left" : "\(minutes)m left"
    }
}
