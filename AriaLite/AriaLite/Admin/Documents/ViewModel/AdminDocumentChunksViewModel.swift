//
//  AdminDocumentChunksViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il testo estratto e indicizzato di un documento, a pezzi (chunk), una pagina alla volta.
//  La ricerca filtra i chunk già scaricati.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminDocumentChunksViewModel {
    let backend: AriaBackend
    let documentId: String
    let title: String

    static let pageSize = 50

    private(set) var chunks: [AdminDocumentChunk] = []
    private(set) var total: Int?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private var lastPageWasFull = false

    var searchText = ""

    init(backend: AriaBackend, documentId: String, title: String) {
        self.backend = backend
        self.documentId = documentId
        self.title = title
    }

    var visibleChunks: [AdminDocumentChunk] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return chunks }
        return chunks.filter { $0.text.localizedStandardContains(query) }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var canLoadMore: Bool {
        guard hasLoaded else { return false }
        if let total { return chunks.count < total }
        return lastPageWasFull
    }

    var subtitle: String {
        if let total, total > chunks.count { return String(localized: "\(chunks.count) of \(total) chunks") }
        return String(localized: "\(chunks.count) chunks")
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await backend.api.call(AdminDocumentsAPI.chunks(id: documentId, skip: 0, limit: Self.pageSize))
            chunks = Self.sorted(page.items)
            total = page.total
            lastPageWasFull = page.items.count >= Self.pageSize
            hasLoaded = true
            errorMessage = nil
        } catch {
            guard let message = AdminDocumentsFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await backend.api.call(AdminDocumentsAPI.chunks(id: documentId, skip: chunks.count, limit: Self.pageSize))
            let known = Set(chunks.map(\.id))
            chunks = Self.sorted(chunks + page.items.filter { !known.contains($0.id) })
            total = page.total ?? total
            lastPageWasFull = page.items.count >= Self.pageSize
        } catch {
            guard let message = AdminDocumentsFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }

    /// In ordine di lettura; quelli senza numero in fondo.
    private static func sorted(_ items: [AdminDocumentChunk]) -> [AdminDocumentChunk] {
        items.sorted { ($0.ordinal ?? .max) < ($1.ordinal ?? .max) }
    }
}
