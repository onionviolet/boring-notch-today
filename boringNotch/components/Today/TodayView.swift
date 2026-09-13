import AppKit
import SwiftUI

struct TodayView: View {
    @StateObject private var store = TodayStore.shared
    @State private var actionMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Circle().fill(bridgeColor).frame(width: 6, height: 6)
                Text(bridgeLabel).font(.caption2).foregroundStyle(.secondary)
                Spacer()
            }.padding(.horizontal, 14).padding(.top, 8)
            Group {
                switch store.state {
                case .loading: ProgressView().frame(width: 360, height: 150)
                case .empty: message(icon: "calendar.badge.exclamationmark", title: "Nothing published for Today", detail: "Ask Codex to publish a bounded Today payload.")
                case .malformed(let reason): message(icon: "exclamationmark.triangle", title: "Today data needs attention", detail: reason)
                case .ready(let payload, let isStale): payloadView(payload, isStale: isStale)
                }
            }
        }
        .frame(width: 430)
        .onAppear { store.start() }
    }

    private var bridgeLabel: String {
        if store.refreshPending {
            switch store.bridgeConnection {
            case .connected, .refreshing: return "MCP refresh pending"
            case .disconnected: return "Refresh pending • MCP offline"
            case .stale: return "Refresh pending • MCP heartbeat stale"
            case .error: return "Refresh pending • bridge status invalid"
            }
        }
        switch store.bridgeConnection {
        case .connected: return "MCP live"
        case .refreshing: return "MCP refresh pending"
        case .disconnected: return "MCP offline • file fallback"
        case .stale: return "MCP heartbeat stale • file fallback"
        case .error: return "Bridge status invalid • file fallback"
        }
    }

    private var bridgeColor: Color {
        if store.refreshPending { return .blue }
        switch store.bridgeConnection {
        case .connected: return .green
        case .refreshing: return .blue
        case .disconnected: return .gray
        case .stale: return .orange
        case .error: return .red
        }
    }

    private func message(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(.gray)
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Request refresh") { store.requestRefresh() }.buttonStyle(.bordered)
        }.padding(24)
    }

    private func payloadView(_ payload: TodayPayload, isStale: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Today").font(.headline)
                if isStale { Text("STALE").font(.caption2.weight(.bold)).foregroundStyle(.orange) }
                Spacer()
                Text(payload.generatedAt, style: .time).font(.caption2).foregroundStyle(.secondary)
            }
            if payload.rows.isEmpty {
                Text("No ranked work remains. Keep the win small.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(Array(payload.rows.enumerated()), id: \.element.id) { index, row in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack { Text("\(index + 1). \(row.work)").font(.subheadline.weight(.semibold)); Spacer(); Text(row.time).font(.caption).foregroundStyle(.secondary) }
                        Text("\(row.purpose) • \(row.studyMethod)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Text("Why now: \(row.whyNow)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        Text("Done: \(row.doneWhen) | \(row.basis.rawValue)").font(.caption2).foregroundStyle(.gray).lineLimit(1)
                    }.padding(.vertical, 2)
                }
            }
            if let anki = payload.anki {
                Text(anki.status == .available ? "Anki: \(anki.reviewedToday ?? 0) reviewed, \(anki.newCards ?? 0) new" : "Anki is not running").font(.caption).foregroundStyle(.secondary)
            }
            if let next = payload.next { labeled("Next", next) }
            if let protected = payload.protectedTime { labeled("Protected", protected) }
            if let start = payload.start { labeled("Start", start) }
            HStack {
                ForEach(payload.actions) { action in Button(action.label) { open(action) }.buttonStyle(.bordered) }
                Spacer()
                Button("Refresh") { store.requestRefresh() }.buttonStyle(.bordered)
            }
            if let notice = store.notice { Text(notice).font(.caption2).foregroundStyle(.orange) }
            if let actionMessage { Text(actionMessage).font(.caption2).foregroundStyle(.orange) }
        }.padding(14)
    }

    private func labeled(_ label: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 5) { Text("\(label):").font(.caption.weight(.semibold)); Text(text).font(.caption).foregroundStyle(.secondary) }
    }

    private func open(_ action: TodayAction) {
        guard (try? action.validate()) != nil else { return }
        switch action.kind {
        case .source:
            if let url = action.url.flatMap(URL.init(string:)) { NSWorkspace.shared.open(url) }
        case .itembank:
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "dev.itembank") else {
                actionMessage = "Itembank is not installed."
                return
            }
            NSWorkspace.shared.openApplication(at: appURL, configuration: .init()) { _, error in
                Task { @MainActor in actionMessage = error.map { "Could not open Itembank: \($0.localizedDescription)" } }
            }
        }
    }
}
