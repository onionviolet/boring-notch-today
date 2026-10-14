import AppKit
import SwiftUI

struct TodayView: View {
    @StateObject private var store = TodayStore.shared
    @State private var actionMessage: String?
    @State private var expandedRows: Set<String> = []
    @State private var showQuietSettings = false

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
            if let focus = store.focus {
                HStack {
                    Text(focus.endsAt <= store.now ? "Focus session finished: \(focus.work)" : "Focus: \(focus.work) · \(store.focusRemaining ?? "")")
                        .font(.caption).lineLimit(1)
                    Spacer()
                    Button(focus.endsAt <= store.now ? "Clear" : "Stop") { store.stopFocus() }
                }.padding(.horizontal, 14).padding(.bottom, 6)
            }
            Divider()
            ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 9) {
                    if !store.reminders.isEmpty {
                        TodayReminderBanner { rowID in
                            store.selectedRowID = rowID
                            store.dismissReminders()
                        }
                    }
                    if payload.rows.isEmpty {
                        Text("No ranked work remains. Keep the win small.").font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(payload.rows.enumerated()), id: \.element.id) { index, row in
                            DisclosureGroup(isExpanded: Binding(
                                get: { expandedRows.contains(row.id) },
                                set: { if $0 { expandedRows.insert(row.id) } else { expandedRows.remove(row.id) } }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    labeled("Purpose", row.purpose)
                                    labeled("Method", row.studyMethod)
                                    labeled("Why now", row.whyNow)
                                    labeled("Done", row.doneWhen)
                                    if let deadline = payload.deadlines?.first(where: { $0.rowID == row.id }) {
                                        Text("\(deadline.required ? "Required" : "Optional") · Due \(deadline.dueAt.formatted(date: .abbreviated, time: .shortened)) · \(TodaySchedule.countdown(to: deadline.dueAt, at: store.now))")
                                            .font(.caption).foregroundStyle(.orange)
                                        if let action = payload.actions.first(where: { $0.id == deadline.actionID }) {
                                            Button("Open submission site") { open(action) }.buttonStyle(.bordered)
                                        }
                                    }
                                    Button("Focus for 25 minutes") { store.startFocus(row: row) }.buttonStyle(.bordered)
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
                            }.padding(.vertical, 2).id(row.id)
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
                        Button { showQuietSettings.toggle() } label: { Image(systemName: "moon") }
                            .help("Quiet hours").popover(isPresented: $showQuietSettings) { TodayQuietSettings() }
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
            .onAppear {
                if let id = store.selectedRowID { expandedRows.insert(id); proxy.scrollTo(id, anchor: .top); store.selectedRowID = nil }
            }
            .onChange(of: store.selectedRowID) { _, id in
                if let id { expandedRows.insert(id); proxy.scrollTo(id, anchor: .top); store.selectedRowID = nil }
            }
            }
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


struct TodayReminderBanner: View {
    @ObservedObject var store = TodayStore.shared
    let openToday: (String) -> Void

    private var grouped: [TodayDueReminder] {
        var seen: Set<String> = []
        return store.reminders.sorted { $0.deadline.required && !$1.deadline.required }
            .filter { seen.insert($0.deadline.id).inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(grouped) { item in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(item.deadline.required ? "Required" : "Optional"): \(item.row.work)")
                            .font(.caption.weight(.semibold)).lineLimit(1).help(item.row.work)
                        Text(item.deadline.dueAt <= store.now ? "Deadline passed · \(item.deadline.dueAt.formatted(date: .omitted, time: .shortened))" : "Due \(item.deadline.dueAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Today") { openToday(item.row.id) }
                    if let action = source(for: item) {
                        Button("Site") {
                            if let url = action.url.flatMap(URL.init(string:)) { NSWorkspace.shared.open(url) }
                        }
                    }
                }
            }
            if store.reminders.contains(where: { $0.reminder.kind == .checkpoint }) {
                Text("Check required files and the final submission receipt.").font(.caption2).foregroundStyle(.orange)
            }
            HStack {
                Button("Snooze 10 min") { store.snoozeReminders() }
                Button("Dismiss") { store.dismissReminders() }
            }
        }.buttonStyle(.bordered).padding(10).frame(width: 580, alignment: .leading)
    }

    private func source(for item: TodayDueReminder) -> TodayAction? {
        guard case .ready(let payload, _) = store.state else { return nil }
        return payload.actions.first { $0.id == item.deadline.actionID && $0.kind == .source }
    }
}

private struct TodayQuietSettings: View {
    @AppStorage("today.quiet.enabled") private var enabled = false
    @AppStorage("today.quiet.start") private var start = 1320
    @AppStorage("today.quiet.end") private var end = 480
    @AppStorage("today.quiet.allowRequired") private var allowRequired = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Quiet hours", isOn: $enabled)
            HStack {
                Picker("From", selection: $start) { times }
                Picker("Until", selection: $end) { times }
            }
            Toggle("Allow required deadline alerts during quiet hours", isOn: $allowRequired)
            Text("Optional work stays quiet. Equal times silence routine alerts all day.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding().frame(width: 350)
    }

    private var times: some View {
        ForEach(Array(stride(from: 0, to: 1440, by: 30)), id: \.self) { minute in
            Text(String(format: "%02d:%02d", minute / 60, minute % 60)).tag(minute)
        }
    }
}


/// A glance occupies only the wings alongside the hardware notch, never a lower banner.
struct TodayNotchGlance: View {
    @ObservedObject var store = TodayStore.shared
    let notchWidth: CGFloat
    let height: CGFloat
    let openToday: (String) -> Void

    private var reminder: TodayDueReminder? { store.reminders.first }
    private var rowID: String? { reminder?.row.id ?? store.focus?.rowID ?? store.upcomingDeadline?.rowID }
    private var title: String { reminder?.row.work ?? store.focus?.work ?? store.upcomingWork ?? "Today" }
    private var status: String {
        if reminder != nil { return "Reminder" }
        if let focus = store.focus { return focus.endsAt <= store.now ? "Focus done" : store.focusRemaining ?? "Focus" }
        if let due = store.upcomingDeadline { return TodaySchedule.countdown(to: due.dueAt, at: store.now).replacingOccurrences(of: " left", with: "") }
        return "Today"
    }

    var body: some View {
        Button {
            if let rowID { openToday(rowID) }
        } label: {
            HStack(spacing: 0) {
                Text(title)
                    .frame(width: 90, alignment: .leading)
                Color.clear.frame(width: notchWidth + 10)
                Text(status)
                    .monospacedDigit()
                    .foregroundStyle(reminder != nil ? .orange : .secondary)
                    .frame(width: 90, alignment: .trailing)
            }
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title + " · " + status + ". Open Today for details.")
        .accessibilityLabel(title + ", " + status + ", open Today")
    }
}
