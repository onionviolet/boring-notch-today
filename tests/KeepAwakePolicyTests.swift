import Foundation

@main struct KeepAwakePolicyTests {
    static let base = KeepAwakeInputs(
        sessionActive: true, lidClosedWithSession: false, lidClosedWhileClaude: false,
        claudeWorking: false, onBattery: true, batteryLevel: 80, batteryThreshold: 20,
        startedBelowThreshold: false, lowPowerMode: false, stopInLowPowerMode: true,
        runningHot: false)

    static func decide(_ change: (inout KeepAwakeInputs) -> Void) -> KeepAwakeDecision {
        var input = base
        change(&input)
        return KeepAwakePolicy.decide(input)
    }

    static func main() {
        // A plain session keeps running and never touches system sleep.
        precondition(decide { _ in } == KeepAwakeDecision(endSession: nil, lidGuard: false, lidBlockedBy: nil))

        // Battery cutoff ends the session on battery, not on power, not when off.
        precondition(decide { $0.batteryLevel = 20 }.endSession == .battery)
        precondition(decide { $0.batteryLevel = 20; $0.onBattery = false }.endSession == nil)
        precondition(decide { $0.batteryLevel = 5; $0.batteryThreshold = 0 }.endSession == nil)

        // Starting below the threshold is honoured for the session...
        precondition(decide { $0.batteryLevel = 15; $0.startedBelowThreshold = true }.endSession == nil)
        // ...but never for lid-closed.
        let lowLid = decide { $0.batteryLevel = 15; $0.startedBelowThreshold = true; $0.lidClosedWithSession = true }
        precondition(lowLid.lidGuard == false && lowLid.lidBlockedBy == .battery)

        // Low Power Mode ends the session only when that cutoff is on.
        precondition(decide { $0.lowPowerMode = true }.endSession == .lowPower)
        precondition(decide { $0.lowPowerMode = true; $0.stopInLowPowerMode = false }.endSession == nil)

        // Lid-closed follows the session, and drops when the session ends.
        precondition(decide { $0.lidClosedWithSession = true }.lidGuard)
        precondition(!decide { $0.lidClosedWithSession = true; $0.sessionActive = false }.lidGuard)
        let ended = decide { $0.lidClosedWithSession = true; $0.batteryLevel = 10 }
        precondition(ended.endSession == .battery && !ended.lidGuard)

        // The Claude trigger works with no session, only while Claude works.
        precondition(decide { $0.sessionActive = false; $0.lidClosedWhileClaude = true; $0.claudeWorking = true }.lidGuard)
        precondition(!decide { $0.sessionActive = false; $0.lidClosedWhileClaude = true }.lidGuard)
        precondition(!decide { $0.sessionActive = false; $0.claudeWorking = true }.lidGuard)

        // Heat blocks lid-closed but leaves the session alone.
        let hot = decide { $0.lidClosedWithSession = true; $0.runningHot = true }
        precondition(hot.endSession == nil && !hot.lidGuard && hot.lidBlockedBy == .heat)

        // No blocker is reported when lid-closed was never wanted.
        precondition(decide { $0.runningHot = true }.lidBlockedBy == nil)

        print("KeepAwakePolicyTests passed")
    }
}
