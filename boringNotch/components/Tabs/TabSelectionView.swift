//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import SwiftUI
import Defaults

struct TabModel: Identifiable {
    var id: NotchViews { view }
    let label: String
    let icon: String
    let view: NotchViews
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    private var tabs: [TabModel] {
        var result = [TabModel(label: "Home", icon: "house.fill", view: .home)]
        if Defaults[.boringShelf] { result.append(TabModel(label: "Shelf", icon: "tray.fill", view: .shelf)) }
        result.append(TabModel(label: "Today", icon: "calendar", view: .today))
        result.append(TabModel(label: "D-hall", icon: "fork.knife", view: .dhall))
        return result
    }
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                    TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view) {
                        coordinator.currentView = tab.view
                    }
                    .frame(height: 26)
                    .foregroundStyle(tab.view == coordinator.currentView ? .white : .gray)
                    .background {
                        Capsule()
                            .fill(tab.view == coordinator.currentView ? Color(nsColor: .secondarySystemFill) : Color.clear)
                    }

            }
        }
        .clipShape(Capsule())
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel(camera: CameraModel()))
}
