import Foundation

@main
struct NowPlayingTimingTests {
    private static let decoder = JSONDecoder()

    static func main() throws {
        try testMicrosConversion()
        try testLegacyTimestampFallback()
        testFreshElapsedWithoutTimestampUsesReceiptTime()
        testUnrelatedDiffPreservesMatchedPair()
        testFullResetStartsNewPair()
        testPauseResumeWithFreshSamplesDoesNotJump()
        print("NowPlayingTimingTests passed")
    }

    private static func payload(_ json: String) throws -> NowPlayingPayload {
        try decoder.decode(NowPlayingPayload.self, from: Data(json.utf8))
    }

    private static func testMicrosConversion() throws {
        let value = try payload("""
        {"durationMicros":245500000,"elapsedTimeMicros":12345678,"timestampEpochMicros":1700000000123456}
        """)
        precondition(value.resolvedDuration == 245.5)
        precondition(value.resolvedElapsedTime == 12.345678)
        precondition(value.resolvedTimestamp == Date(timeIntervalSince1970: 1_700_000_000.123456))
    }

    private static func testLegacyTimestampFallback() throws {
        let value = try payload("""
        {"duration":90,"elapsedTime":12.5,"timestamp":"2026-09-19T04:05:06Z"}
        """)
        precondition(value.resolvedDuration == 90)
        precondition(value.resolvedElapsedTime == 12.5)
        precondition(value.resolvedTimestamp == Date(timeIntervalSince1970: 1_789_790_706))
    }

    private static func testFreshElapsedWithoutTimestampUsesReceiptTime() {
        let receipt = Date(timeIntervalSince1970: 2_000)
        let resolved = NowPlayingTiming.resolve(
            previousElapsedTime: 3,
            previousTimestamp: .distantPast,
            elapsedTime: 9,
            sampleTimestamp: nil,
            isDiff: true,
            receiptTime: receipt
        )
        precondition(resolved.elapsedTime == 9)
        precondition(resolved.timestamp == receipt)
    }

    private static func testUnrelatedDiffPreservesMatchedPair() {
        let anchor = Date(timeIntervalSince1970: 1_000)
        let resolved = NowPlayingTiming.resolve(
            previousElapsedTime: 17,
            previousTimestamp: anchor,
            elapsedTime: nil,
            sampleTimestamp: Date(timeIntervalSince1970: 1_100),
            isDiff: true,
            receiptTime: Date(timeIntervalSince1970: 1_200)
        )
        precondition(resolved.elapsedTime == 17)
        precondition(resolved.timestamp == anchor)
    }

    private static func testFullResetStartsNewPair() {
        let sample = Date(timeIntervalSince1970: 3_000)
        let resolved = NowPlayingTiming.resolve(
            previousElapsedTime: 17,
            previousTimestamp: .distantPast,
            elapsedTime: nil,
            sampleTimestamp: sample,
            isDiff: false,
            receiptTime: .distantFuture
        )
        precondition(resolved.elapsedTime == 0)
        precondition(resolved.timestamp == sample)
    }

    private static func testPauseResumeWithFreshSamplesDoesNotJump() {
        let pause = NowPlayingTiming.resolve(
            previousElapsedTime: 10,
            previousTimestamp: Date(timeIntervalSince1970: 100),
            elapsedTime: 25,
            sampleTimestamp: Date(timeIntervalSince1970: 115),
            isDiff: true
        )
        let resume = NowPlayingTiming.resolve(
            previousElapsedTime: pause.elapsedTime,
            previousTimestamp: pause.timestamp,
            elapsedTime: 25,
            sampleTimestamp: Date(timeIntervalSince1970: 215),
            isDiff: true
        )
        precondition(pause.elapsedTime == 25)
        precondition(resume.elapsedTime == 25)
        precondition(resume.timestamp == Date(timeIntervalSince1970: 215))

        let inferredPause = NowPlayingTiming.resolve(
            previousElapsedTime: 10,
            previousTimestamp: Date(timeIntervalSince1970: 100),
            elapsedTime: nil,
            sampleTimestamp: nil,
            isDiff: true,
            previousIsPlaying: true,
            isPlaying: false,
            receiptTime: Date(timeIntervalSince1970: 115)
        )
        let inferredResume = NowPlayingTiming.resolve(
            previousElapsedTime: inferredPause.elapsedTime,
            previousTimestamp: inferredPause.timestamp,
            elapsedTime: nil,
            sampleTimestamp: nil,
            isDiff: true,
            previousIsPlaying: false,
            isPlaying: true,
            receiptTime: Date(timeIntervalSince1970: 215)
        )
        precondition(inferredPause.elapsedTime == 25)
        precondition(inferredResume.elapsedTime == 25)
        precondition(inferredResume.timestamp == Date(timeIntervalSince1970: 215))

        let repeatedPause = NowPlayingTiming.resolve(
            previousElapsedTime: inferredPause.elapsedTime,
            previousTimestamp: inferredPause.timestamp,
            elapsedTime: nil,
            sampleTimestamp: Date(timeIntervalSince1970: 200),
            isDiff: true,
            previousIsPlaying: false,
            isPlaying: false,
            receiptTime: Date(timeIntervalSince1970: 200)
        )
        precondition(repeatedPause.elapsedTime == 25)
        precondition(repeatedPause.timestamp == Date(timeIntervalSince1970: 115))

        let rateChange = NowPlayingTiming.resolve(
            previousElapsedTime: 10,
            previousTimestamp: Date(timeIntervalSince1970: 100),
            elapsedTime: nil,
            sampleTimestamp: nil,
            isDiff: true,
            previousIsPlaying: true,
            isPlaying: true,
            playbackRate: 1.5,
            newPlaybackRate: 2,
            receiptTime: Date(timeIntervalSince1970: 110)
        )
        precondition(rateChange.elapsedTime == 25)
        precondition(rateChange.timestamp == Date(timeIntervalSince1970: 110))
    }
}
