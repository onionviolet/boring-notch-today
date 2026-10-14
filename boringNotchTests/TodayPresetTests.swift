import AppKit
import SwiftUI
import XCTest
@testable import boringNotch

@MainActor
final class TodayPresetTests: XCTestCase {
    private func suite(_ body: (TodayPresetStore, String) throws -> Void) throws {
        let name = "TodayPresetTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(TodayPresetStore(defaults: defaults, domain: name), name)
    }
    private func raw(_ store: TodayPresetStore) -> NSDictionary {
        (store.defaults.persistentDomain(forName: store.domain) ?? [:]) as NSDictionary
    }
    func testBuiltInsAndHumanPreviewAreFullDeterministicStates() throws {
        let expected = [
            TodayPresetName.study: ["25", "required", "compact", "standard", "automatic", "compact", "compact", "day"],
            .quiet: ["25", "all", "compact", "subtle", "hidden", "compact", "compact", "all"],
            .media: ["25", "all", "current", "standard", "hidden", "compact", "compact", "all"]]
        try suite { store, _ in
            let initial = raw(store)
            for (name, values) in expected {
                let target = try XCTUnwrap(store.target(name))
                XCTAssertEqual(TodayPresetKey.allCases.map { target[$0] }, values)
                for change in store.preview(name) {
                    XCTAssertEqual(change.after, target[change.key])
                    XCTAssertTrue(change.description.contains(change.key.title))
                    XCTAssertTrue(change.description.contains(change.key.display(change.after)))
                }
            }
            XCTAssertEqual(raw(store), initial)
            XCTAssertNil(TodayPresetValues(["bad"]))
            XCTAssertNil(store.custom)
        }
    }
    func testCustomNormalizesLiveValuesPersistsWithoutApplyingOrReplacingUndo() throws {
        try suite { store, name in
            for key in TodayPresetKey.allCases {
                for bad: Any in [99, true, ["bad"], "invalid"] {
                    store.defaults.set(bad, forKey: key.rawValue)
                    XCTAssertEqual(store.current[key], key.fallback)
                }
            }
            store.apply(.study)
            let before = raw(store).mutableCopy() as! NSMutableDictionary
            store.saveCustom()
            before[TodayPresetStore.customKey] = store.defaults.data(forKey: TodayPresetStore.customKey)
            XCTAssertEqual(raw(store), before)
            let fresh = TodayPresetStore(defaults: try XCTUnwrap(UserDefaults(suiteName: name)), domain: name)
            XCTAssertEqual(fresh.custom, fresh.current)
            XCTAssertTrue(fresh.canRestore)
        }
    }
    func testSavedCustomAppliesItsSnapshotAndRestoreKeepsImmediatePriorState() throws {
        try suite { store, name in
            store.defaults.set("45", forKey: TodayPresetKey.duration.rawValue)
            store.defaults.set("full", forKey: TodayPresetKey.label.rawValue)
            store.defaults.set("balanced", forKey: TodayPresetKey.width.rawValue)
            store.saveCustom()
            let saved = try XCTUnwrap(store.custom)
            store.defaults.set("15", forKey: TodayPresetKey.duration.rawValue)
            store.defaults.set("compact", forKey: TodayPresetKey.label.rawValue)
            let fresh = TodayPresetStore(defaults: try XCTUnwrap(UserDefaults(suiteName: name)), domain: name)
            XCTAssertEqual(fresh.preview(.custom).map(\.key), [.duration, .label])
            XCTAssertEqual(fresh.apply(.custom).count, 2)
            XCTAssertEqual(fresh.current, saved)
            fresh.restore()
            XCTAssertEqual(fresh.current[.duration], "15")
            XCTAssertEqual(fresh.current[.label], "compact")
            XCTAssertEqual(fresh.custom, saved)
        }
    }
    func testApplyReadsFreshBeforeAndRestoreSurvivesReconstruction() throws {
        try suite { store, name in
            _ = store.preview(.study)
            store.defaults.set("60", forKey: TodayPresetKey.duration.rawValue)
            store.defaults.set("full", forKey: TodayPresetKey.label.rawValue)
            let delta = store.apply(.study)
            XCTAssertEqual(delta.first(where: { $0.key == .duration })?.before, "60")
            XCTAssertEqual(store.current, TodayPresetName.study.builtIn)
            let fresh = TodayPresetStore(defaults: try XCTUnwrap(UserDefaults(suiteName: name)), domain: name)
            XCTAssertNotNil(fresh.restore())
            XCTAssertEqual(fresh.current[.duration], "60")
            XCTAssertEqual(fresh.current[.label], "full")
            XCTAssertNil(fresh.defaults.persistentDomain(forName: name)?[TodayPresetKey.presentation.rawValue])
            XCTAssertFalse(fresh.canRestore)
        }
    }
    func testRegisteredDefaultsAreNotMistakenForStoredPriorState() throws {
        try suite { store, name in
            store.defaults.register(defaults: [TodayPresetKey.presentation.rawValue: "all"])
            XCTAssertNil(store.defaults.persistentDomain(forName: name)?[TodayPresetKey.presentation.rawValue])
            store.apply(.study)
            store.restore()
            XCTAssertNil(store.defaults.persistentDomain(forName: name)?[TodayPresetKey.presentation.rawValue])
            XCTAssertEqual(store.defaults.string(forKey: TodayPresetKey.presentation.rawValue), "all")
        }
    }
    func testNoOpPreservesUndoAndLaterApplyHasOnlyOneLevel() throws {
        try suite { store, _ in
            store.apply(.study)
            let undo = store.defaults.data(forKey: TodayPresetStore.restoreKey)
            let before = raw(store)
            XCTAssertTrue(store.apply(.study).isEmpty)
            XCTAssertEqual(raw(store), before)
            XCTAssertEqual(store.defaults.data(forKey: TodayPresetStore.restoreKey), undo)
            store.apply(.quiet)
            store.restore()
            XCTAssertEqual(store.current, TodayPresetName.study.builtIn)
            XCTAssertNil(store.restore())
        }
    }
    func testRestoreRetainsManualRawInvalidAndRemovedValuesAndConsumesAllConflicts() throws {
        try suite { store, _ in
            store.defaults.set("60", forKey: TodayPresetKey.duration.rawValue)
            store.apply(.study)
            store.defaults.set("45", forKey: TodayPresetKey.duration.rawValue)
            store.defaults.set("invalid", forKey: TodayPresetKey.presentation.rawValue)
            store.defaults.removeObject(forKey: TodayPresetKey.density.rawValue)
            let result = try XCTUnwrap(store.restore())
            XCTAssertEqual(Set(result.retained), [.duration, .presentation, .density])
            XCTAssertEqual(result.restored, [.horizon])
            XCTAssertEqual(store.defaults.string(forKey: TodayPresetKey.presentation.rawValue), "invalid")
            XCTAssertNil(store.defaults.persistentDomain(forName: store.domain)?[TodayPresetKey.density.rawValue])
            XCTAssertFalse(store.canRestore)
            let delta = store.apply(.quiet)
            for change in delta { store.defaults.removeObject(forKey: change.key.rawValue) }
            let all = try XCTUnwrap(store.restore())
            XCTAssertEqual(all.retained.count, delta.count)
            XCTAssertTrue(all.restored.isEmpty)
            XCTAssertFalse(store.canRestore)
        }
    }
    func testFallbackCoincidenceDoesNotEraseRawConflicts() throws {
        try suite { store, _ in
            store.defaults.set("60", forKey: TodayPresetKey.duration.rawValue)
            store.defaults.set("compact", forKey: TodayPresetKey.density.rawValue)
            store.apply(.media)
            store.defaults.removeObject(forKey: TodayPresetKey.duration.rawValue)
            store.defaults.set(99, forKey: TodayPresetKey.density.rawValue)
            XCTAssertEqual(store.current[.duration], "25")
            XCTAssertEqual(store.current[.density], "current")
            let result = try XCTUnwrap(store.restore())
            XCTAssertEqual(Set(result.retained), [.duration, .density])
            XCTAssertNil(store.defaults.persistentDomain(forName: store.domain)?[TodayPresetKey.duration.rawValue])
            XCTAssertEqual(store.defaults.integer(forKey: TodayPresetKey.density.rawValue), 99)
        }
    }
    func testInvalidInitialStoredValueRestoresNormalizedDefault() throws {
        try suite { store, _ in
            store.defaults.set(["unvalidated"], forKey: TodayPresetKey.presentation.rawValue)
            store.apply(.study)
            store.restore()
            XCTAssertEqual(store.defaults.string(forKey: TodayPresetKey.presentation.rawValue), "all")
        }
    }
    func testWholeRecordRejectionForCustomAndUndo() throws {
        try suite { store, _ in
            store.saveCustom()
            store.apply(.study)
            for storageKey in [TodayPresetStore.customKey, TodayPresetStore.restoreKey] {
                let valid = try XCTUnwrap(store.defaults.data(forKey: storageKey))
                let root = try XCTUnwrap(JSONSerialization.jsonObject(with: valid) as? [String: Any])
                let entries = root["entries"] as! [[String: Any]]
                var bads: [[String: Any]] = []
                var bad = root; bad["version"] = 2; bads.append(bad)
                bad = root; bad["version"] = true; bads.append(bad)
                bad = root; bad["unknown"] = "field"; bads.append(bad)
                bad = root; bad["entries"] = []; bads.append(bad)
                bad = root; bad["entries"] = entries + [entries[0]]; bads.append(bad)
                for (key, value): (String, Any) in [("key", "today.focus"), ("value", "invalid"), ("value", 25), ("unknown", true), ("previous", ["blob"])] {
                    var rows = entries; rows[0][key] = value
                    bad = root; bad["entries"] = rows; bads.append(bad)
                }
                if storageKey == TodayPresetStore.customKey { bad = root; bad["entries"] = Array(entries.dropLast()); bads.append(bad) }
                var data = try bads.map { try JSONSerialization.data(withJSONObject: $0) }
                data += [Data("{broken".utf8), Data(repeating: 65, count: 4097)]
                for corrupt in data {
                    store.defaults.set(corrupt, forKey: storageKey)
                    let before = raw(store)
                    if storageKey == TodayPresetStore.customKey {
                        XCTAssertNil(store.custom); XCTAssertTrue(store.apply(.custom).isEmpty)
                    } else { XCTAssertFalse(store.canRestore); XCTAssertNil(store.restore()) }
                    XCTAssertEqual(raw(store), before)
                }
                store.defaults.set(valid, forKey: storageKey)
            }
        }
    }
    func testApplyRestoreWhitelistProtectsSchedulingAndOtherBoundaries() throws {
        try suite { store, _ in
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let row = TodayRow(id: "synthetic", work: "Practice", purpose: "Learn", studyMethod: "Read", doneWhen: "Checked", time: "25 min", whyNow: "Planned", basis: .plan)
            let today = TodayStore(defaults: store.defaults, clock: { now })
            today.startFocus(row: row)
            let active = try XCTUnwrap(today.focus)
            let sentinels: [String: Any] = ["today.focus": try XCTUnwrap(store.defaults.data(forKey: "today.focus")), "today.reminderLedger": Data("ledger".utf8), "today.quiet.enabled": true, "today.quiet.start": 60, "today.quiet.end": 90, "today.scrollOffset": 237.5, "experimentalHapticStrength": "0.7", "hapticHover": false, "notchHeight": 38, "enableGestures": false, "selectedTab": "today", "updaterFeed": "disabled", "payload": Data("synthetic".utf8)]
            for (key, value) in sentinels { store.defaults.set(value, forKey: key) }
            let baseline = raw(store)
            for preset in [TodayPresetName.study, .quiet, .media] {
                store.apply(preset)
                store.saveCustom()
                XCTAssertEqual(today.focus, active)
                XCTAssertEqual(TodayStore(defaults: store.defaults, clock: { now }).focus?.endsAt, active.endsAt)
                store.restore()
                for (key, value) in sentinels { XCTAssertEqual(raw(store)[key] as? NSObject, value as? NSObject) }
            }
            let permitted = Set(TodayPresetKey.allCases.map(\.rawValue) + [TodayPresetStore.customKey, TodayPresetStore.restoreKey])
            for key in raw(store).allKeys.compactMap({ $0 as? String }) where !permitted.contains(key) {
                XCTAssertEqual(raw(store)[key] as? NSObject, baseline[key] as? NSObject)
            }
        }
    }
    func testPresetsDoNotAcknowledgeOrSuppressSyntheticDueReminder() throws {
        try suite { store, _ in
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let row = TodayRow(id: "optional", work: "Practice", purpose: "Learn", studyMethod: "Read", doneWhen: "Checked", time: "25 min", whyNow: "Planned", basis: .plan)
            let deadline = TodayDeadline(id: "due", rowID: row.id, dueAt: now.addingTimeInterval(3600), required: false, actionID: nil, reminders: [.init(id: "prep", at: now, kind: .preparation)])
            let payload = TodayPayload(schemaVersion: 2, generatedAt: now, rows: [row], next: "Free text", protectedTime: nil, start: nil, anki: nil, actions: [], deadlines: [deadline])
            let today = TodayStore(defaults: store.defaults, clock: { now }, initialPayload: payload)
            today.tick()
            XCTAssertEqual(today.reminders.count, 1)
            let ledger = store.defaults.data(forKey: "today.reminderLedger")
            for preset in [TodayPresetName.study, .quiet, .media] {
                store.apply(preset)
                today.tick()
                XCTAssertEqual(today.reminders.count, 1)
                XCTAssertEqual(store.defaults.data(forKey: "today.reminderLedger"), ledger)
                XCTAssertEqual(TodayPresentationPreferences(defaults: store.defaults).rows(in: payload, retained: [row.id]).map(\.id), [row.id])
                store.restore()
                today.tick()
                XCTAssertEqual(today.reminders.count, 1)
                XCTAssertEqual(store.defaults.data(forKey: "today.reminderLedger"), ledger)
            }
        }
    }
    func testOffscreenPresetSectionRendersWithoutWrites() throws {
        try suite { store, _ in
            @MainActor func render(_ name: TodayPresetName, _ suffix: String, status: String = "") throws {
                let before = raw(store)
                let host = NSHostingView(rootView: Form { TodayPresetSettingsView(store: store, selection: name, status: status) }.formStyle(.grouped).frame(width: 480, height: 800).environment(\.colorScheme, .dark))
                host.frame = NSRect(x: 0, y: 0, width: 480, height: 800)
                let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                window.contentView = host
                defer { window.contentView = nil }
                for _ in 0..<12 { host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                try data.write(to: root.appendingPathComponent("work/o8-\(suffix).png"))
                XCTAssertEqual(raw(store), before)
            }
            for name in [TodayPresetName.study, .quiet, .media, .custom] { try render(name, name.rawValue.lowercased()) }
            store.saveCustom(); try render(.custom, "custom-saved")
            store.apply(.study); try render(.study, "noop-restore")
            store.defaults.set("full", forKey: TodayPresetKey.label.rawValue)
            store.apply(.media)
            store.defaults.set("automatic", forKey: TodayPresetKey.visibility.rawValue)
            let result = try XCTUnwrap(store.restore())
            try render(.quiet, "restore-result", status: result.message)
        }
    }
}
