//
//  SearchManualsIntent.swift
//  PocketManuals
//
//  The in-app search schema: a way for Siri to reach the app by voice without an App Shortcut
//  phrase. Siri passes the search term, the app opens on Ask, and the question is answered there
//  over every indexed manual. The intent also returns the answer, for Siri to show or speak.
//  Apple does not let a ShowInAppSearchResultsIntent run in the background, so the app opens.
//

import AppIntents

@available(iOS 27, macOS 27, visionOS 27, *)
@AppIntent(schema: .system.searchInApp)
struct SearchManualsIntent: ShowInAppSearchResultsIntent {
    /// Shortcuts lists actions by title, and the schema does not provide one.
    static let title: LocalizedStringResource = "Search My Manuals"
    static let searchScopes: [StringSearchScope] = [.general]

    var criteria: StringSearchCriteria

    @Dependency private var ask: AskViewModel
    @Dependency private var library: ManualLibrary
    @Dependency private var settings: ProviderSettings
    @Dependency private var preferences: ManualsPreferences

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog & ShowsSnippetView {
        AppLog.info("Siri in-app search received")
        ask.askRequested = true
        return IntentAnswer.reply(await AskPocketManualsIntent.answer(
            criteria.term,
            ask: ask,
            library: library,
            settings: settings,
            preferences: preferences
        ))
    }
}
