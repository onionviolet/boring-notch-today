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
                    .help(bridgeDetail)
                Spacer()
            }.padding(.horizontal, 14).padding(.top, 8)
            Group {
                switch store.state {
                case .loading: ProgressView().frame(width: 360, height: 150)
                case .empty: message(icon: "calendar.badge.exclamationmark", title: "Nothing published for Today", detail: "Ask Codex to publish your Today plan.")
                case .malformed(let reason): message(icon: "exclamationmark.triangle", title: "Today data needs attention", detail: reason)
                case .ready(let payload, let isStale): payloadView(payload, isStale: isStale)
                }
            }
        }
        // Fit the space below the notch header so the scroll viewport stays inside the panel.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { store.start() }
    }

    private var bridgeLabel: String {
        if store.refreshPending { return "Refresh requested, waiting for agent" }
        switch store.bridgeConnection {
        case .connected: return "Connected"
        case .refreshing: return "Refresh requested, waiting for agent"
        case .disconnected: return "Offline • saved plan"
        case .stale: return "Connection inactive • saved plan"
        case .error: return "Connection needs attention • saved plan"
        }
    }

    private var bridgeDetail: String {
        let connection: String
        switch store.bridgeConnection {
        case .connected, .refreshing: connection = "A local MCP transport is connected."
        case .disconnected: connection = "The local MCP transport is offline."
        case .stale: connection = "The local MCP heartbeat is stale."
        case .error: connection = "The bridge status record was rejected."
        }
        return connection + " Refresh requests need an active agent to publish a new plan."
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
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Today").font(.headline)
                    if isStale { Text("STALE").font(.caption2.weight(.bold)).foregroundStyle(.orange) }
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(updateLabel(payload.generatedAt, at: context.date))
                            .font(.caption2).foregroundStyle(.secondary)
                            .help(payload.generatedAt.formatted(date: .complete, time: .shortened))
                    }
                }
                if let start = payload.start {
                    HStack(alignment: .top, spacing: 5) {
                        Text("Start:").font(.caption.weight(.semibold))
                        Text(start).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(2).help(start)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            Divider()
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 9) {
                    if payload.rows.isEmpty {
                        Text("No ranked work remains. Keep the win small.").font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(payload.rows.enumerated()), id: \.element.id) { index, row in
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 4) {
                                    labeled("Purpose", row.purpose)
                                    labeled("Method", row.studyMethod)
                                    labeled("Why now", row.whyNow)
                                    labeled("Done", row.doneWhen)
                                    Text(row.basis.rawValue).font(.caption2).foregroundStyle(.secondary)
                                }.padding(.top, 4)
                            } label: {
                                HStack(alignment: .top) {
                                    Text("\(index + 1). \(row.work)")
                                        .font(.subheadline.weight(.semibold))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 8)
                                    Text(row.time)
                                        .font(.caption).foregroundStyle(.secondary)
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: 150, alignment: .trailing)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }.padding(.vertical, 2)
                        }
                    }
                    if let anki = payload.anki {
                        Text(anki.status == .available ? "Anki: \(anki.reviewedToday ?? 0) reviewed, \(anki.newCards ?? 0) new" : "Anki is not running").font(.caption).foregroundStyle(.secondary)
                    }
                    if let next = payload.next { labeled("Next", next) }
                    if let protected = payload.protectedTime { labeled("Protected", protected) }
                    HStack {
                        ForEach(payload.actions) { action in Button(action.label) { open(action) }.buttonStyle(.bordered) }
                        Spacer()
                        Button(store.refreshPending ? "Requested" : "Refresh") { store.requestRefresh() }
                            .buttonStyle(.bordered).disabled(store.refreshPending)
                            .help("Request a new plan from an active agent.")
                    }
                    if let notice = store.notice { Text(notice).font(.caption2).foregroundStyle(.orange) }
                    if let actionMessage { Text(actionMessage).font(.caption2).foregroundStyle(.orange) }
                }
                .padding(14)
                .background(TodayScrollPositionKeeper(defaultsKey: "today.scrollOffset"))
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func updateLabel(_ date: Date, at now: Date) -> String {
        let calendar = Calendar.current
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday, " + date.formatted(date: .omitted, time: .shortened)
        }
        if !calendar.isDate(date, inSameDayAs: now) {
            return "Updated " + date.formatted(date: .abbreviated, time: .shortened)
        }
        let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
        if minutes < 1 { return "Updated just now" }
        if minutes < 60 { return "Updated \(minutes) min ago" }
        let hours = minutes / 60
        return "Updated \(hours) \(hours == 1 ? "hour" : "hours") ago"
    }

    private func labeled(_ label: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Text("\(label):").font(.caption.weight(.semibold))
            Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
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

private struct TodayScrollPositionKeeper: NSViewRepresentable {
    let defaultsKey: String

    func makeCoordinator() -> Coordinator { Coordinator(defaultsKey: defaultsKey) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { context.coordinator.attach(to: view) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { context.coordinator.attach(to: view) }
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        private let defaultsKey: String
        private weak var scrollView: NSScrollView?
        private var boundsObserver: NSObjectProtocol?

        init(defaultsKey: String) {
            self.defaultsKey = defaultsKey
        }

        func attach(to view: NSView) {
            guard let enclosingScrollView = enclosingScrollView(for: view), scrollView !== enclosingScrollView else { return }
            detach()
            scrollView = enclosingScrollView

            let clipView = enclosingScrollView.contentView
            if let savedOffset = UserDefaults.standard.object(forKey: defaultsKey) as? NSNumber {
                clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: savedOffset.doubleValue))
                enclosingScrollView.reflectScrolledClipView(clipView)
            }
            clipView.postsBoundsChangedNotifications = true
            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [defaultsKey] notification in
                guard let clipView = notification.object as? NSClipView else { return }
                UserDefaults.standard.set(clipView.bounds.origin.y, forKey: defaultsKey)
            }
        }

        func detach() {
            if let scrollView {
                UserDefaults.standard.set(scrollView.contentView.bounds.origin.y, forKey: defaultsKey)
            }
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }
            boundsObserver = nil
            scrollView = nil
        }

        private func enclosingScrollView(for view: NSView) -> NSScrollView? {
            var ancestor = view.superview
            while let current = ancestor {
                if let scrollView = current as? NSScrollView { return scrollView }
                ancestor = current.superview
            }
            return nil
        }
    }
}
