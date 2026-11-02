//
//  KeepAwakeButton.swift
//  boringNotch
//
//  The cup in the open notch's header. Click toggles keep-awake for the
//  default duration; right-click picks a duration, the lid-closed modes and
//  the lid fade.
//

import Defaults
import SwiftUI

struct KeepAwakeButton: View {
    @ObservedObject private var manager = KeepAwakeManager.shared
    @Default(.keepAwakeLidClosed) private var lidClosed
    @Default(.keepAwakeLidClosedWhileClaude) private var lidClosedWhileAgent
    @Default(.lidFadeEnabled) private var lidFade

    var body: some View {
        Button {
            manager.toggle()
        } label: {
            Capsule()
                .fill(.black)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: manager.isActive || manager.lidGuardEngaged ? "cup.and.saucer.fill" : "cup.and.saucer")
                        .foregroundColor(tint)
                        .imageScale(.medium)
                }
        }
        .buttonStyle(PlainButtonStyle())
        .help(statusText)
        .accessibilityLabel(Text("Keep awake"))
        .accessibilityValue(Text(statusText))
        .contextMenu { menu }
    }

    /// White while idle keep-awake runs, orange while system sleep is off,
    /// so the riskier mode is never mistaken for the safe one.
    private var tint: Color {
        if manager.lidGuardEngaged { return .orange }
        if manager.isActive { return .white }
        return .gray
    }

    private var statusText: String {
        var parts: [String] = []
        if manager.isActive {
            if let end = manager.endsAt {
                parts.append("Awake until \(end.formatted(date: .omitted, time: .shortened))")
            } else {
                parts.append("Awake until stopped")
            }
        } else if let stop = manager.lastStop {
            parts.append("Stopped: \(stop.label)")
        } else {
            parts.append("Keep awake off")
        }
        if manager.lidGuardEngaged {
            parts.append(manager.agentWorking && !manager.isActive ? "lid closed OK while an agent works" : "lid closed OK")
        } else if let blocked = manager.lidBlockedBy {
            parts.append("lid-closed paused: \(blocked.label)")
        } else if (lidClosed || lidClosedWhileAgent) && manager.lidGuardSetup != .ready {
            parts.append("lid-closed needs setup")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var menu: some View {
        Text(statusText)
        Divider()
        Button("15 minutes") { manager.activate(minutes: 15) }
        Button("1 hour") { manager.activate(minutes: 60) }
        Button("2 hours") { manager.activate(minutes: 120) }
        Button("4 hours") { manager.activate(minutes: 240) }
        Button("Until stopped") { manager.activate(minutes: 0) }
        if manager.isActive {
            Button("Stop") { manager.deactivate() }
        }
        Divider()
        Toggle("Also with lid closed", isOn: $lidClosed)
        Toggle("Lid closed while Claude or Codex works", isOn: $lidClosedWhileAgent)
        Toggle("Fade screen as lid closes", isOn: $lidFade)
        Divider()
        Button("Keep Awake Settings…") {
            SettingsWindowController.shared.showWindow()
        }
    }
}
