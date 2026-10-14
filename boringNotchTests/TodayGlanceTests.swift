import AppKit
import Defaults
import SwiftUI
import XCTest
@testable import boringNotch

@MainActor
final class TodayGlanceTests: XCTestCase {
    private func prefs(_ visibility: String = "automatic", horizon: String = "all") -> TodayGlancePreferences {
        .init(visibility: visibility, label: "compact", width: "compact", horizon: horizon)
    }

    func testInvalidPreferencesAndConservativeLabels() {
        let fallback = TodayGlancePreferences(visibility: "invalid", label: "invalid", width: "invalid", horizon: "invalid")
        XCTAssertEqual(fallback, prefs())
        XCTAssertEqual(fallback.displayTitle("POL"), "POL")
        XCTAssertEqual(fallback.displayTitle("Long arbitrary prose with no course identity"), "Long arb…")
        XCTAssertEqual(fallback.displayTitle("你好世界你好世界再见"), "你好世界你好世界…")
        let full = TodayGlancePreferences(visibility: "automatic", label: "full", width: "balanced", horizon: "all")
        XCTAssertEqual(full.displayTitle("Long arbitrary prose"), "Long arbitrary prose")
        XCTAssertEqual(full.width.cap, 80)
    }

    func testHorizonBoundariesOnlyFilterRoutineDeadlines() {
        let now = Date(timeIntervalSince1970: 0)
        for (horizon, boundary) in [("hour", 3600.0), ("sixHours", 21600.0), ("day", 86400.0)] {
            let p = prefs(horizon: horizon)
            XCTAssertTrue(p.includes(now.addingTimeInterval(boundary), at: now))
            XCTAssertFalse(p.includes(now.addingTimeInterval(boundary + 1), at: now))
            XCTAssertFalse(p.includes(now, at: now))
            XCTAssertEqual(p.activity(reminder: true, focus: true, dueAt: now.addingTimeInterval(boundary + 1), at: now, music: true, blocked: false), .reminder)
            XCTAssertEqual(p.activity(reminder: false, focus: true, dueAt: nil, at: now, music: true, blocked: false), .focus)
        }
        XCTAssertTrue(prefs().includes(now.addingTimeInterval(365 * 86400), at: now))
    }

    func testActivityTransitionsAndSuppression() {
        let now = Date(); let due = now.addingTimeInterval(60)
        let p = prefs()
        XCTAssertEqual(p.activity(reminder: false, focus: false, dueAt: due, at: now, music: false, blocked: false), .deadline)
        XCTAssertNil(p.activity(reminder: false, focus: false, dueAt: due, at: now, music: true, blocked: false))
        XCTAssertEqual(p.activity(reminder: false, focus: true, dueAt: due, at: now, music: true, blocked: false), .focus)
        XCTAssertEqual(p.activity(reminder: true, focus: true, dueAt: due, at: now, music: true, blocked: false), .reminder)
        // The caller supplies the same suppression for fullscreen, zero height,
        // open notch, notification, hello, fallback notice, battery and HUD.
        XCTAssertNil(p.activity(reminder: true, focus: true, dueAt: due, at: now, music: false, blocked: true))
        XCTAssertNil(prefs("hidden").activity(reminder: true, focus: true, dueAt: due, at: now, music: false, blocked: false))
        XCTAssertNil(p.activity(reminder: false, focus: false, dueAt: nil, at: now, music: false, blocked: false))
    }

    func testCountdownBuckets() {
        let now = Date(timeIntervalSince1970: 0)
        for (seconds, expected) in [(-1.0, "Done"), (0, "Done"), (1, "1m"), (60, "1m"), (61, "2m"), (3540, "59m"), (3541, "1h"), (3600, "1h"), (3601, "2h"), (86340, "24h"), (86400, "1d"), (86401, "2d"), (1000 * 86400, "999d+")] {
            XCTAssertEqual(TodayGlancePresentation.countdown(to: now.addingTimeInterval(seconds), at: now), expected)
        }
    }

    func testAsymmetricGeometryAnchorsPhysicalCenterAndBounds() {
        let notch: CGFloat = 180
        for cap: CGFloat in [56, 80] {
            for (left, right): (CGFloat, CGFloat) in [(0, 0), (12, 0), (0, 35), (12, 35), (500, 500), (500, 12)] {
                let g = TodayGlanceGeometry(leftTextWidth: left, rightTextWidth: right, cap: cap, outerPadding: 14)
                let width = g.visibleWidth(notchWidth: notch)
                let start = -width / 2 + g.centerOffset
                let hardwareStart = start + 14 + g.leftWidth
                XCTAssertEqual(hardwareStart, -notch / 2, accuracy: 0.001)
                XCTAssertEqual(start + width, notch / 2 + g.rightWidth + 14, accuracy: 0.001)
                XCTAssertLessThanOrEqual(g.leftWidth + 14, cap)
                XCTAssertLessThanOrEqual(g.rightWidth + 14, cap)
                XCTAssertEqual(g.leftWidth == 0, left == 0)
                XCTAssertEqual(g.rightWidth == 0, right == 0)
            }
        }
    }

    func testActualFontLegibilityAndStableWidths() {
        for cap: CGFloat in [56, 80] {
            let short = TodayNotchGlance.geometry(label: "POL", cap: cap, outerPadding: 14)
            let long = TodayNotchGlance.geometry(label: "A very long title that must truncate", cap: cap, outerPadding: 14)
            XCTAssertLessThan(short.leftWidth, long.leftWidth)
            XCTAssertEqual(short.rightWidth, long.rightWidth)
            for status in ["1m", "59m", "24h", "999d+", "Done", "Alert"] {
                XCTAssertLessThanOrEqual(TodayNotchGlance.textWidth(status, monospaced: true) + 4, short.rightWidth)
            }
            XCTAssertLessThanOrEqual(long.visibleWidth(notchWidth: 180), 180 + 2 * cap)
        }
    }

    func testPreferencesPersistAcrossNewDefaultsInstance() throws {
        let name = "TodayGlanceTests.\(UUID().uuidString)"
        let first = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { first.removePersistentDomain(forName: name) }
        first.set("hidden", forKey: "today.glance.visibility")
        first.set("full", forKey: "today.glance.label")
        first.set("balanced", forKey: "today.glance.width")
        first.set("day", forKey: "today.glance.horizon")
        let restored = try XCTUnwrap(UserDefaults(suiteName: name))
        let p = TodayGlancePreferences(visibility: restored.string(forKey: "today.glance.visibility")!, label: restored.string(forKey: "today.glance.label")!, width: restored.string(forKey: "today.glance.width")!, horizon: restored.string(forKey: "today.glance.horizon")!)
        XCTAssertEqual(p.visibility, .hidden)
        XCTAssertEqual(p.label, .full)
        XCTAssertEqual(p.width, .balanced)
        XCTAssertEqual(p.horizon, .day)
    }
    func testRenderActualGlanceWithCenterGuides() throws {
        let scenarios: [(String, String, String, CGFloat, Bool, Bool)] = [
            ("Compact short", "POL", "23h", 56, true, true),
            ("Compact long", "Long arbitrary title…", "999d+", 56, true, true),
            ("Balanced full", "POL · Tue 23:59", "Alert", 80, true, true),
            ("Left only", "POL", "", 56, true, false),
            ("Right only", "", "25m", 56, false, true),
            ("No wings", "", "", 56, false, false)
        ]
        let content = VStack(spacing: 12) {
            ForEach(scenarios.indices, id: \.self) { index in
                let item = scenarios[index]
                let measured = TodayNotchGlance.geometry(label: item.1, cap: item.3, outerPadding: 14)
                let geometry = TodayGlanceGeometry(leftTextWidth: item.4 ? TodayNotchGlance.textWidth(item.1) : 0,
                    rightTextWidth: item.5 ? measured.rightWidth - 4 : 0, cap: item.3, outerPadding: 14)
                let presentation = TodayGlancePresentation(rowID: "test", title: item.1, label: item.1,
                    status: item.2, detail: item.2, isReminder: item.2 == "Alert", geometry: geometry)
                VStack(spacing: 2) {
                    Text(item.0).font(.caption).foregroundStyle(.white)
                    ZStack {
                        TodayNotchGlance(presentation: presentation, notchWidth: 180, height: 38, openToday: { _ in })
                            .padding(.horizontal, 14)
                            .background(.black)
                            .clipShape(NotchShape(topCornerRadius: 6, bottomCornerRadius: 14))
                            .offset(x: geometry.centerOffset)
                        HStack(spacing: 180) {
                            Color.red.frame(width: 1)
                            Color.red.frame(width: 1)
                        }.frame(height: 38).allowsHitTesting(false)
                    }.frame(width: 640, height: 38)
                }
            }
        }.padding(12).background(Color(red: 0.45, green: 0.45, blue: 0.47)).environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        renderer.isOpaque = true
        let image = try XCTUnwrap(renderer.cgImage)
        let bitmap = NSBitmapImageRep(cgImage: image)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        try png.write(to: root.appendingPathComponent("work/o6-glance-render.png"))
    }

}
