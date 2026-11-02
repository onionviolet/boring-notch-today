//
//  KeepAwakePolicy.swift
//  boringNotch
//
//  The keep-awake cutoff rules as a pure function, free of IOKit and UI so
//  tests/KeepAwakePolicyTests.swift can compile it on its own.
//

import Foundation

enum KeepAwakeStopReason: String, Equatable {
    case battery
    case lowPower
    case heat

    var label: String {
        switch self {
        case .battery: "battery low"
        case .lowPower: "Low Power Mode"
        case .heat: "Mac running hot"
        }
    }
}

struct KeepAwakeInputs: Equatable {
    /// A manual keep-awake session is running.
    var sessionActive: Bool
    /// Keep the Mac awake with the lid closed while a session runs.
    var lidClosedWithSession: Bool
    /// Keep the Mac awake with the lid closed while an AI agent is mid-turn.
    var lidClosedWhileAgent: Bool
    var agentWorking: Bool
    var onBattery: Bool
    /// 0...100.
    var batteryLevel: Int
    /// 0 turns the battery cutoff off.
    var batteryThreshold: Int
    /// The session started at or below the threshold. Like KeepingYouAwake,
    /// an explicit start there is honoured instead of being cut at once.
    var startedBelowThreshold: Bool
    var lowPowerMode: Bool
    var stopInLowPowerMode: Bool
    /// `ProcessInfo.thermalState` is `.serious` or `.critical`.
    var runningHot: Bool
}

struct KeepAwakeDecision: Equatable {
    /// End the manual session, and why.
    var endSession: KeepAwakeStopReason?
    /// Whether system sleep should be off (lid-closed keep-awake).
    var lidGuard: Bool
    /// Lid-closed keep-awake was wanted but a cutoff blocks it.
    var lidBlockedBy: KeepAwakeStopReason?
}

enum KeepAwakePolicy {
    static func decide(_ input: KeepAwakeInputs) -> KeepAwakeDecision {
        let batteryLow = input.onBattery
            && input.batteryThreshold > 0
            && input.batteryLevel <= input.batteryThreshold
        let lowPower = input.lowPowerMode && input.stopInLowPowerMode

        var endSession: KeepAwakeStopReason?
        if input.sessionActive {
            if batteryLow && !input.startedBelowThreshold {
                endSession = .battery
            } else if lowPower {
                endSession = .lowPower
            }
        }
        let sessionContinues = input.sessionActive && endSession == nil

        let lidWanted = (sessionContinues && input.lidClosedWithSession)
            || (input.lidClosedWhileAgent && input.agentWorking)

        // Lid-closed is the risky mode (no airflow, possibly in a bag), so
        // its cutoffs have no start-below-threshold override.
        var blocker: KeepAwakeStopReason?
        if input.runningHot {
            blocker = .heat
        } else if batteryLow {
            blocker = .battery
        } else if lowPower {
            blocker = .lowPower
        }

        return KeepAwakeDecision(
            endSession: endSession,
            lidGuard: lidWanted && blocker == nil,
            lidBlockedBy: lidWanted ? blocker : nil
        )
    }
}

/// How dark the built-in screen gets as the lid closes, from the hinge angle
/// in degrees. Pure for the same reason as KeepAwakePolicy.
enum LidFadeCurve {
    /// Fully visible at or above this angle.
    static let fadeStart = 50.0
    /// Fully black at or below this angle.
    static let fadeEnd = 12.0

    /// 0 visible ... 1 black, eased so the last stretch darkens fastest.
    static func opacity(angle: Double) -> Double {
        let t = min(max((fadeStart - angle) / (fadeStart - fadeEnd), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Below this the lid is shut (or all but), as in clamshell use.
    static let closedAngle = 3.0

    /// Poll fast only while the lid is moving through or near the fade
    /// range, so a lid left wide open or shut costs four cheap reads a second.
    static func pollInterval(angle: Double) -> TimeInterval {
        angle > fadeStart + 30 || angle < closedAngle ? 0.25 : 1.0 / 30
    }
}
