import Defaults
import XCTest
@testable import boringNotch

final class HapticExperimentTests: XCTestCase {
    private final class Lease: ActuatorLease {
        var pulses: [Float] = []
        var finishes = 0
        var result: Int32 = 0
        func pulse(strength: Float) -> Int32 { pulses.append(strength); return result }
        func finish() -> Int32 { finishes += 1; return 0 }
    }
    private final class Access: ActuatorAccess {
        var acquisitions = 0
        var results: [Result<any ActuatorLease, HapticFailure>] = []
        func acquire() -> Result<any ActuatorLease, HapticFailure> {
            acquisitions += 1
            return results.isEmpty ? .failure(.init(message: "Disconnected")) : results.removeFirst()
        }
    }
    private let ms: UInt64 = 1_000_000

    func testStrengthPreferenceDefaultsToUserPickAndPersists() throws {
        let name = "HapticTests\(UUID())"
        let suite = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { suite.removePersistentDomain(forName: name) }
        let strength = Defaults.Key<Double>(name + "_strength", default: Defaults.Keys.hapticStrength.defaultValue, suite: suite)
        XCTAssertEqual(Defaults[strength], 0.7)
        XCTAssertEqual(HapticStrength.defaultValue, 0.7)
        Defaults[strength] = 1.15
        suite.synchronize()
        XCTAssertEqual(try XCTUnwrap(UserDefaults(suiteName: name)).double(forKey: strength.name), 1.15)
    }

    func testClampingKeepsValuesInSliderRange() {
        XCTAssertEqual(HapticStrength.clamped(0), 0.1)
        XCTAssertEqual(HapticStrength.clamped(-5), 0.1)
        XCTAssertEqual(HapticStrength.clamped(1.3), 1.3)
        XCTAssertEqual(HapticStrength.clamped(9), 2.0)
        XCTAssertEqual(HapticStrength.clamped(.nan), 0.7)
        XCTAssertEqual(HapticStrength.clamped(.infinity), 0.7)
    }

    func testCuesReuseOneOpenActuatorAtRequestedStrength() {
        let access = Access(); let lease = Lease(); access.results = [.success(lease)]
        let actuator = TrackpadActuator(access: access)
        XCTAssertEqual(actuator.perform(strength: 0.7, now: 0), .played)
        XCTAssertEqual(actuator.perform(strength: 1.3, now: 100 * ms), .played)
        XCTAssertEqual(access.acquisitions, 1)
        XCTAssertEqual(lease.pulses, [0.7, 1.3])
        XCTAssertTrue(actuator.hasOpenLease)
    }

    func testBurstsAreThrottledButPreviewBypasses() {
        let access = Access(); let lease = Lease(); access.results = [.success(lease)]
        let actuator = TrackpadActuator(access: access)
        XCTAssertEqual(actuator.perform(strength: 0.7, now: 0), .played)
        XCTAssertEqual(actuator.perform(strength: 0.7, now: 10 * ms), .throttled)
        XCTAssertFalse(TrackpadActuator.Outcome.throttled.needsFallback)
        XCTAssertEqual(actuator.perform(strength: 0.7, now: 20 * ms, bypassThrottle: true), .played)
        XCTAssertEqual(actuator.perform(strength: 0.7, now: 70 * ms), .played)
        XCTAssertEqual(lease.pulses.count, 3)
    }

    func testUnavailableRouteFallsBackAndWaitsBeforeRetrying() {
        let access = Access()
        access.results = [.failure(.init(message: "no device"))]
        let actuator = TrackpadActuator(access: access)
        let first = actuator.perform(strength: 0.7, now: 0)
        XCTAssertEqual(first, .unavailable("no device")); XCTAssertTrue(first.needsFallback)
        // Ordinary cues inside the retry window do not rescan.
        XCTAssertEqual(actuator.perform(strength: 0.7, now: 1_000 * ms), .unavailable("retry pending"))
        XCTAssertEqual(access.acquisitions, 1)
        let lease = Lease(); access.results = [.success(lease)]
        XCTAssertEqual(actuator.perform(strength: 0.7, now: TrackpadActuator.retryDelay + 1), .played)
        XCTAssertEqual(access.acquisitions, 2)
    }

    func testFailedPulseDropsStaleActuatorAndNextCueReacquires() {
        let access = Access(); let stale = Lease(); stale.result = -7; let fresh = Lease()
        access.results = [.success(stale), .success(fresh)]
        let actuator = TrackpadActuator(access: access)
        let outcome = actuator.perform(strength: 0.7, now: 0)
        XCTAssertEqual(outcome, .failed(-7)); XCTAssertTrue(outcome.needsFallback)
        XCTAssertEqual(stale.finishes, 1); XCTAssertFalse(actuator.hasOpenLease)
        XCTAssertEqual(actuator.perform(strength: 0.7, now: 100 * ms), .played)
        XCTAssertEqual(fresh.pulses, [0.7]); XCTAssertEqual(access.acquisitions, 2)
    }

    func testResetReleasesActuatorAndClearsRetryWindow() {
        let access = Access(); let lease = Lease()
        access.results = [.failure(.init(message: "asleep")), .success(lease)]
        let actuator = TrackpadActuator(access: access)
        _ = actuator.perform(strength: 0.7, now: 0)
        actuator.reset()
        XCTAssertEqual(actuator.perform(strength: 0.7, now: 100 * ms), .played)
        actuator.reset()
        XCTAssertEqual(lease.finishes, 1); XCTAssertFalse(actuator.hasOpenLease)
    }

    func testRouteCheckOpensWithoutPulsing() {
        let access = Access(); let lease = Lease(); access.results = [.success(lease)]
        let actuator = TrackpadActuator(access: access)
        XCTAssertNil(actuator.ensureLease(now: 0, force: true))
        XCTAssertTrue(lease.pulses.isEmpty); XCTAssertTrue(actuator.hasOpenLease)
    }

    func testActualLookupFailurePaths() {
        var access = PrivateActuatorAccess()
        access.abiSupported = false
        if case .failure(let failure) = access.acquire() { XCTAssertTrue(failure.message.contains("OS build")) }
        else { XCTFail("Unsupported ABI must fail") }
        access.abiSupported = true
        access.libraryPath = "/no/such/actuator.framework"
        if case .failure(let failure) = access.acquire() { XCTAssertTrue(failure.message.contains("library")) }
        else { XCTFail("Missing library must fail") }
        access.libraryPath = "/usr/lib/libSystem.B.dylib"
        access.symbolLookup = { _, _ in nil }
        if case .failure(let failure) = access.acquire() { XCTAssertTrue(failure.message.contains("symbols")) }
        else { XCTFail("Missing symbol must fail") }
    }

    func testActualEnumerationFailureAndEmptyScanNeverOpenAnActuator() {
        let missing: @convention(c) () -> Unmanaged<CFArray>? = { nil }
        let empty: @convention(c) () -> Unmanaged<CFArray>? = { Unmanaged.passRetained([] as CFArray) }
        for (function, expected) in [(missing, "enumeration"), (empty, "no current trackpad")] {
            var access = PrivateActuatorAccess()
            access.abiSupported = true
            access.libraryPath = "/usr/lib/libSystem.B.dylib"
            let address = unsafeBitCast(function, to: UnsafeMutableRawPointer.self)
            // Only the List function can be called on these nil/empty scans.
            access.symbolLookup = { _, _ in address }
            if case .failure(let failure) = access.acquire() { XCTAssertTrue(failure.message.contains(expected)) }
            else { XCTFail("An empty scan must never supply a lease") }
        }
    }

    func testCurrentUnsignedHostCanAcquireAndReleaseWithoutPulse() throws {
        switch PrivateActuatorAccess().acquire() {
        case .failure(let failure): throw XCTSkip(failure.message)
        case .success(let lease): XCTAssertEqual(lease.finish(), 0)
        }
    }

    func testMasterOverridesBothOrdinaryGroups() {
        for hover in [false, true] { for actions in [false, true] {
            XCTAssertFalse(HapticCuePolicy.allows(.hover, master: false, hover: hover, actions: actions))
            XCTAssertFalse(HapticCuePolicy.allows(.action, master: false, hover: hover, actions: actions))
            XCTAssertEqual(HapticCuePolicy.allows(.hover, master: true, hover: hover, actions: actions), hover)
            XCTAssertEqual(HapticCuePolicy.allows(.action, master: true, hover: hover, actions: actions), actions)
        } }
    }
}
