import Defaults
import XCTest
@testable import boringNotch

@MainActor
final class HapticExperimentTests: XCTestCase {
    private final class Lease: ExperimentalActuatorLease {
        var pulses: [Float] = []
        var finishes = 0
        var result: Int32 = 0
        var cleanup: Int32 = 0
        func pulse(strength: Float) -> Int32 { pulses.append(strength); return result }
        func finish() -> Int32 { finishes += 1; return cleanup }
    }
    private final class Access: ExperimentalActuatorAccess {
        var acquisitions = 0
        var results: [Result<any ExperimentalActuatorLease, HapticExperimentFailure>] = []
        func acquire() -> Result<any ExperimentalActuatorLease, HapticExperimentFailure> {
            acquisitions += 1
            return results.isEmpty ? .failure(.init(message: "Disconnected")) : results.removeFirst()
        }
    }

    func testPreferenceMigrationPersistenceAndInvalidValuesDoNotPulse() throws {
        let name = "HapticTests\(UUID())"
        let suite = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { suite.removePersistentDomain(forName: name) }
        // Namespace keys too, since Defaults registration can be shared by suites.
        let master = Defaults.Key<Bool>(name + "_master", default: Defaults.Keys.enableHaptics.defaultValue, suite: suite)
        let hover = Defaults.Key<Bool>(name + "_hover", default: Defaults.Keys.hapticHover.defaultValue, suite: suite)
        let actions = Defaults.Key<Bool>(name + "_actions", default: Defaults.Keys.hapticActions.defaultValue, suite: suite)
        let strength = Defaults.Key<String>(name + "_strength", default: Defaults.Keys.experimentalHapticStrength.defaultValue, suite: suite)
        let access = Access(); let experiment = HapticExperiment(access: access)
        XCTAssertTrue(Defaults[master]); XCTAssertTrue(Defaults[hover]); XCTAssertTrue(Defaults[actions])
        XCTAssertEqual(HapticStrength.requested(Defaults[strength]), 0.2)
        Defaults[master] = false; Defaults[hover] = false; Defaults[actions] = true; Defaults[strength] = "0.45"
        suite.synchronize()
        let reopened = try XCTUnwrap(UserDefaults(suiteName: name))
        XCTAssertFalse(reopened.bool(forKey: master.name)); XCTAssertFalse(reopened.bool(forKey: hover.name))
        XCTAssertTrue(reopened.bool(forKey: actions.name))
        XCTAssertEqual(HapticStrength.requested(try XCTUnwrap(reopened.string(forKey: strength.name))), 0.45)
        Defaults[strength] = "nan"
        XCTAssertEqual(HapticStrength.requested(Defaults[strength]), 0.2)
        suite.set(42, forKey: strength.name)
        XCTAssertEqual(HapticStrength.requested(Defaults[strength]), 0.2)
        XCTAssertEqual(access.acquisitions, 0)
        XCTAssertFalse(experiment.available)
    }

    func testOffMasterOffAndClampingAtActuatorBoundary() {
        let access = Access(); let lease = Lease(); access.results = [.success(lease)]
        let experiment = HapticExperiment(access: access)
        for value in [0.2, 0.45, 0.7, 100.0] { experiment.test(masterEnabled: false, requestedStrength: value) }
        for value in [0.0, -1.0, -Double.infinity] {
            // Nonfinite values fall back to the conservative default; master remains off.
            experiment.test(masterEnabled: value.isFinite, requestedStrength: value)
        }
        XCTAssertEqual(access.acquisitions, 0)
        experiment.test(masterEnabled: true, requestedStrength: 10)
        XCTAssertEqual(lease.pulses, [0.7]); XCTAssertEqual(lease.finishes, 1)
        XCTAssertEqual(HapticStrength.clamped(.nan), 0.2)
        XCTAssertEqual(HapticStrength.clamped(.infinity), 0.2)
        XCTAssertEqual(HapticStrength.requested("off"), 0)
    }

    func testOneExplicitRequestAndAvailabilityNeverPulses() {
        let access = Access(); let check = Lease(); let test = Lease()
        access.results = [.success(check), .success(test)]
        let experiment = HapticExperiment(access: access)
        experiment.checkAvailability()
        XCTAssertTrue(experiment.available); XCTAssertTrue(check.pulses.isEmpty); XCTAssertEqual(check.finishes, 1)
        // Preference editing/restoration has no callback into this controller.
        for choice in HapticStrength.choices { _ = HapticStrength.requested(choice) }
        XCTAssertEqual(access.acquisitions, 1)
        experiment.test(masterEnabled: true, requestedStrength: 0.45)
        XCTAssertEqual(access.acquisitions, 2); XCTAssertEqual(test.pulses, [0.45]); XCTAssertEqual(test.finishes, 1)
        XCTAssertTrue(experiment.status.contains("unverified"))
    }

    func testFailedActuationCleansUpWithoutRetryOrFallback() {
        let access = Access(); let lease = Lease(); lease.result = -7
        access.results = [.success(lease)]
        let experiment = HapticExperiment(access: access)
        experiment.test(masterEnabled: true, requestedStrength: 0.2)
        XCTAssertEqual(lease.pulses.count, 1); XCTAssertEqual(lease.finishes, 1)
        XCTAssertEqual(access.acquisitions, 1); XCTAssertFalse(experiment.available)
        XCTAssertTrue(experiment.status.contains("-7"))
    }

    func testDisconnectInvalidatesAvailabilityAndExplicitRecheckReacquires() {
        let access = Access(); let before = Lease(); let after = Lease(); let pulse = Lease()
        access.results = [.success(before), .failure(.init(message: "Disconnected")), .success(after), .success(pulse)]
        let experiment = HapticExperiment(access: access)
        experiment.checkAvailability()
        experiment.test(masterEnabled: true, requestedStrength: 0.2)
        XCTAssertFalse(experiment.available); XCTAssertTrue(before.pulses.isEmpty)
        experiment.checkAvailability(); XCTAssertTrue(experiment.available)
        experiment.test(masterEnabled: true, requestedStrength: 0.2)
        XCTAssertEqual(pulse.pulses, [0.2]); XCTAssertEqual(before.finishes, 1)
        XCTAssertEqual(after.finishes, 1); XCTAssertTrue(after.pulses.isEmpty)
    }

    func testUnavailableFailuresRemainVisibleAndSilent() {
        for reason in ["Missing library", "Missing symbol", "Enumeration failed", "No device"] {
            let access = Access(); access.results = [.failure(.init(message: reason))]
            let experiment = HapticExperiment(access: access)
            experiment.test(masterEnabled: true, requestedStrength: 0.2)
            XCTAssertFalse(experiment.available); XCTAssertEqual(experiment.status, reason)
            XCTAssertEqual(access.acquisitions, 1)
        }
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

    func testCleanupFailureDisablesExperiment() {
        let access = Access(); let lease = Lease(); lease.cleanup = -9
        access.results = [.success(lease)]
        let experiment = HapticExperiment(access: access)
        experiment.checkAvailability()
        XCTAssertFalse(experiment.available); XCTAssertTrue(lease.pulses.isEmpty)
        XCTAssertEqual(lease.finishes, 1); XCTAssertTrue(experiment.status.contains("-9"))
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
