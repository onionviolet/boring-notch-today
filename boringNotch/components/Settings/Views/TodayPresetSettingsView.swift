import SwiftUI

struct TodayPresetSettingsView: View {
    let store: TodayPresetStore
    @State var selection: TodayPresetName = .study
    @State var status = ""
    @State private var revision = 0
    @State private var applied: [TodayPresetChange] = []

    var body: some View {
        let _ = revision
        let target = store.target(selection)
        let changes = store.preview(selection)
        Section("Named Today Presets") {
            Picker("Preset", selection: $selection) {
                ForEach(TodayPresetName.allCases) { Text($0.rawValue).tag($0) }
            }
            Text("Quiet changes Today presentation only. Quiet hours, reminder delivery and active focus sessions stay as they are.")
                .font(.caption).foregroundStyle(.secondary)
            if let target {
                Text("Preview · \(selection.rawValue)").font(.headline)
                ForEach(TodayPresetKey.allCases, id: \.self) { key in
                    if let change = changes.first(where: { $0.key == key }) {
                        Text(change.description)
                    } else {
                        Text("\(key.title): \(key.display(target[key])) (unchanged)")
                            .foregroundStyle(.secondary)
                    }
                }.font(.caption)
                if changes.isEmpty { Text("These settings already match. Apply will change nothing.").font(.caption) }
            }
            Text(store.customStatus).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Apply \(selection.rawValue)") {
                    applied = store.apply(selection)
                    status = applied.isEmpty ? "No settings changed. Previous restore kept." : "Applied \(selection.rawValue): \(applied.count) settings changed."
                    revision += 1
                }.disabled(target == nil)
                Button("Save Custom") {
                    store.saveCustom()
                    status = "Saved current settings as Custom. Settings and previous restore kept."
                    revision += 1
                }
                Button("Restore previous settings") {
                    if let result = store.restore() { status = result.message; applied = [] }
                    revision += 1
                }.disabled(!store.canRestore)
            }
            if store.restoreInvalid { Text("Previous restore is invalid or unsupported; restoration is unavailable.").font(.caption) }
            if !status.isEmpty { Text(status).font(.caption) }
            if !applied.isEmpty {
                Text("Last applied changes").font(.caption.bold())
                ForEach(applied) { Text($0.description).font(.caption) }
            }
        }
        .onChange(of: selection) { status = ""; applied = [] }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in revision += 1 }
    }
}
