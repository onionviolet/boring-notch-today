import AppKit
import Combine
import Darwin
import Foundation

@MainActor
final class TodayStore: ObservableObject {
    enum State: Equatable { case loading, ready(TodayPayload, isStale: Bool), empty, malformed(String) }

    static let shared = TodayStore()
    @Published private(set) var state: State = .loading
    @Published private(set) var bridgeConnection: TodayBridgeConnection = .disconnected
    @Published private(set) var refreshPending = false
    @Published private(set) var notice: String?
    @Published private(set) var reminders: [TodayDueReminder] = []
    @Published private(set) var now = Date()
    @Published private(set) var focus: TodayFocusSession?
    @Published var selectedRowID: String?
    private var scheduleTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var ledger = TodayReminderLedger()
    private var timer: Timer?
    private var watcher: DispatchSourceFileSystemObject?
    private var watchedURL: URL?
    private var watchedInode: UInt64?
    private var debounceWorkItem: DispatchWorkItem?
    private var lastGoodPayload: TodayPayload?
    private var latestPayloadAccepted = false
    private var lastRefreshRequestAt: Date?

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
        reload()
        installWatcherIfNeeded()
        guard timer == nil else { return }
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reload() }
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
        let previousPending = refreshPending
        let nextBridge = readBridgeStatus()
        let nextPending = readRefreshPending()
        if previousBridge != nextBridge { bridgeConnection = nextBridge }
        if previousPending != nextPending { refreshPending = nextPending }
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
        let now = clock()
        guard lastRefreshRequestAt.map({ now.timeIntervalSince($0) >= 2 }) ?? true else {
            notice = "A refresh is already pending."
            return
        }
        let requestID = UUID().uuidString
        let body: [String: Any] = [
            "schemaVersion": 1,
            "id": requestID,
            "requestedAt": ISO8601DateFormatter().string(from: now),
            "source": "Boring Notch Today"
        ]
        do {
            try Self.rejectSymlinks([storageDirectory.deletingLastPathComponent(), storageDirectory, refreshRequestURL])
            if FileManager.default.fileExists(atPath: storageDirectory.path) {
                let values = try storageDirectory.resourceValues(forKeys: [.isSymbolicLinkKey])
                guard values.isSymbolicLink != true else { throw TodayPayloadError.unsafeAction("storage") }
            }
            try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: storageDirectory.path)
            let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            try data.write(to: refreshRequestURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: refreshRequestURL.path)
            lastRefreshRequestAt = now
            refreshPending = true
            notice = "Refresh requested, waiting for an active agent."
        } catch {
            notice = "Could not create the local refresh request."
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

    private func readRefreshPending() -> Bool {
        guard FileManager.default.fileExists(atPath: refreshRequestURL.path) else {
            return false
        }
        do {
            try Self.rejectSymlinks([storageDirectory.deletingLastPathComponent(), storageDirectory, refreshRequestURL])
            let values = try refreshRequestURL.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true, (values.fileSize ?? 0) <= 4 * 1024,
                  let object = try JSONSerialization.jsonObject(with: Data(contentsOf: refreshRequestURL)) as? [String: Any],
                  Set(object.keys) == Set(["schemaVersion", "id", "requestedAt", "source"]),
                  object["schemaVersion"] as? Int == 1,
                  object["source"] as? String == "Boring Notch Today",
                  let requestID = object["id"] as? String, UUID(uuidString: requestID) != nil,
                  let requestedAt = object["requestedAt"] as? String,
                  ISO8601DateFormatter().date(from: requestedAt) != nil else {
                throw TodayPayloadError.invalidText("refresh request")
            }
            return true
        } catch {
            return false
        }
    }

    private var currentPayload: TodayPayload? {
        guard latestPayloadAccepted, case .ready(let payload, _) = state else { return nil }
        return payload
    }

    var upcomingDeadline: TodayDeadline? {
        currentPayload.flatMap { TodaySchedule.nextDeadline(payload: $0, at: now) }
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

    func tick() {
        let instant = clock()
        if let payload = lastGoodPayload, case .ready = state {
            let next = State.ready(payload, isStale: payload.isStale(at: instant))
            if state != next { state = next }
        }
        let focusTime = focus.map { $0.endsAt > now || $0.endsAt > instant } ?? false
        let deadlineTime = latestPayloadAccepted && (lastGoodPayload.map {
            !$0.isStale(at: instant) && !($0.deadlines ?? []).isEmpty
        } ?? false)
        let timeContent = focusTime || deadlineTime
        if timeContent, now != instant { now = instant }
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
        for item in reminders { ledger.snoozed[item.id] = now.addingTimeInterval(600) }
        reminders = []
        saveLedger()
    }

    private func saveLedger() {
        if let data = try? JSONEncoder().encode(ledger) { defaults.set(data, forKey: "today.reminderLedger") }
    }

    func startFocus(row: TodayRow) {
        now = clock()
        focus = TodayFocusSession(rowID: row.id, work: row.work, endsAt: clock().addingTimeInterval(TimeInterval(TodayPresentationPreferences(defaults: defaults).focusMinutes * 60)))
        if let data = try? JSONEncoder().encode(focus) { defaults.set(data, forKey: "today.focus") }
    }

    func stopFocus() {
        guard focus != nil else { return }
        focus = nil
        defaults.removeObject(forKey: "today.focus")
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
