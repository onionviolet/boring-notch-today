import AppKit
import SwiftUI

struct TodayView: View {
    @ObservedObject var store = TodayStore.shared
    var startsStore = true
    var previewPreferences: TodayPresentationPreferences? = nil
    var scrollDefaults: UserDefaults = .standard
    @AppStorage("today.focus.duration") var focusDuration = "25"
    @AppStorage("today.presentation") var presentation = "all"
    @AppStorage("today.density") var density = "current"
    @AppStorage("today.reminder.prominence") var prominence = "standard"
    @State private var revealedRows: Set<String> = []

    private var preferences: TodayPresentationPreferences {
        previewPreferences ?? .init(duration: focusDuration, presentation: presentation, density: density, prominence: prominence)
    }
    private var retainedRows: Set<String> {
        revealedRows.union(store.focus.map { [$0.rowID] } ?? [])
            .union(store.reminders.map { $0.row.id }).union(store.selectedRowID.map { [$0] } ?? [])
    }
    @State private var actionMessage: String?
    // Expanded rows outlive the view: the notch tears TodayView down on close.
    @State private var expandedRows: Set<String> = []
    private static let expandedKey = "today.expandedRows"
    @State private var showQuietSettings = false
    @State private var showPlanDetails = false
    @State private var showStartDetails = false
    @State private var showUpcoming = false

    var body: some View {
        VStack(spacing: 0) {
            planHeader
            Group {
                switch store.state {
                case .loading: ProgressView().frame(width: 360, height: 150)
                case .empty: message(icon: "calendar.badge.exclamationmark", title: "Nothing published for Today", detail: "Ask Codex to publish your Today plan.")
                case .malformed(let reason): message(icon: "exclamationmark.triangle", title: "Today data needs attention", detail: reason)
                case .ready(let payload, let isStale):
                    if showUpcoming, let next = payload.next {
                        upcomingView(next)
                    } else {
                        payloadView(payload, isStale: isStale)
                    }
                }
            }
        }
        // Fit the space below the notch header so the scroll viewport stays inside the panel.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if startsStore { store.start() }
            expandedRows.formUnion(scrollDefaults.stringArray(forKey: Self.expandedKey) ?? [])
        }
        .onChange(of: expandedRows) { _, rows in
            scrollDefaults.set(Array(rows).sorted(), forKey: Self.expandedKey)
        }
        .onChange(of: store.selectedRowID) { _, id in
            if id != nil { showUpcoming = false }
        }
    }

    private var planHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Today").font(.headline)
                if case .ready(let payload, let isStale) = store.state {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        let label = updateLabel(payload.generatedAt, at: context.date)
                        Text(store.showingPreviousPlan ? "Showing previous plan · \(label)" :
                             isStale ? "Stale plan · \(label)" : label)
                            .font(.caption).foregroundStyle(isStale || store.showingPreviousPlan ? Color.orange : Color.secondary)
                            .lineLimit(1)
                            .help(payload.generatedAt.formatted(date: .complete, time: .shortened))
                    }
                }
                Spacer(minLength: 4)
                if case .ready(let payload, _) = store.state, payload.next != nil {
                    Button {
                        showUpcoming.toggle()
                    } label: {
                        Label(showUpcoming ? "Back to tasks" : "Upcoming",
                              systemImage: showUpcoming ? "chevron.left" : "calendar")
                    }
                    .help(showUpcoming ? "Return to the task list" : "Show upcoming dates and milestones")
                }
                Button(store.refreshPending ? "Requested" : "Request refresh") { store.requestRefresh() }
                    .disabled(store.refreshPending || store.state == .loading)
                    .help("Ask an active agent to publish a new plan.")
                Button {
                    showPlanDetails.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("Today connection details")
                .popover(isPresented: $showPlanDetails) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Today connection").font(.headline)
                        Text(bridgeDetail)
                        if let requestedAt = store.refreshRequestedAt {
                            Text("Requested \(requestedAt.formatted(date: .abbreviated, time: .shortened))")
                        }
                        Text("An active agent needs to pick up the request and publish a plan.")
                            .foregroundStyle(.secondary)
                        if let revision = Bundle.main.object(forInfoDictionaryKey: "BNSourceRevision") as? String,
                           !revision.isEmpty {
                            Text("Build \(revision)").textSelection(.enabled)
                        }
                    }
                    .font(.caption).padding(12).frame(width: 260, alignment: .leading)
                }
            }
            .buttonStyle(.bordered)
            if store.refreshPending {
                Text("Waiting for an agent").font(.caption).foregroundStyle(.secondary)
            }
            if let issue = store.refreshIssue {
                Text(issue).font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 4)
    }

    private var bridgeDetail: String {
        switch store.bridgeConnection {
        case .connected, .refreshing: return "A local MCP transport is connected."
        case .disconnected: return "The local MCP transport is offline."
        case .stale: return "The local MCP heartbeat is stale."
        case .error: return "The bridge status record was rejected."
        }
    }

    private func message(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(.gray)
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(24)
    }

    private func upcomingView(_ next: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Upcoming").font(.subheadline.weight(.semibold))
                Text(next)
                    .font(.callout)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }

    private func payloadView(_ payload: TodayPayload, isStale: Bool) -> some View {
        let visibleRows = preferences.rows(in: payload, retained: retainedRows)
        let hiddenCount = payload.rows.count - visibleRows.count
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if let start = payload.start {
                    Button {
                        showStartDetails.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle").foregroundStyle(.tint)
                            Text("Start").fontWeight(.semibold).fixedSize()
                            Text(start).lineLimit(1).foregroundStyle(.secondary)
                            Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .layoutPriority(1)
                    .accessibilityLabel("Start: \(start)")
                    .accessibilityHint("Show the full start instruction")
                    .help(start)
                    .popover(isPresented: $showStartDetails) {
                        Text(start).font(.callout).textSelection(.enabled)
                            .padding(12).frame(width: 300, alignment: .leading)
                    }
                }
                Spacer(minLength: 0)
                if let deadline = store.upcomingDeadline, deadline.required,
                   let row = payload.rows.first(where: { $0.id == deadline.rowID }) {
                    Button {
                        store.selectedRowID = row.id
                    } label: {
                        Label("Due \(deadline.dueAt.formatted(.dateTime.month(.abbreviated).day()))",
                              systemImage: "calendar")
                            .font(.caption)
                            .fixedSize()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Next deadline: \(row.work), due \(deadline.dueAt.formatted(date: .abbreviated, time: .shortened))")
                    .accessibilityHint("Reveal the task card")
                    .help("\(row.work) · \(deadline.dueAt.formatted(date: .abbreviated, time: .shortened))")
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            if let focus = store.focus {
                let finished = focus.endsAt <= store.now
                HStack(spacing: 6) {
                    Text(finished ? "Focus finished" : "Focus")
                        .font(.caption.weight(.semibold)).fixedSize()
                    Text(focus.work).font(.caption).lineLimit(1)
                    Spacer(minLength: 4)
                    if !finished, let remaining = store.focusRemaining {
                        Text(remaining).font(.caption.monospacedDigit()).fixedSize()
                            .accessibilityLabel("Focus time remaining: \(remaining)")
                    }
                    Button(finished ? "Clear" : "Stop") { store.stopFocus() }
                }.padding(.horizontal, 14).padding(.bottom, 6)
            }
            Divider()
            ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: preferences.compact ? 5 : 9) {
                    if !store.reminders.isEmpty {
                        TodayReminderBanner(store: store, subtle: preferences.subtleReminders) { rowID in
                            store.selectedRowID = rowID
                            store.dismissReminders()
                        }
                    }
                    if preferences.requiredOnly {
                        Text(hiddenCount > 0 ? "Required-only · \(hiddenCount) optional \(hiddenCount == 1 ? "row hidden" : "rows hidden")" : "Required-only · work without deadlines and active targets kept")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if visibleRows.isEmpty && !payload.rows.isEmpty {
                        Text("No work matches Required-only. Switch to All to see optional deadline work.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if payload.rows.isEmpty {
                        Text("No tasks in this plan.").font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(payload.rows.enumerated()).filter { visibleRows.contains($0.element) }, id: \.element.id) { index, row in
                            let deadlines = preferences.deadlines(for: row.id, in: payload,
                                retainedRows: revealedRows.union(store.focus.map { [$0.rowID] } ?? []),
                                reminderIDs: Set(store.reminders.map { $0.deadline.id }))
                            let nextDeadline = deadlines.filter { $0.dueAt > store.now }.min { $0.dueAt < $1.dueAt }
                            DisclosureGroup(isExpanded: Binding(
                                get: { expandedRows.contains(row.id) },
                                set: { if $0 { expandedRows.insert(row.id) } else { expandedRows.remove(row.id) } }
                            )) {
                                VStack(alignment: .leading, spacing: 9) {
                                    taskSteps(row.studyMethod)
                                    HStack(spacing: 8) {
                                        Button(preferences.focusActionLabel) { store.startFocus(row: row) }
                                            .buttonStyle(.bordered)
                                        ForEach(payload.actions.filter { action in deadlines.contains { $0.actionID == action.id } }) { action in
                                            Button(action.label) { open(action) }.buttonStyle(.bordered)
                                        }
                                    }
                                    DisclosureGroup("Task details") {
                                        VStack(alignment: .leading, spacing: 7) {
                                            detailSection("Finish when", row.doneWhen)
                                            detailSection("Timing", row.whyNow)
                                            if preferences.requiredOnly && (payload.deadlines ?? []).contains(where: { $0.rowID == row.id }) && !(payload.deadlines ?? []).contains(where: { $0.rowID == row.id && $0.required }) && retainedRows.contains(row.id) {
                                                Text("Optional work retained for focus, reminder or navigation")
                                                    .font(.caption2).foregroundStyle(.secondary)
                                            }
                                            ForEach(deadlines) { deadline in
                                                let due = deadline.dueAt.formatted(date: .abbreviated, time: .shortened)
                                                let remaining = isStale || store.showingPreviousPlan ? "" :
                                                    " · \(TodaySchedule.countdown(to: deadline.dueAt, at: store.now))"
                                                Text("\(deadline.required ? "Required" : "Optional") · Due \(due)\(remaining)")
                                                    .font(.caption).foregroundStyle(.orange)
                                            }
                                            Text("\(row.purpose.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))) · \(row.basis.rawValue)")
                                                .font(.caption2).foregroundStyle(.secondary)
                                        }
                                        .padding(.top, 6)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }.padding(.top, 8)
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("\(index + 1). \(row.work)")
                                        .font(.subheadline.weight(.semibold))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .layoutPriority(1)
                                    Spacer(minLength: 0)
                                    if let nextDeadline {
                                        Text(nextDeadline.dueAt.formatted(.dateTime.month(.abbreviated).day()))
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(nextDeadline.required ? Color.orange : Color.secondary)
                                            .fixedSize()
                                            .accessibilityLabel("Due \(nextDeadline.dueAt.formatted(date: .abbreviated, time: .shortened))")
                                    }
                                    Text(row.time)
                                        .font(.caption).foregroundStyle(.secondary)
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: 130, alignment: .trailing)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, preferences.compact ? 5 : 7)
                            .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                            .id(row.id)
                        }
                    }
                    if let anki = payload.anki {
                        Text(anki.status == .available ? "Anki: \(anki.reviewedToday ?? 0) reviewed, \(anki.newCards ?? 0) new" : "Anki is not running").font(.caption).foregroundStyle(.secondary)
                    }
                    if let protected = payload.protectedTime { labeled("Protected", protected) }
                    HStack {
                        ForEach(payload.actions) { action in Button(action.label) { open(action) }.buttonStyle(.bordered) }
                        Spacer()
                        Button { showQuietSettings.toggle() } label: { Image(systemName: "moon") }
                            .accessibilityLabel("Quiet hours")
                            .help("Quiet hours").popover(isPresented: $showQuietSettings) { TodayQuietSettings() }
                    }
                    if let notice = store.notice { Text(notice).font(.caption2).foregroundStyle(.orange) }
                    if let actionMessage { Text(actionMessage).font(.caption2).foregroundStyle(.orange) }
                }
                .padding(preferences.compact ? 10 : 14)
                .background(TodayScrollPositionKeeper(defaultsKey: "today.scrollOffset", defaults: scrollDefaults))
            }
            .frame(maxHeight: .infinity)
            .onAppear {
                revealSelection(store.selectedRowID, proxy: proxy)
            }
            .onChange(of: preferences.requiredOnly) { _, _ in revealedRows = [] }
            .onChange(of: payload) { _, _ in revealedRows = [] }
            .onChange(of: store.selectedRowID) { _, id in
                revealSelection(id, proxy: proxy)
            }
            }
        }
    }

    private func taskSteps(_ method: String) -> some View {
        let methodPrefixes = ["[Administrative] ", "[Apply] ", "[Memorize] ", "[Perform] ",
                              "[Read and summarize] ", "[Understand] "]
        let steps = method.split(whereSeparator: \.isNewline).map { rawLine in
            let line = rawLine.trimmingCharacters(in: CharacterSet(charactersIn: "• ").union(.whitespaces))
            guard let prefix = methodPrefixes.first(where: { line.hasPrefix($0) }) else { return line }
            return String(line.dropFirst(prefix.count))
        }.filter { !$0.isEmpty }

        return VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("•").foregroundStyle(.secondary).accessibilityHidden(true)
                    Text(step).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.callout)
    }

    private func detailSection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).fontWeight(.semibold).foregroundStyle(.primary)
            Text(body).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func revealSelection(_ id: String?, proxy: ScrollViewProxy) {
        guard let id else { return }
        revealedRows.insert(id)
        expandedRows.insert(id)
        // Let the retained row enter layout before scrolling and clearing navigation.
        DispatchQueue.main.async {
            proxy.scrollTo(id, anchor: .top)
            if store.selectedRowID == id { store.selectedRowID = nil }
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

struct TodayScrollPositionKeeper: NSViewRepresentable {
    let defaultsKey: String
    var defaults: UserDefaults = .standard

    func makeCoordinator() -> Coordinator { Coordinator(defaultsKey: defaultsKey, defaults: defaults) }

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

        private let defaults: UserDefaults
        init(defaultsKey: String, defaults: UserDefaults = .standard) {
            self.defaultsKey = defaultsKey
            self.defaults = defaults
        }

        func attach(to view: NSView) {
            guard let enclosingScrollView = enclosingScrollView(for: view) else { return }
            if scrollView === enclosingScrollView {
                clampOffset(in: enclosingScrollView)
                return
            }
            detach()
            scrollView = enclosingScrollView

            let clipView = enclosingScrollView.contentView
            if let savedOffset = defaults.object(forKey: defaultsKey) as? NSNumber {
                clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x,
                    y: clamped(savedOffset.doubleValue, in: enclosingScrollView)))
                enclosingScrollView.reflectScrolledClipView(clipView)
            }
            clipView.postsBoundsChangedNotifications = true
            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [defaultsKey, defaults] notification in
                guard let clipView = notification.object as? NSClipView else { return }
                defaults.set(clipView.bounds.origin.y, forKey: defaultsKey)
            }
        }

        private func clamped(_ offset: CGFloat, in scroll: NSScrollView) -> CGFloat {
            let maximum = max(0, (scroll.documentView?.frame.height ?? 0) - scroll.contentView.bounds.height)
            return min(max(0, offset.isFinite ? offset : 0), maximum)
        }

        private func clampOffset(in scroll: NSScrollView) {
            let clip = scroll.contentView
            let offset = clamped(clip.bounds.origin.y, in: scroll)
            if offset != clip.bounds.origin.y {
                clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: offset))
                scroll.reflectScrolledClipView(clip)
            }
        }

        func detach() {
            if let scrollView {
                defaults.set(scrollView.contentView.bounds.origin.y, forKey: defaultsKey)
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
    var subtle = false
    let openToday: (String) -> Void

    private var grouped: [TodayDueReminder] {
        var seen: Set<String> = []
        return store.reminders.sorted { $0.deadline.required && !$1.deadline.required }
            .filter { seen.insert($0.deadline.id).inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: subtle ? 3 : 5) {
            ForEach(grouped) { item in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(item.deadline.required ? "Required" : "Optional"): \(item.row.work)")
                            .font(.caption.weight(subtle ? .regular : .semibold)).lineLimit(1).help(item.row.work)
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
        }.buttonStyle(.bordered).padding(subtle ? 6 : 10).frame(width: 580, alignment: .leading)
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
    let presentation: TodayGlancePresentation
    let notchWidth: CGFloat
    let height: CGFloat
    let openToday: (String) -> Void

    // Use the same font for measurement and rendering; reserve one countdown bucket
    // across ticks so digits and unit transitions never make the right wing jitter.
    static let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
    static func textWidth(_ text: String, monospaced: Bool = false) -> CGFloat {
        let font = monospaced
            ? NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
            : Self.font
        return (text as NSString).size(withAttributes: [.font: font]).width
    }
    static func geometry(label: String, cap: CGFloat, outerPadding: CGFloat) -> TodayGlanceGeometry {
        TodayGlanceGeometry(leftTextWidth: textWidth(label),
            rightTextWidth: ["99m", "99h", "999d+", "Done", "Alert"].map { textWidth($0, monospaced: true) }.max() ?? 0,
            cap: cap, outerPadding: outerPadding)
    }

    var body: some View {
        let help = Text(verbatim: "\(presentation.title) · \(presentation.detail). Open Today for details.")
        let accessibilityLabel = Text(verbatim: "\(presentation.title), \(presentation.detail), open Today")
        let button = Button { openToday(presentation.rowID) } label: {
            glanceLabel
        }
        return button
            .buttonStyle(PlainButtonStyle())
            .help(help)
            .accessibilityLabel(accessibilityLabel)
    }

    private var glanceLabel: some View {
        HStack(spacing: 0) {
            Text(presentation.label)
                .padding(.horizontal, 2)
                .frame(width: presentation.geometry.leftWidth, alignment: .leading)
                .clipped()
            Color.clear.frame(width: notchWidth)
            statusLabel
        }
        .font(Font(Self.font))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(height: height)
        .contentShape(Rectangle())
    }

    private var statusLabel: some View {
        let style = presentation.isReminder
            ? AnyShapeStyle(Color.orange)
            : AnyShapeStyle(HierarchicalShapeStyle.secondary)
        return Text(presentation.status)
            .monospacedDigit()
            .foregroundStyle(style)
            .padding(.horizontal, 2)
            .frame(width: presentation.geometry.rightWidth, alignment: .trailing)
            .clipped()
    }
}
