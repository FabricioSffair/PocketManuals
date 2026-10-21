//
//  PocketManualsApp.swift
//  PocketManuals
//
//  Pocket Manuals: a RailtracksSwift showcase. PDF manuals are indexed page by
//  page; answers cite the page and are checked by a verifier.
//
//  Every long-lived object is created here once and shared by the window, the
//  Settings scene, and the Siri and Shortcuts actions.
//

import SwiftUI
import AppIntents
import Logging
import RailtracksSwift
import RailtownLogger

@main
struct PocketManualsApp: App {
    @State private var settings: ProviderSettings
    @State private var library: ManualLibrary
    @State private var ask: AskViewModel
    @State private var preferences: ManualsPreferences

    init() {
        let settings = ProviderSettings()
        // The index's embedding fallback uses the OpenAI key, only when cloud embeddings are
        // allowed; ManualsRootView passes changes on.
        let library = ManualLibrary(index: ManualIndex(openAIKey: settings.embeddingOpenAIKey))
        let ask = AskViewModel()
        let preferences = ManualsPreferences()
        _settings = State(initialValue: settings)
        _library = State(initialValue: library)
        _ask = State(initialValue: ask)
        _preferences = State(initialValue: preferences)
        // The Siri and Shortcuts actions use these same instances: see AskIntents.swift.
        AppDependencyManager.shared.add(dependency: settings)
        AppDependencyManager.shared.add(dependency: library)
        AppDependencyManager.shared.add(dependency: ask)
        AppDependencyManager.shared.add(dependency: preferences)

        Self.bootstrapLogging()
        // Error logs, the SDK's own error reports and trace uploads, with the Railtown keys from
        // Settings. Without a key they stay off.
        settings.configureRailtown()
        AppLog.info("App launched")
        print("Trace directory: \(RailtracksSwift.flowGraphOutputDirectory.path)")
    }

    var body: some Scene {
        WindowGroup {
            withEnvironment(ManualsRootView())
        }
        #if os(macOS)
        // ⌘, and the sidebar's Settings button. The same view as the iOS Settings tab.
        Settings {
            withEnvironment(SettingsView())
                .frame(width: 560, height: 680)
        }
        #endif
    }

    /// Every scene sees the same shared state.
    private func withEnvironment(_ content: some View) -> some View {
        content
            .environment(settings)
            .environment(library)
            .environment(ask)
            .environment(preferences)
    }

    private static func bootstrapLogging() {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            #if DEBUG
            handler.logLevel = .debug
            #else
            handler.logLevel = .info
            #endif
            return handler
        }
    }
}
