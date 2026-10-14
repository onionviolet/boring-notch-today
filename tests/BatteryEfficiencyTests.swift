import AVFoundation
import AppKit
import Combine
import Foundation

@MainActor final class DelayedCalendar: CalendarService {
    var queries: [(Date, CheckedContinuation<[EventModel], Never>)] = []
    override func events(from: Date, to: Date, calendars: [String]) async -> [EventModel] {
        await withCheckedContinuation { queries.append((from, $0)) }
    }
}

final class FakeWaveform: AudioCaptureLevelsConsumer {}

@main struct BatteryEfficiencyTests {
    @MainActor static func waitFor(_ predicate: () -> Bool) async {
        for _ in 0..<1000 { if predicate() { return }; await Task.yield() }
        preconditionFailure("Async check timed out")
    }
    static func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("bn-efficiency-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let suite = "bn-efficiency-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        var instant = Date(timeIntervalSince1970: 1_792_000_000)
        let formatter = ISO8601DateFormatter()
        func payload(deadlines: Bool = false) throws -> Data {
            var body: [String: Any] = ["schemaVersion": 2, "generatedAt": formatter.string(from: instant),
                "rows": [["id":"a", "work":"Study", "purpose":"Learn", "studyMethod":"Read", "doneWhen":"Understand", "time":"25m", "whyNow":"Due", "basis":"PLAN"]],
                "next":"Later", "protected":"Rest", "start":"Read", "anki":["status":"unavailable"], "actions":[]]
            if deadlines { body["deadlines"] = [["id":"d", "rowID":"a", "dueAt":formatter.string(from: instant.addingTimeInterval(1200)), "required":true,
                "reminders":[["id":"r", "at":formatter.string(from: instant.addingTimeInterval(10)), "kind":"preparation"]]]] }
            return try JSONSerialization.data(withJSONObject: body)
        }
        let url = directory.appendingPathComponent("payload.json")
        try write(payload(), to: url)
        let store = TodayStore(defaults: defaults, clock: { instant }, directory: directory)
        store.reload()
        var publications = 0
        let subscription = store.objectWillChange.sink { publications += 1 }
        for _ in 0..<60 { instant += 1; store.tick(); store.reload() }
        precondition(publications == 0 && store.payloadDecodeCount == 1)
        print("F1/F2: 60 idle ticks/reloads: 0 publications, 1 total plan decode")
        for _ in 0..<12 {
            let status: [String: Any] = ["schemaVersion":1,"state":"connected","updatedAt":formatter.string(from: instant)]
            try write(JSONSerialization.data(withJSONObject: status), to: directory.appendingPathComponent("bridge-status.json"))
            store.reload()
            instant += 5
        }
        precondition(store.payloadDecodeCount == 1 && store.bridgeConnection == .connected)
        instant += 16; store.reload(); precondition(store.bridgeConnection == .stale)
        try write(Data("{}".utf8), to: url); store.reload()
        let rejectedCount = store.payloadDecodeCount
        for _ in 0..<10 { store.reload() }
        precondition(store.payloadDecodeCount == rejectedCount && store.notice == "Latest update was rejected.")
        guard case .ready = store.state else { fatalError("Last good cards lost") }
        try write(payload(deadlines: true), to: url); store.reload()
        precondition(store.payloadDecodeCount == rejectedCount + 1 && store.notice == nil)
        instant += 9; store.tick(); precondition(store.reminders.isEmpty)
        instant += 1; store.tick(); precondition(store.reminders.count == 1)
        let duePublications = publications
        store.tick(); precondition(publications == duePublications)
        store.snoozeReminders(); instant += 599; store.tick(); precondition(store.reminders.isEmpty)
        instant += 1; store.tick(); precondition(store.reminders.count == 1)
        defaults.set(true, forKey: "today.quiet.enabled")
        defaults.set(0, forKey: "today.quiet.start"); defaults.set(0, forKey: "today.quiet.end")
        store.tick(); precondition(store.reminders.isEmpty)
        defaults.set(false, forKey: "today.quiet.enabled")
        // A new identity catches up after a long clock jump (wake-style reload).
        try write(payload(deadlines: true), to: url); store.reload(); instant += 11; store.reload()
        precondition(store.reminders.count == 1)
        guard case .ready(let plan, _) = store.state else { fatalError() }
        store.startFocus(row: plan.rows[0]); instant += 1500; store.tick()
        precondition(store.focusRemaining == "00:00")
        instant += 12 * 3600; store.tick(); precondition(store.reminders.isEmpty)
        guard case .ready(_, let stale) = store.state else { fatalError() }; precondition(stale)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        store.reload(); precondition(store.notice != nil)
        try FileManager.default.removeItem(at: url); store.reload(); precondition(store.state == .empty && store.focus == nil)
        // Future-time rejection must recover without a replacement; a clock
        // reversal must also invalidate cached acceptance of the same bytes.
        var futureBody = try JSONSerialization.jsonObject(with: payload()) as! [String: Any]
        futureBody["generatedAt"] = formatter.string(from: instant.addingTimeInterval(301))
        try write(JSONSerialization.data(withJSONObject: futureBody), to: url)
        store.reload(); precondition(store.notice != nil)
        instant += 1; store.reload(); precondition(store.notice == nil)
        instant -= 10; store.reload(); precondition(store.notice != nil)
        instant += 10; store.reload(); precondition(store.notice == nil)
        try FileManager.default.removeItem(at: url); store.reload()
        // A watcher bound to an ancestor discovers a newly created directory; then a
        // whole-directory replacement must rebind and observe later payload writes.
        let watched = directory.appendingPathComponent("watched")
        let watchingStore = TodayStore(defaults: defaults, clock: { instant }, directory: watched)
        watchingStore.start()
        try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)
        try write(payload(), to: watched.appendingPathComponent("payload.json"))
        try await Task.sleep(for: .milliseconds(500))
        guard case .ready = watchingStore.state else { fatalError("Ancestor watcher missed creation") }
        try FileManager.default.moveItem(at: watched, to: directory.appendingPathComponent("old"))
        try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)
        try write(payload(), to: watched.appendingPathComponent("payload.json"))
        try await Task.sleep(for: .milliseconds(500))
        try write(Data("{}".utf8), to: watched.appendingPathComponent("payload.json"))
        try await Task.sleep(for: .milliseconds(500))
        precondition(watchingStore.notice == "Latest update was rejected.")
        print("F1/F2: heartbeat/stale, atomic reject/recover, snooze/quiet/focus/staleness, ancestor/replacement watcher PASS")
        _ = subscription

        let audio = AudioDemandOwner()
        let wing = FakeWaveform(), panel = FakeWaveform()
        audio.reevaluateDemand(); audio.drain(); precondition(audio.starts == 0)
        audio.setLevelsConsumer(wing); audio.drain()
        audio.setLevelsConsumer(panel); audio.drain(); precondition(audio.starts == 1)
        audio.clearLevelsConsumer(wing); audio.drain(); precondition(audio.stops == 0)
        audio.clearLevelsConsumer(panel); audio.drain(); precondition(audio.stops == 1)
        audio.setLevelsConsumer(wing); audio.drain(); precondition(audio.starts == 2)
        audio.clearLevelsConsumer(wing); audio.drain()
        print("F3: all-window audio demand: zero demand skips capture, shared 2 consumers/1 capture, stop/resume PASS")

        let engine = AVCaptureSessionEngine()
        let camera = CameraModel(engine: engine, authorizationStatus: .authorized)
        engine.eventHandler?(.devices([CameraDevice(id:"fake",name:"Fake",kind:.builtIn)]))
        let first = UUID(), second = UUID()
        camera.startSession(); precondition(engine.starts == 0 && camera.isDemandSuspended)
        camera.setPreviewDemand(first, owner:"one", visible:true)
        camera.setPreviewDemand(second, owner:"two", visible:true)
        precondition(engine.starts == 1)
        camera.closePreview(owner:"one"); precondition(engine.stops == 0 && camera.isIntendedRunning)
        camera.setPreviewDemand(second, owner:"two", visible:false)
        precondition(engine.stops == 1 && camera.isDemandSuspended)
        engine.eventHandler?(.started(session: AVCaptureSession(), device:CameraDevice(id:"fake",name:"Fake",kind:.builtIn)))
        precondition(camera.activeSession == nil)
        camera.selectCamera(.device("fake")); precondition(engine.starts == 1)
        camera.setPreviewDemand(second, owner:"two", visible:true); precondition(engine.starts == 2)
        camera.closePreview(owner:"two"); precondition(!camera.isIntendedRunning)
        camera.setPreviewDemand(first, owner:"one", visible:true); precondition(engine.starts == 2)
        print("F7: two windows, suspension, stale completion, explicit close: 2 starts/2 stops PASS")

        let persistence = ShelfPersistenceService(fileURL: directory.appendingPathComponent("shelf.json"))
        let file = ShelfItem(id: UUID(), kind: .file(bookmark: Data([1])))
        persistence.save([file])
        var validation: CheckedContinuation<Bool, Never>?
        var validations = 0
        let shelf = ShelfStateViewModel(persistence:persistence, validateBookmark: { _ in
            validations += 1
            return await withCheckedContinuation { validation = $0 }
        })
        shelf.cleanupInvalidItems(); await waitFor { validation != nil }
        shelf.cleanupInvalidItems(); precondition(validations == 1)
        let newDrop = ShelfItem(id:UUID(), kind:.text("New"))
        shelf.add([newDrop]); shelf.updateBookmark(for:file, bookmark:Data([2]))
        validation!.resume(returning:false); validation = nil
        for _ in 0..<20 { await Task.yield() }
        precondition(shelf.items.count == 2 && shelf.items.first?.kind == .file(bookmark:Data([2])))
        shelf.flushSync()
        let bytes = try Data(contentsOf: directory.appendingPathComponent("shelf.json"))
        let shelfURL = directory.appendingPathComponent("shelf.json")
        let modification = try shelfURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        let clean = ShelfStateViewModel(persistence:persistence, validateBookmark:{ _ in true })
        clean.cleanupInvalidItems(); for _ in 0..<20 { await Task.yield() }
        try await Task.sleep(for: .milliseconds(1100))
        let cleanBytes = try Data(contentsOf: directory.appendingPathComponent("shelf.json"))
        precondition(cleanBytes == bytes)
        let afterReopen = try shelfURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        precondition(afterReopen == modification)
        let oldWrite = Task { await persistence.saveAsync([file]) }
        await waitFor { persistence.load() == [file] }
        persistence.save([newDrop]); await oldWrite.value
        precondition(persistence.load() == [newDrop])
        print("F8: coalesced validation, newer drop/bookmark retained, clean reopen, FIFO flush PASS")

        let provider = DelayedCalendar()
        let manager = CalendarManager(calendarService:provider, observeChanges:false)
        let oldDay = instant
        let one = Task { await manager.updateCurrentDate(oldDay) }
        await waitFor { provider.queries.count == 1 }
        let duplicate = Task { await manager.updateCurrentDate(oldDay) }
        for _ in 0..<20 { await Task.yield() }; precondition(provider.queries.count == 1)
        let two = Task { await manager.updateCurrentDate(oldDay.addingTimeInterval(86400)) }
        await waitFor { provider.queries.count == 2 }
        provider.queries[1].1.resume(returning:[EventModel(id:"new")]); await two.value
        provider.queries[0].1.resume(returning:[EventModel(id:"old")]); await one.value; await duplicate.value
        precondition(manager.events == [EventModel(id:"new")])
        let reopen = Task { await manager.updateCurrentDate(oldDay.addingTimeInterval(86400)) }
        await waitFor { provider.queries.count == 3 }
        provider.queries[2].1.resume(returning:[EventModel(id:"changed")]); await reopen.value
        precondition(manager.events == [EventModel(id:"changed")])
        await manager.reloadCalendarAndReminderLists(refreshVisibleEvents:true)
        precondition(provider.queries.count == 3) // hidden calendar adds no event query
        let calendarWindow = UUID()
        manager.setVisible(calendarWindow, visible:true)
        let changedStore = Task { await manager.reloadCalendarAndReminderLists(refreshVisibleEvents:true) }
        await waitFor { provider.queries.count == 4 }
        provider.queries[3].1.resume(returning:[EventModel(id:"store-change")]); await changedStore.value
        precondition(manager.events == [EventModel(id:"store-change")])
        manager.setVisible(calendarWindow, visible:false)
        print("F9: duplicate overlap 1 query, newer day wins, same-day reopen refresh PASS")

        let periodic = PeriodicOwner()
        var pending: CheckedContinuation<Void, Never>?
        var starts = 0
        let slow: @MainActor () async -> Void = {
            starts += 1
            await withCheckedContinuation { pending = $0 }
        }
        periodic.operation = slow
        periodic.requestPeriodicUpdate(); await waitFor { pending != nil }
        for _ in 0..<30 { periodic.requestPeriodicUpdate() }
        precondition(starts == 1)
        periodic.periodicUpdateTask?.cancel()
        periodic.requestPeriodicUpdate(); precondition(starts == 1)
        pending!.resume(); pending = nil
        await waitFor { periodic.periodicUpdateTask == nil }
        periodic.requestPeriodicUpdate(); await waitFor { pending != nil }
        precondition(starts == 2); pending!.resume()
        print("F5: 30 slow-endpoint periodic triggers -> 1 in-flight request, cancellation/drain/resume PASS")
        print("Standalone workload/lifecycle checks PASS; running existing camera regression slice")
        runCameraRegressions()
    }
}
