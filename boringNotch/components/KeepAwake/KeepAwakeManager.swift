//
//  KeepAwakeManager.swift
//  boringNotch
//
//  Amphetamine-style keep-awake for the notch. Two layers:
//
//  - Idle keep-awake: an in-process power assertion, the same thing
//    KeepingYouAwake gets from `caffeinate -w`. macOS drops it if the app
//    dies, so it can never get stuck on.
//  - Lid-closed keep-awake: `pmset disablesleep`, which needs root. The
//    sandboxed app asks its XPC helper, which runs a root-owned script
//    through a narrow sudoers rule. That script's watchdog turns sleep back
//    on if the app exits; the launch reset below covers a reboot.
//
//  The cutoff rules live in KeepAwakePolicy so they can be tested alone.
//

import Combine
import Defaults
import Foundation
import IOKit.pwr_mgt

@MainActor
final class KeepAwakeManager: ObservableObject {
    static let shared = KeepAwakeManager()

    /// A manual session is running.
    @Published private(set) var isActive = false
    /// When the manual session ends; nil while it runs until stopped.
    @Published private(set) var endsAt: Date?
    /// System sleep is currently off because of this app.
    @Published private(set) var lidGuardEngaged = false
    @Published private(set) var claudeWorking = false
    @Published private(set) var lidGuardSetup: LidGuardSetup = .unknown
    /// Lid-closed keep-awake is wanted right now but a cutoff blocks it.
    @Published private(set) var lidBlockedBy: KeepAwakeStopReason?
    /// Why the last session ended on its own, shown until the next start.
    @Published private(set) var lastStop: KeepAwakeStopReason?

    private var assertionIDs: [IOPMAssertionID] = []
    private var startedBelowThreshold = false
    private var expiryTimer: Timer?
    private var pollTimer: Timer?
    private var claudeLastSeen: Date?
    private var lidGuardBusy = false
    private var started = false
    private var cancellables: Set<AnyCancellable> = []

    /// Claude lets go of its own assertion shortly after a turn ends; this
    /// grace keeps a short pause between turns from cycling system sleep.
    private let claudeGrace: TimeInterval = 90
    private let pollInterval: TimeInterval = 15

    private init() {}

    /// Called once at launch.
    func start() {
        guard !started else { return }
        started = true

        let battery = BatteryStatusViewModel.shared
        battery.$levelBattery.removeDuplicates().sink { [weak self] _ in self?.scheduleEvaluate() }.store(in: &cancellables)
        battery.$isPluggedIn.removeDuplicates().sink { [weak self] _ in self?.scheduleEvaluate() }.store(in: &cancellables)
        battery.$isInLowPowerMode.removeDuplicates().sink { [weak self] _ in self?.scheduleEvaluate() }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in self?.scheduleEvaluate() }
            .store(in: &cancellables)
        for key in [Defaults.Keys.keepAwakeLidClosed, .keepAwakeLidClosedWhileClaude, .keepAwakeStopInLowPower] {
            Defaults.publisher(key).sink { [weak self] _ in self?.scheduleEvaluate() }.store(in: &cancellables)
        }
        Defaults.publisher(.keepAwakeBatteryThreshold).sink { [weak self] _ in self?.scheduleEvaluate() }.store(in: &cancellables)
        Defaults.publisher(.keepAwakeAllowDisplaySleep).sink { [weak self] _ in
            Task { @MainActor in self?.refreshAssertions() }
        }.store(in: &cancellables)

        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.poll() }
        }

        Task {
            // A crash or forced quit last time can leave sleep off until the
            // watchdog notices; a reboot leaves it off for good. Turn it back
            // on before anything else.
            if Defaults[.keepAwakeLidGuardOwned] {
                if await XPCHelperClient.shared.setLidGuard(false) {
                    Defaults[.keepAwakeLidGuardOwned] = false
                }
            }
            await refreshSetup()
            await poll()
        }
    }

    /// Called from applicationWillTerminate. The script's watchdog turns
    /// sleep back on within seconds even if this call never lands.
    func shutdown() {
        releaseAssertions()
        if lidGuardEngaged || Defaults[.keepAwakeLidGuardOwned] {
            Task { _ = await XPCHelperClient.shared.setLidGuard(false) }
        }
    }

    // MARK: - Session

    /// Starts a session; `minutes` of nil or 0 runs until stopped.
    func activate(minutes: Int? = nil) {
        let minutes = minutes ?? Defaults[.keepAwakeDefaultMinutes]
        let battery = BatteryStatusViewModel.shared
        let threshold = Defaults[.keepAwakeBatteryThreshold]
        startedBelowThreshold = !battery.isPluggedIn && threshold > 0 && Int(battery.levelBattery) <= threshold

        isActive = true
        lastStop = nil
        refreshAssertions()

        expiryTimer?.invalidate()
        expiryTimer = nil
        if minutes > 0 {
            let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
            endsAt = end
            expiryTimer = Timer.scheduledTimer(withTimeInterval: end.timeIntervalSinceNow, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.deactivate() }
            }
        } else {
            endsAt = nil
        }
        evaluate()
    }

    func deactivate(reason: KeepAwakeStopReason? = nil) {
        isActive = false
        endsAt = nil
        expiryTimer?.invalidate()
        expiryTimer = nil
        lastStop = reason
        releaseAssertions()
        evaluate()
    }

    func toggle() {
        isActive ? deactivate() : activate()
    }

    func refreshSetup() async {
        lidGuardSetup = await XPCHelperClient.shared.lidGuardSetupStatus()
        evaluate()
    }

    // MARK: - Assertions

    private func refreshAssertions() {
        releaseAssertions()
        guard isActive else { return }
        var types = [kIOPMAssertionTypePreventUserIdleSystemSleep]
        if !Defaults[.keepAwakeAllowDisplaySleep] {
            types.append(kIOPMAssertionTypePreventUserIdleDisplaySleep)
        }
        for type in types {
            var id = IOPMAssertionID(0)
            let result = IOPMAssertionCreateWithName(
                type as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Boring Notch keep awake" as CFString,
                &id
            )
            if result == kIOReturnSuccess {
                assertionIDs.append(id)
            }
        }
    }

    private func releaseAssertions() {
        for id in assertionIDs {
            IOPMAssertionRelease(id)
        }
        assertionIDs.removeAll()
    }

    // MARK: - Evaluation

    private func poll() async {
        if Defaults[.keepAwakeLidClosedWhileClaude] {
            if await XPCHelperClient.shared.isClaudeWorking() {
                claudeLastSeen = Date()
            }
        } else {
            claudeLastSeen = nil
        }
        evaluate()
    }

    /// Publisher sinks fire during view updates; hop off them first.
    private func scheduleEvaluate() {
        Task { @MainActor in self.evaluate() }
    }

    private func evaluate() {
        claudeWorking = claudeLastSeen.map { Date().timeIntervalSince($0) < claudeGrace } ?? false

        let battery = BatteryStatusViewModel.shared
        let thermal = ProcessInfo.processInfo.thermalState
        let decision = KeepAwakePolicy.decide(KeepAwakeInputs(
            sessionActive: isActive,
            lidClosedWithSession: Defaults[.keepAwakeLidClosed],
            lidClosedWhileClaude: Defaults[.keepAwakeLidClosedWhileClaude],
            claudeWorking: claudeWorking,
            onBattery: !battery.isPluggedIn,
            batteryLevel: Int(battery.levelBattery),
            batteryThreshold: Defaults[.keepAwakeBatteryThreshold],
            startedBelowThreshold: startedBelowThreshold,
            lowPowerMode: battery.isInLowPowerMode,
            stopInLowPowerMode: Defaults[.keepAwakeStopInLowPower],
            runningHot: thermal == .serious || thermal == .critical
        ))

        if let reason = decision.endSession {
            // deactivate() evaluates again with the session off.
            deactivate(reason: reason)
            return
        }
        lidBlockedBy = decision.lidBlockedBy

        // Never ask for the lid guard until setup is confirmed, but always
        // allow turning it off.
        let wantLidGuard = decision.lidGuard && lidGuardSetup == .ready
        syncLidGuard(wantLidGuard)
    }

    private func syncLidGuard(_ want: Bool) {
        guard want != lidGuardEngaged, !lidGuardBusy else { return }
        lidGuardBusy = true
        Task {
            let ok = await XPCHelperClient.shared.setLidGuard(want)
            if ok {
                lidGuardEngaged = want
                Defaults[.keepAwakeLidGuardOwned] = want
            } else if want {
                // The rule or script changed under us; recheck before retrying.
                lidGuardSetup = await XPCHelperClient.shared.lidGuardSetupStatus()
            }
            lidGuardBusy = false
            // Settle any change that arrived while the call was in flight.
            if ok { evaluate() }
        }
    }
}
