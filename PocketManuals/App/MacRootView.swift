//
//  MacRootView.swift
//  PocketManuals
//
//  The macOS window: a sidebar with Library and Ask, and the chosen screen as
//  the detail. Same layout as the Whiteboard app's macOS target. Settings is a
//  separate scene, opened from the sidebar button or with ⌘,.
//

#if os(macOS)
import SwiftUI

struct MacRootView: View {
    @Environment(AskViewModel.self) private var ask
    @Environment(\.openSettings) private var openSettings

    @Binding var tab: ManualsTab

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 240)
        } detail: {
            detail
                .frame(minWidth: 640)
        }
        .frame(minWidth: 1080, minHeight: 680)
    }

    /// Settings is not a sidebar row on the Mac, so it maps to the Library.
    private var selection: Binding<ManualsTab?> {
        Binding(
            get: { tab == .settings ? .library : tab },
            set: { if let destination = $0 { tab = destination } }
        )
    }

    private var sidebar: some View {
        List(selection: selection) {
            Label("Library", systemImage: "books.vertical")
                .tag(ManualsTab.library)
            Label("Ask", systemImage: "questionmark.bubble")
                .tag(ManualsTab.ask)
        }
        .listStyle(.sidebar)
        .navigationTitle("Pocket Manuals")
        .safeAreaInset(edge: .bottom) {
            Button {
                openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .hoverOpacity()
            .padding(.horizontal, .spacing3XL)
            .padding(.vertical, .spacingXL)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch tab {
        case .ask: AskView(model: ask)
        case .library, .settings: LibraryView()
        }
    }
}
#endif
