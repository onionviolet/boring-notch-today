import SwiftUI

struct DHallView: View {
    @StateObject private var store = DHallStore.shared
    @State private var selectedMeal = ""
    @State private var selectedStation = "All"

    private var meal: DHallMenu.Meal? {
        store.menu?.meals.first(where: { $0.name == selectedMeal }) ?? store.menu?.meals.first
    }
    private var stations: [String] {
        var result = ["All"]
        for item in meal?.items ?? [] where !result.contains(item.station) { result.append(item.station) }
        return result
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("D-hall").font(.headline)
                    Text(store.menu?.date ?? DHallMenu.day(context.date)).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if store.refreshing { ProgressView().controlSize(.small) }
                    Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain).disabled(store.refreshing).help("Refresh today's Marketplace menu")
                    Link(destination: DHallStore.source) { Image(systemName: "arrow.up.right.square") }
                        .help("Open NetNutrition for nutrition and allergens")
                }
                if let menu = store.menu {
                    HStack {
                        Text(menu.date == DHallMenu.day(context.date) ? "The Marketplace" : "OLDER MENU • \(menu.date)")
                            .foregroundStyle(menu.date == DHallMenu.day(context.date) ? Color.secondary : .orange)
                        Spacer()
                        Text("Checked \(menu.checkedAt.formatted(date: .omitted, time: .shortened))").foregroundStyle(.secondary)
                    }.font(.caption2)
                    HStack(spacing: 8) {
                        Picker("Meal", selection: $selectedMeal) {
                            ForEach(menu.meals) { Text($0.name).tag($0.name) }
                        }.pickerStyle(.segmented).labelsHidden().frame(width: 220)
                        Picker("Station", selection: $selectedStation) {
                            ForEach(stations, id: \.self) { Text($0).tag($0) }
                        }.controlSize(.small).labelsHidden().help("Choose a station")
                    }
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 5) {
                            ForEach(stations.filter { $0 != "All" && (selectedStation == "All" || $0 == selectedStation) }, id: \.self) { station in
                                Text(station).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 3)
                                ForEach((meal?.items ?? []).filter { $0.station == station }) { item in
                                    Text(item.name).font(.caption).fixedSize(horizontal: false, vertical: true)
                                        .help(item.serving.isEmpty ? item.name : "Posted serving: \(item.serving)")
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.id("\(selectedMeal)/\(selectedStation)")
                } else {
                    Text(store.refreshing ? "Loading today's menu…" : "No saved menu yet.")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if let notice = store.notice { Text(notice).font(.caption2).foregroundStyle(.orange).lineLimit(2).help(notice) }
            }.padding(.horizontal, 14).padding(.vertical, 8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .task { await store.refreshIfNeeded(); chooseMeal() }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { break }
                await store.refreshIfNeeded()
            }
        }
        .onChange(of: selectedMeal) { _, _ in selectedStation = "All" }
        .onChange(of: store.menu?.date) { _, _ in chooseMeal() }
    }

    private func chooseMeal() {
        guard let meals = store.menu?.meals, !meals.isEmpty else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let hour = calendar.component(.hour, from: Date())
        let preferred = hour < 11 ? "Breakfast" : hour < 15 ? "Lunch" : "Dinner"
        selectedMeal = meals.first(where: { $0.name == preferred })?.name ?? meals[0].name
    }
}
