//
//  ManualsRootView.swift
//  PocketManuals
//
//  The app's root: tabs on iOS, a sidebar on macOS. The library, its index and
//  the Ask view model are created once in the App struct. Also opens the manual
//  page a tapped Spotlight result points at.
//

import CoreSpotlight
import SwiftUI

enum ManualsTab: Hashable {
    case library, ask, settings
}

struct ManualsRootView: View {
    @Environment(ProviderSettings.self) private var settings
    @Environment(ManualLibrary.self) private var library
    @Environment(AskViewModel.self) private var ask

    @State private var tab: ManualsTab = .library
    /// The manual page a tapped Spotlight result opens.
    @State private var spotlightPage: PageReference?

    var body: some View {
        Group {
            #if os(macOS)
            MacRootView(tab: $tab)
            #else
            TabView(selection: $tab) {
                Tab("Library", systemImage: "books.vertical", value: ManualsTab.library) {
                    LibraryView()
                }
                Tab("Ask", systemImage: "questionmark.bubble", value: ManualsTab.ask) {
                    AskView(model: ask)
                }
                Tab("Settings", systemImage: "gearshape", value: ManualsTab.settings) {
                    SettingsView()
                }
            }
            #endif
        }
        .task {
            // Loads the on-device model if its assets are present; no download, no network.
            await library.refreshEmbedderStatus()
        }
        // The index's embedding fallback must see a new key or a change to the cloud-embeddings switch.
        .onChange(of: settings.embeddingOpenAIKey) { _, key in
            Task { await library.updateOpenAIKey(key) }
        }
        .task { SpotlightIndex.syncAtLaunch(documents: library.documents) }
        .onContinueUserActivity(CSSearchableItemActionType, perform: openSpotlightResult)
        .sheet(item: $spotlightPage) { page in
            ManualPageViewer(reference: page)
        }
    }

    private func openSpotlightResult(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let page = SpotlightIndex.page(for: identifier, documents: library.documents)
        else { return }
        spotlightPage = page
    }
}
