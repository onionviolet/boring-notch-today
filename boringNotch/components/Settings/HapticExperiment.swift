import AppKit
import Defaults
import Darwin

/// Ordinary cues remain on SwiftUI's supported alignment route.
enum HapticCuePolicy {
    enum Cue { case hover, action }
    static func allows(_ cue: Cue) -> Bool {
        allows(cue, master: Defaults[.enableHaptics], hover: Defaults[.hapticHover], actions: Defaults[.hapticActions])
    }
    static func allows(_ cue: Cue, master: Bool, hover: Bool, actions: Bool) -> Bool {
        master && (cue == .hover ? hover : actions)
    }
}

struct HapticStrength {
    static let conservativeDefault = 0.2
    static let choices = ["off", "0.2", "0.45", "0.7"]
    static func selection(_ stored: String) -> String { choices.contains(stored) ? stored : "0.2" }
    static func requested(_ stored: String) -> Double {
        let value = selection(stored)
        return value == "off" ? 0 : Double(value) ?? conservativeDefault
    }
    static func clamped(_ value: Double) -> Float {
        Float(value.isFinite ? min(max(value, 0), 0.7) : conservativeDefault)
    }
}

/// A lease owns one opened actuator and its library. No lease survives a request.
@MainActor
protocol ExperimentalActuatorLease: AnyObject {
    func pulse(strength: Float) -> Int32
    func finish() -> Int32
}

@MainActor
protocol ExperimentalActuatorAccess {
    func acquire() -> Result<any ExperimentalActuatorLease, HapticExperimentFailure>
}

struct HapticExperimentFailure: Error, Equatable {
    let message: String
}

@MainActor
final class HapticExperiment: ObservableObject {
    @Published private(set) var available = false
    @Published private(set) var status = "Check availability to use the experiment."
    private let access: any ExperimentalActuatorAccess

    init(access: any ExperimentalActuatorAccess = PrivateActuatorAccess()) { self.access = access }

    /// Availability checks acquire and release, but never request a pulse.
    func checkAvailability() {
        switch access.acquire() {
        case .failure(let error): fail(error.message)
        case .success(let lease):
            let code = lease.finish()
            if code == 0 {
                available = true
                status = "Available. Physical intensity is unverified."
            } else { fail("Actuator cleanup failed (\(code)).") }
        }
    }

    func test(masterEnabled: Bool, requestedStrength: Double) {
        let strength = HapticStrength.clamped(requestedStrength)
        guard masterEnabled, strength > 0 else {
            status = "Silent: haptics or requested strength is off."
            return
        }
        // Fresh enumeration prevents stale cached devices across sleep/reconnect.
        // Never retry an actuation, even when its return value reports failure.
        switch access.acquire() {
        case .failure(let error): fail(error.message)
        case .success(let lease):
            let code = lease.pulse(strength: strength)
            let cleanup = lease.finish()
            if code != 0 { fail("Test failed (\(code)); no fallback pulse was sent.") }
            else if cleanup != 0 { fail("Test returned success, but cleanup failed (\(cleanup)).") }
            else {
                available = true
                status = "One pulse requested at \(strength). Physical intensity is unverified."
            }
        }
    }

    private func fail(_ message: String) { available = false; status = message }
}

/// Minimal lookup/lifetime adaptation from Mason Chen's MIT-licensed Tactile,
/// a9b02a4e4fae6408058bd876e24accb52a864520. See THIRD_PARTY_LICENSES.
/// Local arm64 ABI inspection found MTActuatorOpen has an additional UInt32
/// argument. We pass zero explicitly and restrict use to the inspected OS build.
@MainActor
struct PrivateActuatorAccess: ExperimentalActuatorAccess {
    var libraryPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
    var symbolLookup: (UnsafeMutableRawPointer, String) -> UnsafeMutableRawPointer? = { dlsym($0, $1) }
    var abiSupported = ProcessInfo.processInfo.operatingSystemVersionString.contains("Build 26B5101f")
    private typealias List = @convention(c) () -> Unmanaged<CFArray>?
    private typealias DeviceID = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt64>) -> Int32
    private typealias BuiltIn = @convention(c) (UnsafeMutableRawPointer) -> Bool
    private typealias Create = @convention(c) (UInt64) -> UnsafeMutableRawPointer?
    private typealias Open = @convention(c) (UnsafeMutableRawPointer, UInt32) -> Int32
    fileprivate typealias Close = @convention(c) (UnsafeMutableRawPointer) -> Int32
    fileprivate typealias Actuate = @convention(c) (UnsafeMutableRawPointer, Int32, UInt32, Float, Float) -> Int32

    func acquire() -> Result<any ExperimentalActuatorLease, HapticExperimentFailure> {
        #if arch(arm64)
        guard abiSupported else {
            return .failure(.init(message: "Unavailable: private actuator ABI has not been checked on this OS build."))
        }
        guard let library = dlopen(libraryPath, RTLD_NOW | RTLD_LOCAL) else {
            return .failure(.init(message: "Unavailable: actuator library could not be loaded."))
        }
        var transferred = false
        defer { if !transferred { dlclose(library) } }
        guard let listSymbol = symbolLookup(library, "MTDeviceCreateList"),
              let idSymbol = symbolLookup(library, "MTDeviceGetDeviceID"),
              let builtInSymbol = symbolLookup(library, "MTDeviceIsBuiltIn"),
              let createSymbol = symbolLookup(library, "MTActuatorCreateFromDeviceID"),
              let openSymbol = symbolLookup(library, "MTActuatorOpen"),
              let closeSymbol = symbolLookup(library, "MTActuatorClose"),
              let pulseSymbol = symbolLookup(library, "MTActuatorActuate") else {
            return .failure(.init(message: "Unavailable: required actuator symbols are missing."))
        }
        let list = unsafeBitCast(listSymbol, to: List.self)
        let getID = unsafeBitCast(idSymbol, to: DeviceID.self)
        let isBuiltIn = unsafeBitCast(builtInSymbol, to: BuiltIn.self)
        let create = unsafeBitCast(createSymbol, to: Create.self)
        let open = unsafeBitCast(openSymbol, to: Open.self)
        let close = unsafeBitCast(closeSymbol, to: Close.self)
        let pulse = unsafeBitCast(pulseSymbol, to: Actuate.self)
        guard let devices = list()?.takeRetainedValue() as? [AnyObject] else {
            return .failure(.init(message: "Unavailable: trackpad enumeration failed."))
        }
        var candidates: [(UInt64, Bool)] = []
        for device in devices {
            let pointer = Unmanaged.passUnretained(device).toOpaque()
            var id: UInt64 = 0
            if getID(pointer, &id) == 0, id != 0 { candidates.append((id, isBuiltIn(pointer))) }
        }
        // Prefer the built-in trackpad. For external devices use a stable ID order.
        // Only one successfully opened actuator receives a Test request.
        candidates.sort { $0.1 != $1.1 ? $0.1 : $0.0 < $1.0 }
        for (id, _) in candidates {
            guard let actuator = create(id) else { continue }
            guard open(actuator, 0) == 0 else {
                Unmanaged<CFTypeRef>.fromOpaque(actuator).release()
                continue
            }
            transferred = true
            return .success(PrivateActuatorLease(library: library, actuator: actuator, close: close, actuate: pulse))
        }
        return .failure(.init(message: "Unavailable: no current trackpad actuator could be opened."))
        #else
        return .failure(.init(message: "Unavailable: private actuator ABI has not been checked on this architecture."))
        #endif
    }
}

@MainActor
private final class PrivateActuatorLease: ExperimentalActuatorLease {
    private var library: UnsafeMutableRawPointer?
    private var actuator: UnsafeMutableRawPointer?
    private let close: PrivateActuatorAccess.Close
    private let actuate: PrivateActuatorAccess.Actuate
    init(library: UnsafeMutableRawPointer, actuator: UnsafeMutableRawPointer,
         close: @escaping PrivateActuatorAccess.Close, actuate: @escaping PrivateActuatorAccess.Actuate) {
        self.library = library; self.actuator = actuator; self.close = close; self.actuate = actuate
    }
    func pulse(strength: Float) -> Int32 {
        guard let actuator else { return -1 }
        // Fixed waveform 6, flags 0, duration scale 0. Zero never reaches here.
        return actuate(actuator, 6, 0, strength, 0)
    }
    func finish() -> Int32 {
        var code: Int32 = 0
        if let actuator {
            code = close(actuator)
            Unmanaged<CFTypeRef>.fromOpaque(actuator).release()
            self.actuator = nil
        }
        if let library { dlclose(library); self.library = nil }
        return code
    }
    deinit {
        if let actuator { _ = close(actuator); Unmanaged<CFTypeRef>.fromOpaque(actuator).release() }
        if let library { dlclose(library) }
    }
}
