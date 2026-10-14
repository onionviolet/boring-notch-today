import AppKit
import SwiftUI
import XCTest
@testable import boringNotch

@MainActor
final class TodayPresentationTests: XCTestCase {
    private let instant = Date(timeIntervalSince1970: 1_790_000_000)
    private func suite(_ body: (UserDefaults, String) throws -> Void) throws {
        let name = "TodayPresentationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults, name)
    }
    private func row(_ id: String) -> TodayRow {
        .init(id: id, work: "Work \(id)", purpose: "Practice a skill", studyMethod: "Use a fictional example", doneWhen: "Check the result", time: "25 min", whyNow: "Scheduled practice", basis: .plan)
    }
    private func fixture() -> TodayPayload {
        let rows = [row("plain"), row("optional"), row("required"), row("mixed")]
        let reminder = TodayReminder(id: "prep", at: instant, kind: .preparation)
        func deadline(_ id: String, _ row: String, _ required: Bool) -> TodayDeadline {
            .init(id: id, rowID: row, dueAt: instant.addingTimeInterval(3600), required: required, actionID: nil, reminders: [reminder])
        }
        return .init(schemaVersion: 2, generatedAt: instant, rows: rows,
                     next: "Optional free-text next stays visible", protectedTime: "Rest", start: "Start here", anki: nil, actions: [],
                     deadlines: [deadline("o", "optional", false), deadline("r", "required", true), deadline("mo", "mixed", false), deadline("mr", "mixed", true)])
    }
    func testDefaultsInvalidValuesAndPersistenceKeepUnrelatedState() throws {
        try suite { defaults, name in
            XCTAssertEqual(TodayPresentationPreferences(defaults: defaults), .init())
            let keys = ["today.focus.duration", "today.presentation", "today.density", "today.reminder.prominence"]
            for bad: Any in ["garbage", "", 99, true, ["bad"]] {
                for key in keys { defaults.set(bad, forKey: key) }
                XCTAssertEqual(TodayPresentationPreferences(defaults: defaults), .init())
            }
            for bad in ["0", "-1", "26", "9999"] {
                defaults.set(bad, forKey: keys[0])
                XCTAssertEqual(TodayPresentationPreferences(defaults: defaults).focusMinutes, 25)
            }
            let unrelated: [String: Any] = ["today.focus": Data("existing".utf8), "today.reminderLedger": Data("ledger".utf8), "today.quiet.enabled": true, "today.glance.horizon": "day", "hapticHover": false, "experimentalHapticStrength": "off"]
            for (key, value) in unrelated { defaults.set(value, forKey: key) }
            for (key, value) in zip(keys, ["45", "required", "compact", "subtle"]) { defaults.set(value, forKey: key) }
            let restored = try XCTUnwrap(UserDefaults(suiteName: name))
            XCTAssertEqual(TodayPresentationPreferences(defaults: restored), .init(duration: "45", presentation: "required", density: "compact", prominence: "subtle"))
            for (key, value) in unrelated { XCTAssertEqual(restored.object(forKey: key) as? NSObject, value as? NSObject) }
        }
    }
    func testNewFocusDurationAndActiveSessionSurvivePreferenceChangeAndReload() throws {
        try suite { defaults, _ in
            let store = TodayStore(defaults: defaults, clock: { self.instant })
            XCTAssertEqual(TodayPresentationPreferences(defaults: defaults).focusActionLabel, "Focus for 25 minutes")
            store.startFocus(row: row("plain"))
            let old = try XCTUnwrap(store.focus)
            XCTAssertEqual(old.endsAt, instant.addingTimeInterval(1500))
            let bytes = defaults.data(forKey: "today.focus")
            defaults.set("45", forKey: "today.focus.duration")
            XCTAssertEqual(store.focus, old)
            XCTAssertEqual(defaults.data(forKey: "today.focus"), bytes)
            let reloaded = TodayStore(defaults: defaults, clock: { self.instant.addingTimeInterval(60) })
            XCTAssertEqual(reloaded.focus, old)
            XCTAssertEqual(reloaded.focusRemaining, "24:00")
            XCTAssertEqual(TodayPresentationPreferences(defaults: defaults).focusActionLabel, "Focus for 45 minutes")
            reloaded.stopFocus()
            reloaded.startFocus(row: row("optional"))
            XCTAssertEqual(reloaded.focus?.endsAt, instant.addingTimeInterval(60 + 2700))
            for minutes in TodayPresentationPreferences.durations {
                defaults.set(String(minutes), forKey: "today.focus.duration")
                store.startFocus(row: row("plain"))
                XCTAssertEqual(store.focus?.endsAt, instant.addingTimeInterval(Double(minutes * 60)))
            }
        }
    }
    func testFilteringUsesMetadataAndKeepsOrderAndActiveTargets() throws {
        let payload = try fixture().validated(at: instant)
        let p = TodayPresentationPreferences(presentation: "required")
        XCTAssertEqual(p.rows(in: payload, retained: []).map(\.id), ["plain", "required", "mixed"])
        XCTAssertEqual(p.deadlines(for: "mixed", in: payload, retainedRows: [], reminderIDs: []).map(\.id), ["mr"])
        XCTAssertEqual(p.deadlines(for: "mixed", in: payload, retainedRows: [], reminderIDs: ["mo"]).map(\.id), ["mo", "mr"])
        XCTAssertEqual(p.rows(in: payload, retained: ["optional"]).map(\.id), payload.rows.map(\.id))
        XCTAssertEqual(p.deadlines(for: "optional", in: payload, retainedRows: ["optional"], reminderIDs: []).map(\.id), ["o"])
        let v1 = TodayPayload(schemaVersion: 1, generatedAt: instant, rows: payload.rows, next: payload.next, protectedTime: nil, start: payload.start, anki: nil, actions: [])
        XCTAssertEqual(p.rows(in: try v1.validated(at: instant), retained: []), v1.rows)
        let optionalOnly = TodayPayload(schemaVersion: 2, generatedAt: instant, rows: [row("optional")], next: nil, protectedTime: nil, start: nil, anki: nil, actions: [], deadlines: [payload.deadlines![0]])
        XCTAssertTrue(p.rows(in: optionalOnly, retained: []).isEmpty)
        XCTAssertEqual(payload.next, "Optional free-text next stays visible")
        XCTAssertEqual(payload, fixture())
    }
    func testPreferencesDoNotChangeSchedulingSnoozeDismissOrStaleState() throws {
        try suite { defaults, _ in
            var clock = instant
            let store = TodayStore(defaults: defaults, clock: { clock }, initialPayload: fixture())
            store.tick()
            XCTAssertEqual(store.reminders.count, 4)
            let ledger = defaults.data(forKey: "today.reminderLedger")
            for (key, value) in [("today.presentation", "required"), ("today.density", "compact"), ("today.reminder.prominence", "subtle")] { defaults.set(value, forKey: key) }
            _ = TodayPresentationPreferences(defaults: defaults)
            XCTAssertEqual(defaults.data(forKey: "today.reminderLedger"), ledger)
            store.tick()
            XCTAssertEqual(store.reminders.count, 4)
            store.snoozeReminders()
            XCTAssertTrue(store.reminders.isEmpty)
            clock = instant.addingTimeInterval(600)
            store.tick()
            XCTAssertEqual(store.reminders.count, 4)
            store.dismissReminders()
            store.tick()
            XCTAssertTrue(store.reminders.isEmpty)
            let reloaded = TodayStore(defaults: defaults, clock: { clock }, initialPayload: fixture())
            reloaded.tick()
            XCTAssertTrue(reloaded.reminders.isEmpty)
            clock = instant.addingTimeInterval(13 * 3600)
            reloaded.tick()
            XCTAssertTrue(reloaded.reminders.isEmpty)
        }
    }
    func testExactClipOffsetRestoreReattachAndShrinkClamping() throws {
        try suite { defaults, _ in
            defaults.set(237.5, forKey: "offset")
            let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 200))
            let document = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 1000))
            let marker = NSView(frame: .zero)
            document.addSubview(marker)
            scroll.documentView = document
            let keeper = TodayScrollPositionKeeper.Coordinator(defaultsKey: "offset", defaults: defaults)
            keeper.attach(to: marker)
            XCTAssertEqual(scroll.contentView.bounds.origin.y, 237.5, accuracy: 0.01)
            defaults.set(0, forKey: "offset")
            keeper.attach(to: marker)
            XCTAssertEqual(scroll.contentView.bounds.origin.y, 237.5, accuracy: 0.01)
            keeper.detach()
            XCTAssertEqual(defaults.double(forKey: "offset"), 237.5, accuracy: 0.01)
            document.setFrameSize(NSSize(width: 600, height: 260))
            keeper.attach(to: marker)
            XCTAssertLessThanOrEqual(scroll.contentView.bounds.origin.y, 60)
            XCTAssertGreaterThan(scroll.contentView.bounds.origin.y, 0)
            keeper.detach()
        }
    }

    private func settle(_ host: NSView) {
        for _ in 0..<12 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }
    private func scroll(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.compactMap { scroll(in: $0) }.first
    }
    private func saveRender(_ host: NSView, _ name: String) throws {
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        try data.write(to: root.appendingPathComponent("work/\(name).png"))
    }

    func testActualTodayDensityFilterProminenceScrollAndNavigationRender() throws {
        try suite { defaults, _ in
            let store = TodayStore(defaults: defaults, clock: { self.instant }, initialPayload: fixture())
            store.tick()
            @MainActor func content(_ p: TodayPresentationPreferences) -> some View {
                TodayView(store: store, startsStore: false, previewPreferences: p, scrollDefaults: defaults)
                    .frame(width: 640, height: 300).background(Color.black).environment(\.colorScheme, .dark)
            }
            defaults.set(60.0, forKey: "today.scrollOffset")
            let host = NSHostingView(rootView: content(.init()))
            host.frame = NSRect(x: 0, y: 0, width: 640, height: 300)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host
            defer { window.contentView = nil }
            settle(host)
            try saveRender(host, "o7-standard-reminders")
            let scroll = try XCTUnwrap(scroll(in: host))
            XCTAssertEqual(scroll.contentView.bounds.origin.y, 60, accuracy: 0.01)
            scroll.contentView.scroll(to: NSPoint(x: 0, y: 60))
            scroll.reflectScrolledClipView(scroll.contentView)
            let offset = scroll.contentView.bounds.origin.y
            XCTAssertGreaterThan(offset, 0)
            for prefs in [TodayPresentationPreferences(density: "compact"), .init(density: "compact", prominence: "subtle"), .init(presentation: "required", density: "compact", prominence: "subtle")] {
                host.rootView = content(prefs)
                settle(host)
                XCTAssertTrue(try XCTUnwrap(self.scroll(in: host)) === scroll)
                XCTAssertGreaterThan(scroll.contentView.bounds.origin.y, 0)
                XCTAssertLessThanOrEqual(scroll.contentView.bounds.origin.y, offset + 1)
            }
            try saveRender(host, "o7-subtle-reminders")
            store.dismissReminders()
            settle(host)
            // Explicit O6 navigation must bring back an otherwise filtered optional target.
            store.selectedRowID = "optional"
            settle(host)
            XCTAssertNil(store.selectedRowID)
            XCTAssertGreaterThan(scroll.documentView?.frame.height ?? 0, scroll.contentView.frame.height)
            try saveRender(host, "o7-today-render")
        }
    }
}
