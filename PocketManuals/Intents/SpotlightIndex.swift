//
//  SpotlightIndex.swift
//  PocketManuals
//
//  Puts every page of each indexed manual in Spotlight, as plain keyword search: a search for
//  "radon test kit" finds the page. Tapping a result opens that page in the app (see
//  ManualsRootView). The agents are not involved; this reuses the text the app already has.
//

import CoreSpotlight
import Foundation
import PDFKit
import UniformTypeIdentifiers

enum SpotlightIndex {
    private static let manualPrefix = "manual-page|"
    /// Bump when the items' shape changes, so the launch sync indexes everything again.
    private static let formatVersion = 1
    /// One key per manual that was indexed, so the launch sync only fills gaps.
    private static func manualStateKey(_ id: String) -> String { "spotlight.v\(formatVersion).manual.\(id)" }

    static func manualPageID(docID: String, page: Int) -> String {
        manualPrefix + ManualCitation.key(manualID: docID, page: page)
    }
    private static func manualDomain(_ id: String) -> String { "manual.\(id)" }

    // MARK: Manuals

    /// One item per page with text. Replaces the manual's earlier items.
    @MainActor
    static func indexManual(id: String, title: String) {
        let fileURL = ManualLibrary.fileURL(for: id)
        Task.detached(priority: .utility) {
            guard let document = PDFDocument(url: fileURL) else { return }
            let shortTitle = PageReference.shortTitle(title)
            let items = (0..<document.pageCount).compactMap { index -> CSSearchableItem? in
                guard let text = document.page(at: index)?.string?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty
                else { return nil }
                let attributes = CSSearchableItemAttributeSet(contentType: .pdf)
                attributes.title = "\(shortTitle), p. \(index + 1)"
                attributes.contentDescription = String(text.prefix(300))
                attributes.textContent = text
                attributes.keywords = [shortTitle, "manual"]
                return CSSearchableItem(
                    uniqueIdentifier: manualPageID(docID: id, page: index + 1),
                    domainIdentifier: manualDomain(id),
                    attributeSet: attributes
                )
            }
            do {
                let index = CSSearchableIndex.default()
                try await index.deleteSearchableItems(withDomainIdentifiers: [manualDomain(id)])
                try await index.indexSearchableItems(items)
                UserDefaults.standard.set(true, forKey: manualStateKey(id))
                AppLog.info("Manual added to Spotlight", properties: ["Pages": "\(items.count)"])
            } catch {
                AppLog.warning("Manual not added to Spotlight", properties: ["Reason": error.localizedDescription])
            }
        }
    }

    static func removeManual(id: String) {
        UserDefaults.standard.removeObject(forKey: manualStateKey(id))
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [manualDomain(id)])
    }

    // MARK: Launch

    @MainActor private static var didSync = false

    /// Indexes the manuals that are on disk but not in Spotlight yet: manuals indexed before
    /// this feature, or before a format change. Once per launch, however many windows call it.
    @MainActor
    static func syncAtLaunch(documents: [ManualDocument]) {
        guard !didSync else { return }
        didSync = true
        for document in documents where !UserDefaults.standard.bool(forKey: manualStateKey(document.id)) {
            if case .indexed = document.indexState {
                indexManual(id: document.id, title: document.title)
            }
        }
    }

    // MARK: Opening a result

    /// The page a tapped result's identifier points at, or `nil` when its manual is gone.
    @MainActor
    static func page(for identifier: String, documents: [ManualDocument]) -> PageReference? {
        guard identifier.hasPrefix(manualPrefix) else { return nil }
        let key = identifier.dropFirst(manualPrefix.count)
        guard let marker = key.range(of: "#page-", options: .backwards),
              let page = Int(key[marker.upperBound...]),
              let document = documents.first(where: { $0.id == String(key[..<marker.lowerBound]) })
        else { return nil }
        return PageReference(docID: document.id, page: page, title: document.title)
    }
}
