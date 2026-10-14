import XCTest
import SwiftUI
import AppKit
@testable import boringNotch

@MainActor
final class MusicDurationTests: XCTestCase {
    func testLegacyHeightMigrationPreservesZeroAndSupportedHeights() {
        XCTAssertEqual(LegacyNonNotchHeightMigration.migratedHeight(0), 0)
        XCTAssertEqual(LegacyNonNotchHeightMigration.migratedHeight(1), 15)
        XCTAssertEqual(LegacyNonNotchHeightMigration.migratedHeight(14.5), 15)
        XCTAssertEqual(LegacyNonNotchHeightMigration.migratedHeight(15), 15)
        XCTAssertEqual(LegacyNonNotchHeightMigration.migratedHeight(38), 38)
    }

    func testProviderSentinelsAndUnknownDurationCannotSeek() {
        for duration in [-1.0, 0, .nan, .infinity, -.infinity, 1_732_919_508, Double.greatestFiniteMagnitude] {
            XCTAssertFalse(MusicSliderView.hasUsableDuration(duration))
            if duration != 0 { XCTAssertEqual(MusicSliderView.timeString(from: duration), "--:--") }
        }
        XCTAssertTrue(MusicSliderView.hasUsableDuration(180))
        XCTAssertTrue(MusicSliderView.hasUsableDuration(86_400))
        XCTAssertFalse(MusicSliderView.hasUsableDuration(86_401))
        XCTAssertEqual(MusicSliderView.timeString(from: 180), "3:00")
        XCTAssertEqual(MusicSliderView.timeString(from: 0), "0:00")
    }

    @MainActor
    func testInvalidDurationRendersWithoutConstructingInvalidRange() {
        for duration in [-1.0, Double.nan, .infinity, 1_732_919_508] {
            let slider = MusicSliderView(sliderValue: .constant(0), duration: .constant(duration),
                lastDragged: .constant(.distantPast), color: .white, dragging: .constant(false),
                currentDate: Date(), timestampDate: Date(), elapsedTime: 0, playbackRate: 1,
                isPlaying: true, onValueChange: { _ in XCTFail("Unknown duration must not seek") })
            let host = NSHostingView(rootView: slider)
            host.frame = NSRect(x: 0, y: 0, width: 240, height: 60)
            host.layoutSubtreeIfNeeded()
            XCTAssertFalse(host.fittingSize.height.isNaN)
        }
    }
}
