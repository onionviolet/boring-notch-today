import AppKit
import Combine
import CoreFoundation
import Darwin
import Foundation

@MainActor
final class TodayStore: ObservableObject {
    enum State: Equatable { case loading, ready(TodayPayload, isStale: Bool), empty, malformed(String) }

    static let shared = TodayStore()
    @Published private(set) var state: State = .loading
    @Published private(set) var bridgeConnection: TodayBridgeConnection = .disconnected
    @Published private(set) var refreshRequestedAt: Date?
    @Published private(set) var refreshIssue: String?
    var refreshPending: Bool { refreshRequestedAt != nil }
    var showingPreviousPlan: Bool { lastGoodPayload != nil && !latestPayloadAccepted }
    @Published private(set) var notice: String?
    @Published private(set) var reminders: [TodayDueReminder] = []
    @Published private(set) var now = Date()
    @Published private(set) var focus: TodayFocusSession?
    @Published var selectedRowID: String?
    private var scheduleTimer: Timer?
    private var started = false
    private var wakeObserver: NSObjectProtocol?
    private var preferencesObserver: NSObjectProtocol?
    private var ledger = TodayReminderLedger()
    private var timer: Timer?
    private var watcher: DispatchSourceFileSystemObject?
    private var watchedURL: URL?
    private var watchedInode: UInt64?
    private var debounceWorkItem: DispatchWorkItem?
    private var lastGoodPayload: TodayPayload?
    private var latestPayloadAccepted = false

    private var payloadIdentity: PayloadIdentity?
    private(set) var payloadDecodeCount = 0
    private let storageDirectory: URL
    private let defaults: UserDefaults
    private let clock: () -> Date

    init(defaults: UserDefaults = .standard, clock: @escaping () -> Date = Date.init, initialPayload: TodayPayload? = nil, directory: URL? = nil) {
        self.storageDirectory = directory ?? Self.directoryURL
        self.defaults = defaults
        self.clock = clock
        now = clock()
        if let initialPayload {
            lastGoodPayload = initialPayload
            latestPayloadAccepted = true
            state = .ready(initialPayload, isStale: initialPayload.isStale(at: now))
        }
        if let data = defaults.data(forKey: "today.reminderLedger"),
           let saved = try? JSONDecoder().decode(TodayReminderLedger.self, from: data) { ledger = saved }
        if let data = defaults.data(forKey: "today.focus"),
           let saved = try? JSONDecoder().decode(TodayFocusSession.self, from: data) { focus = saved }
    }

    deinit {
        timer?.invalidate()
        scheduleTimer?.invalidate()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        if let preferencesObserver { NotificationCenter.default.removeObserver(preferencesObserver) }
        debounceWorkItem?.cancel()
        watcher?.cancel()
    }

    static var directoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("boring.notch/Today", isDirectory: true)
    }
    static var payloadURL: URL { directoryURL.appendingPathComponent("payload.json") }
    static var refreshRequestURL: URL { directoryURL.appendingPathComponent("refresh-request.json") }
    static var bridgeStatusURL: URL { directoryURL.appendingPathComponent("bridge-status.json") }

    private static func rejectSymlinks(_ urls: [URL]) throws {
        for url in urls where (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil {
            throw TodayPayloadError.unsafeAction("storage")
        }
    }

    private var payloadURL: URL { storageDirectory.appendingPathComponent("payload.json") }
    private var bridgeStatusURL: URL { storageDirectory.appendingPathComponent("bridge-status.json") }
    private var refreshRequestURL: URL { storageDirectory.appendingPathComponent("refresh-request.json") }

    // lstat is repeated even on cache hits: identity includes replacement, in-place
    // edits and metadata changes. Never cache acceptance of an unsafe record.
    private struct PayloadIdentity: Equatable {
        let device: Int32
        let inode: UInt64
        let size: Int64
        let modified: timespec
        let changed: timespec
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.device == rhs.device && lhs.inode == rhs.inode && lhs.size == rhs.size
                && lhs.modified.tv_sec == rhs.modified.tv_sec && lhs.modified.tv_nsec == rhs.modified.tv_nsec
                && lhs.changed.tv_sec == rhs.changed.tv_sec && lhs.changed.tv_nsec == rhs.changed.tv_nsec
        }
        init(url: URL) throws {
            var info = stat()
            guard lstat(url.path, &info) == 0,
                  (info.st_mode & S_IFMT) == S_IFREG, info.st_uid == getuid(),
                  info.st_nlink == 1, (info.st_mode & 0o077) == 0,
                  info.st_size >= 0, info.st_size <= 64 * 1024 else {
                throw TodayPayloadError.invalidText("payload file")
            }
            device = info.st_dev; inode = info.st_ino; size = info.st_size
            modified = info.st_mtimespec; changed = info.st_ctimespec
        }
    }

    func start() {
        guard !started else { return }
        started = true
        reload()
        installWatcherIfNeeded()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        preferencesObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: defaults, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reload()
                self?.installWatcherIfNeeded()
            }
        }
    }

    func reload() {
        defer { tick() }
        let previousBridge = bridgeConnection
        let nextBridge = readBridgeStatus()
        if previousBridge != nextBridge { bridgeConnection = nextBridge }
        let requestedAt = try? readRefreshRequestDate()
        if refreshRequestedAt != requestedAt { refreshRequestedAt = requestedAt }
        if requestedAt != nil, refreshIssue != nil { refreshIssue = nil }
        guard FileManager.default.fileExists(atPath: payloadURL.path) else {
            payloadIdentity = nil
            lastGoodPayload = nil
            latestPayloadAccepted = false
            stopFocus()
            if state != .empty { state = .empty }
            return
        }
        do {
            try Self.rejectSymlinks([storageDirectory.deletingLastPathComponent(), storageDirectory, payloadURL])
            let identity = try PayloadIdentity(url: payloadURL)
            if payloadIdentity == identity, lastGoodPayload.map({ $0.generatedAt <= clock().addingTimeInterval(300) }) ?? true {
                if latestPayloadAccepted, !refreshPending, notice != nil { notice = nil }
                return
            }
            let data = try Data(contentsOf: payloadURL)
            // A concurrent replacement must be retried, not accepted under the old identity.
            guard try PayloadIdentity(url: payloadURL) == identity else {
                throw TodayPayloadError.invalidText("payload changed while reading")
            }
            payloadIdentity = identity
            payloadDecodeCount += 1
            let payload = try TodayPayload.decodeValidated(from: data, at: clock())
            latestPayloadAccepted = true
            lastGoodPayload = payload
            if !refreshPending, notice != nil { notice = nil }
            let next = State.ready(payload, isStale: payload.isStale(at: clock()))
            if state != next { state = next }
        } catch {
            if case TodayPayloadError.invalidText("future generatedAt") = error { payloadIdentity = nil }
            latestPayloadAccepted = false
            if notice != "Latest update was rejected." { notice = "Latest update was rejected." }
            if let lastGoodPayload {
                let next = State.ready(lastGoodPayload, isStale: lastGoodPayload.isStale(at: clock()))
                if state != next { state = next }
            } else {
                let next = State.malformed("The local Today payload is invalid.")
                if state != next { state = next }
            }
        }
    }

    func requestRefresh() {
        do {
            try Self.rejectSymlinks([storageDirectory.deletingLastPathComponent(), storageDirectory, refreshRequestURL])
            let files = FileManager.default
            try files.createDirectory(at: storageDirectory, withIntermediateDirectories: true,
                                      attributes: [.posixPermissions: 0o700])
            try files.setAttributes([.posixPermissions: 0o700], ofItemAtPath: storageDirectory.path)

            // Python holds the same lock through match, publish and acknowledgement.
            // Keep slow publisher I/O off the UI thread by declining a busy lock.
            let lockURL = storageDirectory.appendingPathComponent(".refresh-request.lock")
            let fd = open(lockURL.path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard fd >= 0 else { throw TodayPayloadError.unsafeAction("refresh lock") }
            defer { close(fd) }
            var info = stat()
            guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
                  info.st_uid == getuid(), info.st_nlink == 1, (info.st_mode & 0o077) == 0 else {
                throw TodayPayloadError.unsafeAction("refresh lock")
            }
            guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
                if errno == EWOULDBLOCK {
                    refreshRequestedAt = try? readRefreshRequestDate()
                    refreshIssue = refreshPending ? nil : "Refresh is busy. Try again in a moment."
                    return
                }
                throw TodayPayloadError.unsafeAction("refresh lock")
            }

            if let existing = try readRefreshRequestDate() {
                refreshRequestedAt = existing
            } else {
                let instant = clock()
                let body: [String: Any] = [
                    "schemaVersion": 1, "id": UUID().uuidString,
                    "requestedAt": ISO8601DateFormatter().string(from: instant),
                    "source": "Boring Notch Today"
                ]
                let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
                let temporary = storageDirectory.appendingPathComponent(".refresh-\(UUID().uuidString)")
                defer { try? files.removeItem(at: temporary) }
                guard files.createFile(atPath: temporary.path, contents: data,
                                       attributes: [.posixPermissions: 0o600]),
                      rename(temporary.path, refreshRequestURL.path) == 0 else {
                    throw TodayPayloadError.unsafeAction("refresh request")
                }
                refreshRequestedAt = try readRefreshRequestDate()
            }
            refreshIssue = nil
        } catch {
            refreshIssue = "Could not create the local refresh request."
        }
    }

    private func readBridgeStatus() -> TodayBridgeConnection {
        guard FileManager.default.fileExists(atPath: bridgeStatusURL.path) else {
            return .disconnected
        }
        do {
            try Self.rejectSymlinks([storageDirectory.deletingLastPathComponent(), storageDirectory, bridgeStatusURL])
            let values = try bridgeStatusURL.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true, (values.fileSize ?? 0) <= 4 * 1024 else {
                throw TodayPayloadError.invalidText("bridge status")
            }
            return try TodayBridgeStatus.decodeConnection(from: Data(contentsOf: bridgeStatusURL), at: clock())
        } catch {
            return .error
        }
    }

    private func readRefreshRequestDate() throws -> Date? {
        try Self.rejectSymlinks([storageDirectory.deletingLastPathComponent(), storageDirectory, refreshRequestURL])
        let fd = open(refreshRequestURL.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        if fd < 0, errno == ENOENT { return nil }
        guard fd >= 0 else { throw TodayPayloadError.unsafeAction("refresh request") }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_uid == getuid(), info.st_nlink == 1, (info.st_mode & 0o077) == 0 else {
            throw TodayPayloadError.unsafeAction("refresh request")
        }
        let limit = 4 * 1024
        guard info.st_size <= limit, let data = try handle.read(upToCount: limit + 1), data.count <= limit,
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              Set(object.keys) == Set(["schemaVersion", "id", "requestedAt", "source"]),
              let schema = object["schemaVersion"] as? NSNumber,
              CFGetTypeID(schema) != CFBooleanGetTypeID(), String(cString: schema.objCType) != "d",
              schema.intValue == 1, object["source"] as? String == "Boring Notch Today",
              let id = object["id"] as? String, UUID(uuidString: id)?.uuidString.lowercased() == id.lowercased(),
              let timestamp = object["requestedAt"] as? String else { return nil }
        return Self.refreshDate(timestamp)
    }

    private static let refreshTimestamp = #"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?(?:Z|[+-](?:[01][0-9]|2[0-3]):[0-5][0-9])$"#

    private static let refreshDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        formatter.isLenient = false
        return formatter
    }()

    private static func refreshDate(_ timestamp: String) -> Date? {
        guard let match = timestamp.range(of: refreshTimestamp, options: .regularExpression),
              match == timestamp.startIndex..<timestamp.endIndex else { return nil }
        let seconds = timestamp.replacingOccurrences(of: #"\.[0-9]+"#, with: "", options: .regularExpression)
        return refreshDateFormatter.date(from: seconds)
    }

    private var currentPayload: TodayPayload? {
        guard latestPayloadAccepted, case .ready(let payload, _) = state else { return nil }
        return payload
    }

    var upcomingDeadline: TodayDeadline? {
        guard case .ready(_, isStale: false) = state else { return nil }
        return currentPayload.flatMap { TodaySchedule.nextDeadline(payload: $0, at: clock()) }
    }

    var upcomingWork: String? {
        guard let deadline = upcomingDeadline else { return nil }
        return currentPayload?.rows.first(where: { $0.id == deadline.rowID })?.work
    }

    var focusRemaining: String? {
        guard let focus else { return nil }
        let seconds = max(0, Int(ceil(focus.endsAt.timeIntervalSince(now))))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private static func countdownChanged(_ deadlines: [TodayDeadline], from old: Date, to new: Date) -> Bool {
        func bucket(_ due: Date, _ at: Date) -> Int {
            let seconds = due.timeIntervalSince(at)
            return seconds > 0 ? Int(ceil(seconds / 60)) : -1
        }
        for deadline in deadlines {
            if bucket(deadline.dueAt, old) != bucket(deadline.dueAt, new) { return true }
        }
        return false
    }

    private func updatePublishedClock(at instant: Date) {
        guard now != instant else { return }

        // Focus displays seconds, including the tick that crosses its end.
        if let focus, focus.endsAt > min(now, instant) {
            now = instant
            return
        }

        // Deadlines only need a redraw when their countdown minute changes.
        guard latestPayloadAccepted,
              let payload = lastGoodPayload,
              !payload.isStale(at: instant),
              let deadlines = payload.deadlines else { return }
        if Self.countdownChanged(deadlines, from: now, to: instant) {
            now = instant
        }
    }

    func tick() {
        defer { scheduleNextTick() }
        let instant = clock()
        if let payload = lastGoodPayload, case .ready = state {
            let next = State.ready(payload, isStale: payload.isStale(at: instant))
            if state != next { state = next }
        }
        updatePublishedClock(at: instant)
        let now = instant // semantic scheduling never relies on the publication gate
        let quiet = TodayQuietHours(enabled: defaults.bool(forKey: "today.quiet.enabled"),
            startMinute: defaults.object(forKey: "today.quiet.start") as? Int ?? 1320,
            endMinute: defaults.object(forKey: "today.quiet.end") as? Int ?? 480,
            allowRequiredDeadlines: defaults.bool(forKey: "today.quiet.allowRequired"))
        guard let payload = currentPayload else { if !reminders.isEmpty { reminders = [] }; return }
        if let focus, !payload.rows.contains(where: { $0.id == focus.rowID }) { stopFocus() }
        ledger.prune(at: now)
        let due = TodaySchedule.due(payload: payload, at: now, ledger: ledger, quiet: quiet)
        // Keep a displayed banner until dismissed; remove it when its schedule is removed or changed.
        let valid = Set((payload.deadlines ?? []).flatMap { deadline -> [String] in
            guard let row = payload.rows.first(where: { $0.id == deadline.rowID }) else { return [] }
            return deadline.reminders.map { TodayDueReminder(deadline: deadline, reminder: $0, row: row).id }
        })
        var nextReminders = reminders.filter { valid.contains($0.id) && !payload.isStale(at: now)
            && now <= $0.deadline.dueAt.addingTimeInterval(3600)
            && !(quiet.contains(now) && !($0.deadline.required && quiet.allowRequiredDeadlines)) }
        var changed = false
        for item in due where !nextReminders.contains(where: { $0.id == item.id }) {
            nextReminders.append(item)
            ledger.delivered[item.id] = now
            ledger.snoozed.removeValue(forKey: item.id)
            changed = true
        }
        // Refresh titles/details on an existing banner without replaying its reminder.
        nextReminders = nextReminders.map { item in
            let row = payload.rows.first(where: { $0.id == item.deadline.rowID }) ?? item.row
            return TodayDueReminder(deadline: item.deadline, reminder: item.reminder, row: row)
        }
        if reminders != nextReminders { reminders = nextReminders }
        if changed { saveLedger() }
    }

    func dismissReminders() { reminders = [] }

    func snoozeReminders() {
        let retry = clock().addingTimeInterval(600)
        for item in reminders { ledger.snoozed[item.id] = retry }
        reminders = []
        saveLedger()
        scheduleNextTick()
    }

    private func saveLedger() {
        if let data = try? JSONEncoder().encode(ledger) { defaults.set(data, forKey: "today.reminderLedger") }
    }

    func startFocus(row: TodayRow) {
        now = clock()
        focus = TodayFocusSession(rowID: row.id, work: row.work, endsAt: clock().addingTimeInterval(TimeInterval(TodayPresentationPreferences(defaults: defaults).focusMinutes * 60)))
        if let data = try? JSONEncoder().encode(focus) { defaults.set(data, forKey: "today.focus") }
        scheduleNextTick()
    }

    func stopFocus() {
        guard focus != nil else { return }
        focus = nil
        defaults.removeObject(forKey: "today.focus")
        scheduleNextTick()
    }

    // Only focus needs a one-second clock. Other transitions have explicit dates;
    // the existing file poll and wake observer remain independent recovery paths.
    func nextTickInterval(at instant: Date) -> TimeInterval {
        if let focus, focus.endsAt > instant { return min(1, focus.endsAt.timeIntervalSince(instant)) }
        var interval: TimeInterval = 60
        func consider(_ date: Date) {
            let delay = date.timeIntervalSince(instant)
            if delay >= 0 { interval = min(interval, delay + 0.01) }
        }
        if let payload = lastGoodPayload {
            consider(payload.generatedAt.addingTimeInterval(12 * 3600))
        }
        if let payload = currentPayload, !payload.isStale(at: instant) {
            let deadlines = payload.deadlines ?? []
            if !deadlines.isEmpty, defaults.bool(forKey: "today.quiet.enabled"),
               let minute = Calendar.current.dateInterval(of: .minute, for: instant) {
                consider(minute.end) // quiet-hour changes, including midnight and DST
            }
            for deadline in deadlines {
                let remaining = deadline.dueAt.timeIntervalSince(instant)
                if remaining > 0 {
                    let remainder = remaining.truncatingRemainder(dividingBy: 60)
                    consider(instant.addingTimeInterval(remainder > 0 ? remainder : min(60, remaining)))
                }
                consider(deadline.dueAt.addingTimeInterval(3600))
                for reminder in deadline.reminders {
                    consider(reminder.at)
                }
            }
            for retry in ledger.snoozed.values { consider(retry) }
        }
        return max(0.05, interval)
    }

    private func scheduleNextTick() {
        guard started else { return }
        scheduleTimer?.invalidate()
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: nextTickInterval(at: clock()), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        scheduleTimer?.tolerance = 0.01
    }

    private func nearestExistingWatchURL() -> URL? {
        var candidate = storageDirectory
        while candidate.path != "/" {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        return nil
    }

    private func installWatcherIfNeeded(force: Bool = false) {
        guard let target = nearestExistingWatchURL() else { return }
        var info = stat()
        let inode = lstat(target.path, &info) == 0 ? info.st_ino : nil
        if !force, watcher != nil, watchedURL == target, watchedInode == inode { return }
        watcher?.cancel()
        watcher = nil
        watchedURL = nil
        let descriptor = open(target.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self, weak source] in
            let flags = source?.data ?? []
            Task { @MainActor in
                self?.scheduleReload(rebind: flags.contains(.rename) || flags.contains(.delete))
            }
        }
        source.setCancelHandler { close(descriptor) }
        watcher = source
        watchedURL = target
        watchedInode = inode
        source.resume()
    }

    private func scheduleReload(rebind: Bool) {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.reload()
                let nowWatchingToday = self.watchedURL == self.storageDirectory
                self.installWatcherIfNeeded(force: rebind || !nowWatchingToday)
            }
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }
}


struct TodayFocusSession: Codable, Equatable {
    let rowID: String
    let work: String
    let endsAt: Date
}
