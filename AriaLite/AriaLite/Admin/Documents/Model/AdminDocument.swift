//
//  AdminDocument.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un documento della libreria (RagDocumentResponse). Lettura tollerante: senza id si scarta, tutto il
//  resto può mancare. Sorgente, contenuto e stato arrivano annidati; qui si appiattiscono in campi semplici.
//

import Foundation

nonisolated struct AdminDocument: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String?
    let description: String?
    let tags: [String]
    let fileName: String?
    let mimeType: String?
    let sizeBytes: Int?
    /// `upload`, `url`, `s3`…
    let sourceType: String?
    let pageCount: Int?
    let language: String?
    let textLength: Int?
    /// Stati grezzi delle due pipeline (vedi AdminDocumentState).
    let ingestionState: String?
    let extractionState: String?
    let lastError: String?
    let lastRunId: String?
    let lastCompletedAt: Date?
    /// Cancellato (soft delete): non si mostra e non si segue più.
    let isDeleted: Bool
    let createdAt: Date?
    let updatedAt: Date?

    /// Il nome da mostrare: titolo, poi nome del file.
    var displayName: String { title ?? fileName ?? String(localized: "Untitled document") }

    var statusGroup: AdminDocumentStatusGroup { .from(ingestion: ingestionState, extraction: extractionState) }
    /// Una pipeline lavora o la cancellazione è in corso (non conclusa): si segue con il polling.
    var isProcessing: Bool {
        guard !isDeleted else { return false }
        return statusGroup == .processing || [ingestionState, extractionState].contains("pending_deletion")
    }

    /// "PDF · 12 pages · 3.4 MB": la seconda riga nella lista.
    var summaryLine: String {
        var parts: [String] = []
        if let ext = fileName.map({ ($0 as NSString).pathExtension }), !ext.isEmpty { parts.append(ext.uppercased()) }
        if let pageCount { parts.append(String(localized: "\(pageCount) pages")) }
        if let sizeBytes { parts.append(sizeBytes.formatted(.byteCount(style: .file))) }
        return parts.joined(separator: " · ")
    }

    /// Dove cerca la barra di ricerca.
    var searchableFields: [String] { [title, fileName, description].compactMap { $0 } + tags }

    // MARK: Lettura

    /// Le chiavi arrivano già in camelCase (`.snakeCased()` sull'endpoint, il server è già camelCase).
    private enum CodingKeys: String, CodingKey {
        case id, title, description, tags, source, content, status, isDeleted, createdAt, updatedAt
    }
    private enum SourceKeys: String, CodingKey { case type, fileName, mimeType, sizeBytes }
    private enum ContentKeys: String, CodingKey { case rawTextLength, language, pageCount }
    private enum StatusKeys: String, CodingKey { case ingestionState, extractionState, lastError, lastRunId, lastCompletedAt }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = AdminDocumentDecoding.text(c, .id) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: c.codingPath, debugDescription: "Documento senza id"))
        }
        self.id = id
        title = AdminDocumentDecoding.text(c, .title)
        description = AdminDocumentDecoding.text(c, .description)
        tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        isDeleted = (try? c.decodeIfPresent(Bool.self, forKey: .isDeleted)) ?? false
        createdAt = AdminDocumentDecoding.date(c, .createdAt)
        updatedAt = AdminDocumentDecoding.date(c, .updatedAt)

        let source = try? c.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
        fileName = source.flatMap { AdminDocumentDecoding.text($0, .fileName) }
        mimeType = source.flatMap { AdminDocumentDecoding.text($0, .mimeType) }
        sizeBytes = source.flatMap { AdminDocumentDecoding.int($0, .sizeBytes) }
        sourceType = source.flatMap { AdminDocumentDecoding.text($0, .type) }

        let content = try? c.nestedContainer(keyedBy: ContentKeys.self, forKey: .content)
        pageCount = content.flatMap { AdminDocumentDecoding.int($0, .pageCount) }
        language = content.flatMap { AdminDocumentDecoding.text($0, .language) }
        textLength = content.flatMap { AdminDocumentDecoding.int($0, .rawTextLength) }

        let status = try? c.nestedContainer(keyedBy: StatusKeys.self, forKey: .status)
        ingestionState = status.flatMap { AdminDocumentDecoding.text($0, .ingestionState) }
        extractionState = status.flatMap { AdminDocumentDecoding.text($0, .extractionState) }
        lastError = status.flatMap { AdminDocumentDecoding.errorMessage($0, .lastError) }
        lastRunId = status.flatMap { AdminDocumentDecoding.text($0, .lastRunId) }
        lastCompletedAt = status.flatMap { AdminDocumentDecoding.date($0, .lastCompletedAt) }
    }
}

/// Lettura tollerante condivisa dai modelli della sezione.
nonisolated enum AdminDocumentDecoding {
    static func text<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> String? {
        guard let value = try? c.decodeIfPresent(AriaFlexibleID.self, forKey: key)?.value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func int<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Int? {
        if let value = try? c.decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? c.decodeIfPresent(Double.self, forKey: key) { return Int(value) }
        return text(c, key).flatMap { Int($0) }
    }

    static func double<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Double? {
        if let value = try? c.decodeIfPresent(Double.self, forKey: key) { return value }
        return text(c, key).flatMap { Double($0) }
    }

    static func date<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Date? {
        (try? c.decodeIfPresent(AriaWireDate.self, forKey: key))?.value
    }

    static func strings<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> [String] {
        guard let json = try? c.decodeIfPresent(AriaJSON.self, forKey: key) else { return [] }
        return json.arrayValue.compactMap { $0.nonEmptyString ?? $0["message"]?.nonEmptyString ?? $0["label"]?.nonEmptyString }
    }

    /// Un errore (ErrorDetailResponse `{code, message}`) o una stringa semplice.
    static func errorMessage<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> String? {
        guard let json = try? c.decodeIfPresent(AriaJSON.self, forKey: key) else { return nil }
        return json.nonEmptyString ?? json["message"]?.nonEmptyString ?? json["code"]?.nonEmptyString
    }
}
