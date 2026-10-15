import AppKit
import Darwin
import Defaults
import OSLog
import SwiftUI

/// Notch cues drive the trackpad actuator directly at the user's strength, and
/// fall back to the public AppKit alignment tap when that route is unavailable.
/// On Oct 14 the user could not feel the public tap while moving a finger; the
/// actuator at 0.70 was felt, and 0.70 through 1.30 scaled up in steps.
enum NotchHaptics {
    static let log = Logger(subsystem: "theboringteam.boringnotch", category: "haptics")

    /// One ordinary cue. Callers gate it with HapticCuePolicy.
    static func play() {
        TrackpadActuator.shared.request(strength: Defaults[.hapticStrength]) { outcome in
            log.info("cue \(outcome.logLabel, privacy: .public)")
            if outcome.needsFallback { playStandardTap() }
        }
    }

    /// One deliberate preview, for the Settings slider release.
    static func preview(strength: Double, completion: @escaping @MainActor (TrackpadActuator.Outcome) -> Void) {
        TrackpadActuator.shared.request(strength: strength, bypassThrottle: true) { outcome in
            if outcome.needsFallback { playStandardTap() }
            completion(outcome)
        }
    }

    @MainActor static func playStandardTap() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}

extension View {
    /// Plays one ordinary cue each time `trigger` changes. Callers gate the
    /// toggle with HapticCuePolicy, as they did for .sensoryFeedback.
    func notchHaptic<T: Equatable>(trigger: T) -> some View {
        onChange(of: trigger) { _, _ in NotchHaptics.play() }
    }
}

enum HapticCuePolicy {
    enum Cue { case hover, action }
    static func allows(_ cue: Cue) -> Bool {
        allows(cue, master: Defaults[.enableHaptics], hover: Defaults[.hapticHover], actions: Defaults[.hapticActions])
    }
    static func allows(_ cue: Cue, master: Bool, hover: Bool, actions: Bool) -> Bool {
        master && (cue == .hover ? hover : actions)
    }
}

enum HapticStrength {
    static let range: ClosedRange<Double> = 0.1...2.0
    static let defaultValue = 0.7
    /// Highest value the source project uses and the user felt on Oct 14.
    static let testedCeiling = 1.3
    static func clamped(_ value: Double) -> Float {
        Float(value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : defaultValue)
    }
}

/// A lease owns one opened actuator and its library handle.
protocol ActuatorLease: AnyObject {
    func pulse(strength: Float) -> Int32
    func finish() -> Int32
}

protocol ActuatorAccess {
    func acquire() -> Result<any ActuatorLease, HapticFailure>
}

struct HapticFailure: Error, Equatable {
    let message: String
}

/// Owns at most one open actuator. All work runs on one serial queue so the
/// ~25 ms open cost and the private calls never block the UI thread.
final class TrackpadActuator: @unchecked Sendable {
    enum Outcome: Equatable {
        case played
        case throttled
        case unavailable(String)
        case failed(Int32)

        var needsFallback: Bool {
            switch self {
            case .played, .throttled: false
            case .unavailable, .failed: true
            }
        }
        var logLabel: String {
            switch self {
            case .played: "actuator"
            case .throttled: "throttled"
            case .unavailable(let reason): "standard tap (\(reason))"
            case .failed(let code): "standard tap (actuate \(code))"
            }
        }
    }

    static let shared = TrackpadActuator(access: PrivateActuatorAccess())

    /// Cues closer than this are dropped so bursts of calendar or gesture
    /// cues cannot stack into a buzz.
    static let minimumGap: UInt64 = 40_000_000
    /// After a failed acquisition, standard taps are used until this passes.
    static let retryDelay: UInt64 = 30_000_000_000
    /// The actuator is released after this long without a cue.
    static let idleClose: UInt64 = 5_000_000_000

    private let access: any ActuatorAccess
    private let queue = DispatchQueue(label: "boringNotch.trackpadActuator")
    private var lease: (any ActuatorLease)?
    private var lastPulse: UInt64?
    private var retryAfter: UInt64 = 0
    private var idleGeneration = 0
    private var wakeObserver: NSObjectProtocol?

    init(access: any ActuatorAccess) {
        self.access = access
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: nil
        ) { [weak self] _ in self?.queue.async { self?.reset() } }
    }

    deinit {
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        _ = lease?.finish()
    }

    func request(strength: Double, bypassThrottle: Bool = false,
                 completion: @escaping @MainActor (Outcome) -> Void) {
        queue.async { [self] in
            let now = DispatchTime.now().uptimeNanoseconds
            let outcome = perform(strength: strength, now: now, bypassThrottle: bypassThrottle)
            if lease != nil { scheduleIdleClose() }
            DispatchQueue.main.async { completion(outcome) }
        }
    }

    /// Opens without pulsing, for the Settings route label.
    func checkRoute(completion: @escaping @MainActor (Outcome) -> Void) {
        queue.async { [self] in
            let outcome = ensureLease(now: DispatchTime.now().uptimeNanoseconds, force: true)
            if lease != nil { scheduleIdleClose() }
            DispatchQueue.main.async { completion(outcome ?? .played) }
        }
    }

    // MARK: - Queue-confined core, called directly by tests

    func perform(strength: Double, now: UInt64, bypassThrottle: Bool = false) -> Outcome {
        if !bypassThrottle, let lastPulse, now &- lastPulse < Self.minimumGap { return .throttled }
        if let failure = ensureLease(now: now, force: bypassThrottle) { return failure }
        guard let lease else { return .unavailable("no actuator") }
        let code = lease.pulse(strength: HapticStrength.clamped(strength))
        if code != 0 {
            // A stale or disconnected device: drop it so the next cue reacquires.
            _ = lease.finish()
            self.lease = nil
            return .failed(code)
        }
        lastPulse = now
        return .played
    }

    /// Returns nil when a lease is open, or the reason it is not.
    func ensureLease(now: UInt64, force: Bool = false) -> Outcome? {
        if lease != nil { return nil }
        if !force, now < retryAfter { return .unavailable("retry pending") }
        switch access.acquire() {
        case .success(let opened):
            lease = opened
            retryAfter = 0
            return nil
        case .failure(let failure):
            retryAfter = now &+ Self.retryDelay
            return .unavailable(failure.message)
        }
    }

    func reset() {
        _ = lease?.finish()
        lease = nil
        retryAfter = 0
        idleGeneration += 1
    }

    var hasOpenLease: Bool { lease != nil }

    private func scheduleIdleClose() {
        idleGeneration += 1
        let generation = idleGeneration
        queue.asyncAfter(deadline: .now() + .nanoseconds(Int(Self.idleClose))) { [self] in
            guard generation == idleGeneration, let lease else { return }
            _ = lease.finish()
            self.lease = nil
        }
    }
}

/// Minimal lookup/lifetime adaptation from Mason Chen's MIT-licensed Tactile,
/// a9b02a4e4fae6408058bd876e24accb52a864520. See THIRD_PARTY_LICENSES.
/// Local arm64 ABI inspection found MTActuatorOpen has an additional UInt32
/// argument. We pass zero explicitly and restrict use to the inspected OS build.
struct PrivateActuatorAccess: ActuatorAccess {
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

    func acquire() -> Result<any ActuatorLease, HapticFailure> {
        #if arch(arm64)
        guard abiSupported else {
            return .failure(.init(message: "private actuator ABI not checked on this OS build"))
        }
        guard let library = dlopen(libraryPath, RTLD_NOW | RTLD_LOCAL) else {
            return .failure(.init(message: "actuator library could not be loaded"))
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
            return .failure(.init(message: "required actuator symbols are missing"))
        }
        let list = unsafeBitCast(listSymbol, to: List.self)
        let getID = unsafeBitCast(idSymbol, to: DeviceID.self)
        let isBuiltIn = unsafeBitCast(builtInSymbol, to: BuiltIn.self)
        let create = unsafeBitCast(createSymbol, to: Create.self)
        let open = unsafeBitCast(openSymbol, to: Open.self)
        let close = unsafeBitCast(closeSymbol, to: Close.self)
        let pulse = unsafeBitCast(pulseSymbol, to: Actuate.self)
        guard let devices = list()?.takeRetainedValue() as? [AnyObject] else {
            return .failure(.init(message: "trackpad enumeration failed"))
        }
        var candidates: [(UInt64, Bool)] = []
        for device in devices {
            let pointer = Unmanaged.passUnretained(device).toOpaque()
            var id: UInt64 = 0
            if getID(pointer, &id) == 0, id != 0 { candidates.append((id, isBuiltIn(pointer))) }
        }
        // Prefer the built-in trackpad. For external devices use a stable ID order.
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
        return .failure(.init(message: "no current trackpad actuator could be opened"))
        #else
        return .failure(.init(message: "private actuator ABI not checked on this architecture"))
        #endif
    }
}

private final class PrivateActuatorLease: ActuatorLease {
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
        // Fixed waveform 6 (the strongest stock click), flags 0, duration scale 0.
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
    deinit { _ = finish() }
}
