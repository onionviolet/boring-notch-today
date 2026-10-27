import SwiftUI
import AppKit

struct DHallView: View {
    @StateObject private var store = DHallStore.shared
    @AppStorage("dhall.day") private var selectedDay = ""
    @AppStorage("dhall.meal") private var selectedMeal = ""
    @AppStorage("dhall.station") private var selectedStation = "All"
    @State private var searching = false
    @State private var showExtras = false
    @State private var jumpRequest = UUID()
    private static let topID = "dhall.top", moreID = "dhall.more"
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var today: String { DHallMenu.day() }
    private var menu: DHallMenu? { store.menu(for: selectedDay) ?? store.menu(for: today) ?? store.menus.last }
    private var meal: DHallMenu.Meal? {
        menu?.meals.first(where: { $0.name == selectedMeal }) ?? menu?.meals.first
    }
    private var stations: [String] {
        var result = ["All"]
        for item in meal?.items ?? [] where !result.contains(item.station) { result.append(item.station) }
        return result
    }

    private func items(at station: String) -> [DHallMenu.Item] { (meal?.items ?? []).filter { $0.station == station } }
    /// Hot-line stations, those with starred or watched items first; others keep posted order.
    private var hotStations: [String] {
        stations.dropFirst().filter { !DHallStore.isSelfServe($0) }.enumerated().sorted { a, b in
            let (sa, sb) = (bestScore(a.element), bestScore(b.element))
            return sa != sb ? sa > sb : a.offset < b.offset
        }.map(\.element)
    }
    private var extraStations: [String] { stations.dropFirst().filter(DHallStore.isSelfServe) }
    private func bestScore(_ station: String) -> Int { max(items(at: station).map(store.score).max() ?? 0, 1) }

    private struct Hit: Identifiable {
        var id: String { "\(day)/\(meal)/\(item.id)" }
        var day: String
        var meal: String
        var item: DHallMenu.Item
    }
    private var hits: [Hit] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard needle.count >= 2 else { return [] }
        let ordered = store.menus.filter { $0.date >= today } + store.menus.filter { $0.date < today }.reversed()
        return ordered.flatMap { menu in
            menu.meals.flatMap { meal in
                meal.items.filter { $0.name.lowercased().contains(needle) }
                    .map { Hit(day: menu.date, meal: meal.name, item: $0) }
            }
        }
    }

    private func parse(_ day: String) -> Date? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "America/New_York")
        parser.dateFormat = "yyyy-MM-dd"
        return parser.date(from: day)
    }

    private func dayLabel(_ day: String) -> String {
        if day == today { return "Today" }
        if day == DHallMenu.shifted(today, by: 1) { return "Tomorrow" }
        if day == DHallMenu.shifted(today, by: -1) { return "Yesterday" }
        guard let date = parse(day) else { return day }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "EEE MMM d"
        return formatter.string(from: date)
    }

    /// Steps to the previous or next saved day.
    private func dayStep(_ offset: Int) -> some View {
        let days = store.menus.map(\.date)
        let index = days.firstIndex(of: menu?.date ?? today)
        let target = index.flatMap { days.indices.contains($0 + offset) ? days[$0 + offset] : nil }
        return Button { if let target { selectedDay = target } } label: {
            Image(systemName: offset < 0 ? "chevron.left" : "chevron.right")
        }.buttonStyle(.plain).disabled(target == nil).help(offset < 0 ? "Previous day" : "Next day")
    }

    private func pickerLabel(_ menu: DHallMenu) -> String {
        let count = store.keyItems(menu).count
        return dayLabel(menu.date) + (count == 0 ? "" : " ★\(count)")
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 6) {
                header
                if searching {
                    TextField("Search the week and history", text: $query)
                        .textFieldStyle(.roundedBorder).controlSize(.small).font(.caption)
                        .focused($searchFocused)
                    results
                } else if let menu {
                    HStack {
                        Text(menu.date >= DHallMenu.day(context.date) ? "The Marketplace" : "RECORDED • \(dayLabel(menu.date))")
                            .foregroundStyle(menu.date >= DHallMenu.day(context.date) ? Color.secondary : .orange)
                        Spacer()
                        Text("Checked \(menu.checkedAt.formatted(date: .omitted, time: .shortened))").foregroundStyle(.secondary)
                    }.font(.caption2)
                    keyStrip(menu)
                    Picker("Meal", selection: $selectedMeal) {
                        ForEach(menu.meals) { Text($0.name).tag($0.name) }
                    }.pickerStyle(.segmented).labelsHidden().frame(width: 220)
                    stationChips
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4, pinnedViews: .sectionHeaders) {
                                Color.clear.frame(height: 0).id(Self.topID)
                                ForEach(hotStations, id: \.self) { stationSection($0) }
                                if !extraStations.isEmpty {
                                    Button { showExtras.toggle() } label: {
                                        Label("Salad bar, drinks & more (\(extraStations.count) stations)",
                                              systemImage: showExtras ? "chevron.down" : "chevron.right")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }.buttonStyle(.plain).padding(.top, 4).id(Self.moreID)
                                    if showExtras { ForEach(extraStations, id: \.self) { stationSection($0) } }
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .onAppear { DispatchQueue.main.async { jump(proxy) } }
                        .onChange(of: jumpRequest) { _, _ in jump(proxy) }
                    }.id("\(menu.date)/\(selectedMeal)")
                } else {
                    Text(store.refreshing ? "Loading the menu…" : "No saved menu yet.")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if let notice = store.notice { Text(notice).font(.caption2).foregroundStyle(.orange).lineLimit(2).help(notice) }
            }.padding(.horizontal, 14).padding(.vertical, 8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .task { normalizeDay(); await store.refreshIfNeeded(); normalizeDay(); chooseMeal() }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { break }
                await store.refreshIfNeeded()
            }
        }
        .onChange(of: selectedDay) { _, _ in chooseMeal(); resetStationIfMissing() }
        .onChange(of: selectedMeal) { _, _ in resetStationIfMissing() }
        .onChange(of: store.menus.count) { _, _ in normalizeDay() }
        .onChange(of: searching) { _, on in
            setKeyboardAccess(on)
            if on { searchFocused = true } else { query = "" }
        }
        .onDisappear { searching = false; setKeyboardAccess(false) }
    }

    private var header: some View {
        HStack {
            Text("D-hall").font(.headline)
            if store.menus.count > 1 {
                dayStep(-1)
                Picker("Day", selection: $selectedDay) {
                    ForEach(store.menus.reversed(), id: \.date) { Text(pickerLabel($0)).tag($0.date) }
                }.controlSize(.small).labelsHidden().fixedSize().help("Choose a day; past days are recorded")
                dayStep(1)
            } else {
                Text(menu?.date ?? today).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if store.refreshing { ProgressView().controlSize(.small) }
            Button { searching.toggle() } label: { Image(systemName: searching ? "xmark.circle" : "magnifyingglass") }
                .buttonStyle(.plain).help("Search items across days")
            Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain).disabled(store.refreshing).help("Refresh the Marketplace menus")
            Link(destination: DHallStore.source) { Image(systemName: "arrow.up.right.square") }
                .help("Open NetNutrition for nutrition and allergens")
        }
    }

    /// Starred and keyword items for the shown day; tapping one jumps to its meal and station.
    @ViewBuilder private func keyStrip(_ menu: DHallMenu) -> some View {
        let keys = store.keyItems(menu)
        if !keys.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                    ForEach(keys, id: \.item.name) { key in
                        Button {
                            selectedMeal = key.meal; select(key.item.station)
                        } label: {
                            (Text(key.item.name).foregroundStyle(.yellow) + Text(" \(key.meal)").foregroundStyle(.secondary))
                                .font(.caption2).lineLimit(1)
                        }.buttonStyle(.plain).help("Show \(key.item.station) at \(key.meal)")
                    }
                }
            }
        }
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    /// Watched keywords, shown before typing; tap one to stop highlighting it.
    private var keywordList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Highlighted words (tap to remove). Search, then Watch to add one.")
                .font(.caption2).foregroundStyle(.secondary)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), alignment: .leading)], alignment: .leading, spacing: 4) {
                    ForEach(store.keywords, id: \.self) { word in
                        Button { store.toggleKeyword(word) } label: {
                            Label(word, systemImage: "xmark").font(.caption2).labelStyle(.titleAndIcon)
                        }.buttonStyle(.bordered).controlSize(.mini)
                    }
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var results: some View {
        let found = hits
        if trimmedQuery.count >= 2 {
            Button { store.toggleKeyword(trimmedQuery) } label: {
                Label(store.isWatched(trimmedQuery) ? "Stop highlighting “\(trimmedQuery)”" : "Watch “\(trimmedQuery)” on every menu",
                      systemImage: store.isWatched(trimmedQuery) ? "star.slash" : "star")
                    .font(.caption2)
            }.buttonStyle(.plain).foregroundStyle(.yellow)
        }
        if trimmedQuery.isEmpty {
            keywordList
        } else if found.isEmpty {
            Text(query.trimmingCharacters(in: .whitespaces).count < 2 ? "Type at least 2 letters." : "Not on any recorded or upcoming menu.")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(found.prefix(200)) { hit in
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            star(hit.item.name)
                            Button {
                                selectedDay = hit.day; selectedMeal = hit.meal; selectedStation = hit.item.station
                                searching = false
                            } label: {
                                (Text(hit.item.name).foregroundStyle(store.isKey(hit.item) ? Color.yellow : .primary) + Text("  \(dayLabel(hit.day)) • \(hit.meal)").foregroundStyle(.secondary))
                                    .font(.caption).multilineTextAlignment(.leading)
                            }.buttonStyle(.plain)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Jump buttons for the hot line; the station headers stay pinned while scrolling.
    private var stationChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(hotStations, id: \.self) { station in
                    Button { select(station) } label: {
                        Label(station, systemImage: Self.icon(station)).font(.caption2)
                    }.buttonStyle(.bordered).controlSize(.mini)
                        .tint(selectedStation == station ? .accentColor : nil)
                }
                if !extraStations.isEmpty {
                    Button { select(Self.moreID) } label: { Label("More", systemImage: "ellipsis") .font(.caption2) }
                        .buttonStyle(.bordered).controlSize(.mini)
                }
            }
        }
    }

    private func stationSection(_ station: String) -> some View {
        Section {
            DHallFlow(spacing: 4) {
                ForEach(store.ranked(items(at: station))) { chip($0) }
            }.padding(.bottom, 4)
        } header: {
            Label(station, systemImage: Self.icon(station))
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 2)
                .background(Color.black)
        }.id(station)
    }

    /// Starred and watched items lead in yellow; staples (on most saved meals) are dimmed.
    private func chip(_ item: DHallMenu.Item) -> some View {
        let score = store.score(item)
        let emoji = DHallStore.matchesKeyword(item, store.keywords) ? DHallStore.emoji(item) : nil
        return HStack(spacing: 3) {
            star(item.name)
            if let emoji { Text(emoji).font(.caption2) }
            Text(item.name).font(.caption.weight(score >= 2 ? .semibold : .regular))
                .foregroundStyle(score >= 2 ? Color.yellow : score < 0 ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(score >= 2 ? 0.14 : 0.06)))
        .help(score < 0 ? "Usually on the menu" + (item.serving.isEmpty ? "" : " • \(item.serving)")
              : item.serving.isEmpty ? item.name : "Posted serving: \(item.serving)")
    }

    static func icon(_ station: String) -> String {
        let name = station.lowercased()
        let table: [(String, String)] = [("grill", "flame"), ("global", "globe.americas"), ("daily", "fork.knife"),
            ("pizza", "chart.pie"), ("soup", "mug"), ("deli", "takeoutbag.and.cup.and.straw"), ("dessert", "birthday.cake"),
            ("ice cream", "snowflake"), ("salad", "leaf"), ("fruit", "leaf"), ("coffee", "cup.and.saucer"), ("tea", "cup.and.saucer"),
            ("cereal", "sun.horizon"), ("milk", "drop"), ("fountain", "drop"), ("allergen", "checkmark.shield"), ("breakfast", "sunrise")]
        return table.first { name.contains($0.0) }?.1 ?? "circle.grid.2x2"
    }

    private func select(_ station: String) {
        selectedStation = station
        jumpRequest = UUID()
    }

    private func jump(_ proxy: ScrollViewProxy) {
        let target: String
        if selectedStation == "All" { target = Self.topID }
        else if selectedStation == Self.moreID { target = Self.moreID }
        else if stations.contains(selectedStation) {
            if DHallStore.isSelfServe(selectedStation) { showExtras = true }
            target = selectedStation
        } else { target = Self.topID }
        DispatchQueue.main.async { withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(target, anchor: .top) } }
    }

    private func star(_ name: String) -> some View {
        Button { store.toggleFavorite(name) } label: {
            Image(systemName: store.isFavorite(name) ? "star.fill" : "star")
                .font(.caption2).foregroundStyle(store.isFavorite(name) ? Color.yellow : .secondary)
        }.buttonStyle(.plain).help(store.isFavorite(name) ? "Remove from favorites" : "Star this item")
    }

    /// The notch panel refuses key status so it never steals focus; typing needs it only while searching.
    private func setKeyboardAccess(_ on: Bool) {
        for window in NSApp.windows { (window as? BoringNotchSkyLightWindow)?.wantsKeyForTextInput = on }
    }

    private func normalizeDay() {
        if store.menu(for: selectedDay) == nil { selectedDay = store.menu(for: today) != nil ? today : (store.menus.last?.date ?? today) }
    }

    private func resetStationIfMissing() {
        if !stations.contains(selectedStation) && selectedStation != Self.moreID { selectedStation = "All" }
    }

    private func chooseMeal() {
        guard let meals = menu?.meals, !meals.isEmpty else { return }
        if menu?.date != today {
            // Keep the same meal across days when it exists, e.g. browsing Lunch.
            if meals.contains(where: { $0.name == selectedMeal }) { return }
            selectedMeal = meals.first(where: { $0.name == "Lunch" })?.name ?? meals[0].name
            return
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let hour = calendar.component(.hour, from: Date())
        let preferred = hour < 11 ? "Breakfast" : hour < 15 ? "Lunch" : "Dinner"
        selectedMeal = meals.first(where: { $0.name == preferred })?.name ?? meals[0].name
    }
}

/// Wraps chips onto as many lines as the width needs.
struct DHallFlow: Layout {
    var spacing: CGFloat = 4

    private func sizes(_ subviews: Subviews, width: CGFloat) -> [CGSize] {
        subviews.map { view in
            let ideal = view.sizeThatFits(.unspecified)
            return ideal.width <= width ? ideal : view.sizeThatFits(ProposedViewSize(width: width, height: nil))
        }
    }

    private func frames(_ sizes: [CGSize], width: CGFloat) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = [], x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for size in sizes {
            if x > 0 && x + size.width > width { x = 0; y += line + spacing; line = 0 }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing; line = max(line, size.height); widest = max(widest, x - spacing)
        }
        return (frames, CGSize(width: widest, height: y + line))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let size = frames(sizes(subviews, width: width), width: width).size
        return CGSize(width: proposal.width ?? size.width, height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sized = sizes(subviews, width: bounds.width)
        for (view, frame) in zip(subviews, frames(sized, width: bounds.width).frames) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                       proposal: ProposedViewSize(frame.size))
        }
    }
}
