//
//  BatterySettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import Defaults
import SwiftUI

struct BatterySettingsView: View {
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .showBatteryIndicator) {
                    Text("Show battery indicator")
                }
                Defaults.Toggle(key: .showPowerStatusNotifications) {
                    Text("Show power status notifications")
                }
            } header: {
                Text("General")
            }
            Section {
                Defaults.Toggle(key: .showBatteryPercentage) {
                    Text("Show battery percentage")
                }
                Defaults.Toggle(key: .showPowerStatusIcons) {
                    Text("Show power status icons")
                }
                Defaults.Toggle(key: .showChargingWattage) {
                    Text("Show charging wattage")
                }
            } header: {
                Text("Battery Information")
            }
            KeepAwakeSettingsSection()
        }
        .onAppear {
            Task { @MainActor in
                await XPCHelperClient.shared.isAccessibilityAuthorized()
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Battery")
    }
}

private struct KeepAwakeSettingsSection: View {
    @ObservedObject private var manager = KeepAwakeManager.shared
    @Default(.keepAwakeDefaultMinutes) private var defaultMinutes
    @Default(.keepAwakeBatteryThreshold) private var batteryThreshold

    var body: some View {
        Section {
            Defaults.Toggle(key: .showKeepAwakeButton) {
                Text("Show keep-awake button in the notch")
            }
            Picker("Click keeps the Mac awake for", selection: $defaultMinutes) {
                Text("15 minutes").tag(15)
                Text("1 hour").tag(60)
                Text("2 hours").tag(120)
                Text("4 hours").tag(240)
                Text("Until stopped").tag(0)
            }
            Defaults.Toggle(key: .keepAwakeAllowDisplaySleep) {
                Text("Let the display sleep")
            }
            Picker("Stop on battery at", selection: $batteryThreshold) {
                Text("Never").tag(0)
                Text("10%").tag(10)
                Text("20%").tag(20)
                Text("30%").tag(30)
                Text("50%").tag(50)
            }
            Defaults.Toggle(key: .keepAwakeStopInLowPower) {
                Text("Stop in Low Power Mode")
            }
        } header: {
            Text("Keep Awake")
        }
        Section {
            Defaults.Toggle(key: .keepAwakeLidClosed) {
                Text("Also keep awake with the lid closed")
            }
            Defaults.Toggle(key: .keepAwakeLidClosedWhileClaude) {
                Text("Keep awake with the lid closed while Claude or Codex works")
            }
            HStack {
                Text("Setup")
                Spacer()
                Text(setupText)
                    .foregroundStyle(manager.lidGuardSetup == .ready ? Color.secondary : Color.orange)
                setupButton
            }
        } header: {
            Text("Lid Closed")
        } footer: {
            Text("Turns system sleep off, which needs a one-time root setup: Set Up asks for your administrator password once. \"While Claude or Codex works\" follows the desktop apps and the claude and codex CLIs while a turn runs. Pauses when the Mac runs hot, in Low Power Mode or at the battery cutoff, and turns back on by itself if Boring Notch quits. Don't pack a closed, awake Mac in a bag.")
                .foregroundStyle(.secondary)
        }
        .onAppear {
            Task { await manager.refreshSetup() }
        }
        LidFadeSettingsSection()
    }

    @ViewBuilder
    private var setupButton: some View {
        switch manager.lidGuardSetup {
        case .ready:
            Button("Remove") {
                Task { await manager.configureSetup(install: false) }
            }
            .disabled(manager.setupBusy)
        case .unknown:
            Button("Recheck") {
                Task { await manager.refreshSetup() }
            }
        case .notInstalled, .insecure, .noSudoRule:
            Button(manager.lidGuardSetup == .notInstalled ? "Set Up…" : "Repair…") {
                Task { await manager.configureSetup(install: true) }
            }
            .disabled(manager.setupBusy)
        }
    }

    private var setupText: String {
        switch manager.lidGuardSetup {
        case .ready: manager.lidGuardEngaged ? "Ready, sleep is off now" : "Ready"
        case .notInstalled: "Script not installed"
        case .insecure: "Script not root-owned, refused"
        case .noSudoRule: "Sudoers rule missing"
        case .unknown: "Checking…"
        }
    }
}

private struct LidFadeSettingsSection: View {
    @ObservedObject private var fade = LidFadeController.shared
    @Default(.lidFadeEnabled) private var enabled

    var body: some View {
        Section {
            Defaults.Toggle(key: .lidFadeEnabled) {
                Text("Fade the screen as the lid closes")
            }
            if enabled && fade.sensorAvailable == false {
                Text("This Mac's lid-angle sensor can't be read, so the fade stays off.")
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Lid Fade")
        } footer: {
            Text("Dims the built-in screen to black between about 50° and 12° and brightens it again as you open the lid. Reads the hinge sensor four times a second while the lid is open or shut, faster only while it moves through the fade.")
                .foregroundStyle(.secondary)
        }
    }
}
