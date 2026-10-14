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


// Local display choices only. Unknown persisted values use the shipped defaults.
struct TodayGlancePreferences: Equatable {
    enum Visibility: String, CaseIterable { case automatic, hidden }
    enum Label: String, CaseIterable { case compact, full }
    enum Width: String, CaseIterable {
        case compact, balanced
        var cap: CGFloat { self == .compact ? 56 : 80 }
    }
    enum Horizon: String, CaseIterable {
        case hour, sixHours, day, all
        var seconds: TimeInterval? {
            switch self {
            case .hour: return 3600
            case .sixHours: return 21600
            case .day: return 86400
            case .all: return nil
            }
        }
    }
    let visibility: Visibility
    let label: Label
    let width: Width
    let horizon: Horizon

    init(visibility: String, label: String, width: String, horizon: String) {
        self.visibility = Visibility(rawValue: visibility) ?? .automatic
        self.label = Label(rawValue: label) ?? .compact
        self.width = Width(rawValue: width) ?? .compact
        self.horizon = Horizon(rawValue: horizon) ?? .all
    }

    enum Activity { case reminder, focus, deadline }
    func activity(reminder: Bool, focus: Bool, dueAt: Date?, at now: Date,
                  music: Bool, blocked: Bool) -> Activity? {
        guard visibility == .automatic, !blocked else { return nil }
        if reminder { return .reminder }
        if focus { return .focus }
        if !music, let dueAt, includes(dueAt, at: now) { return .deadline }
        return nil
    }
    func includes(_ dueAt: Date, at now: Date) -> Bool {
        let remaining = dueAt.timeIntervalSince(now)
        return remaining > 0 && (horizon.seconds.map { remaining <= $0 } ?? true)
    }
    func displayTitle(_ title: String) -> String {
        guard label == .compact, title.count > 8 else { return title }
        return String(title.prefix(8)) + "…"
    }
}

struct TodayGlanceGeometry: Equatable {
    // Caps include the shaped row's external corner padding on each side.
    let leftWidth: CGFloat
    let rightWidth: CGFloat
    let outerPadding: CGFloat
    init(leftTextWidth: CGFloat, rightTextWidth: CGFloat, cap: CGFloat, outerPadding: CGFloat) {
        self.outerPadding = outerPadding
        func wing(_ text: CGFloat) -> CGFloat {
            text > 0 ? min(max(0, cap - outerPadding), ceil(text) + 4) : 0
        }
        leftWidth = wing(leftTextWidth)
        rightWidth = wing(rightTextWidth)
    }
    var centerOffset: CGFloat { (rightWidth - leftWidth) / 2 }
    func visibleWidth(notchWidth: CGFloat) -> CGFloat {
        notchWidth + leftWidth + rightWidth + 2 * outerPadding
    }
}

struct TodayGlancePresentation: Equatable {
    let rowID: String
    let title: String
    let label: String
    let status: String
    let detail: String
    let isReminder: Bool
    let geometry: TodayGlanceGeometry

    static func countdown(to end: Date, at now: Date) -> String {
        let remaining = end.timeIntervalSince(now)
        guard remaining > 0 else { return "Done" }
        let minutes = max(1, Int(ceil(min(remaining / 60, 1_440_000))))
        if minutes < 60 { return "\(minutes)m" }
        if minutes < 1440 { return "\(Int(ceil(Double(minutes) / 60)))h" }
        let days = Int(ceil(Double(minutes) / 1440))
        return days > 999 ? "999d+" : "\(days)d"
    }
}


/// Local display choices. Reading invalid/absent values falls back without rewriting state.
struct TodayPresentationPreferences: Equatable {
    static let durations = [15, 25, 45, 60]
    let focusMinutes: Int
    let requiredOnly: Bool
    let compact: Bool
    let subtleReminders: Bool

    init(duration: String = "25", presentation: String = "all", density: String = "current", prominence: String = "standard") {
        let minutes = Int(duration) ?? 25
        focusMinutes = Self.durations.contains(minutes) ? minutes : 25
        requiredOnly = presentation == "required"
        compact = density == "compact"
        subtleReminders = prominence == "subtle"
    }

    init(defaults: UserDefaults) {
        self.init(duration: defaults.object(forKey: "today.focus.duration") as? String ?? "25",
                  presentation: defaults.object(forKey: "today.presentation") as? String ?? "all",
                  density: defaults.object(forKey: "today.density") as? String ?? "current",
                  prominence: defaults.object(forKey: "today.reminder.prominence") as? String ?? "standard")
    }

    var focusActionLabel: String { "Focus for \(focusMinutes) minutes" }

    func rows(in payload: TodayPayload, retained: Set<String>) -> [TodayRow] {
        payload.rows.filter { row in
            let deadlines = (payload.deadlines ?? []).filter { $0.rowID == row.id }
            return !requiredOnly || deadlines.isEmpty || deadlines.contains(where: \.required) || retained.contains(row.id)
        }
    }

    func deadlines(for rowID: String, in payload: TodayPayload, retainedRows: Set<String>, reminderIDs: Set<String>) -> [TodayDeadline] {
        (payload.deadlines ?? []).filter {
            $0.rowID == rowID && (!requiredOnly || $0.required || retainedRows.contains(rowID) || reminderIDs.contains($0.id))
        }
    }
}
