//
//  AdminKnowledgeGraphDocument.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un documento della base di conoscenza (RagDocumentResponse, chiavi già camelCase lato server).
//  Non ha campi che lo leghino ad altro: il grafo lo collega agli asset solo tramite i `tags`.
//

import Foundation

nonisolated struct AdminKnowledgeGraphDocument: Decodable, Sendable, Hashable {
    let serverId: String?
    let title: String?
    let description: String?
    let tags: [String]
    let sourceType: String?
    let fileName: String?
    let mimeType: String?
    let sizeBytes: Int?
    let pageCount: Int?
    let language: String?
    let ingestionState: String?
    let extractionState: String?
    let lastError: String?
    let lastCompletedAt: Date?
    let isDeleted: Bool
    let createdAt: Date?
    let updatedAt: Date?

    init(from decoder: any Decoder) throws {
        let wire = try AdminKnowledgeGraphWire(decoder)
        serverId = wire.text("id")
        title = wire.text("title")
        description = wire.text("description")
        tags = wire.texts("tags")
        let source = wire.nested("source")
        sourceType = source?.text("type")
        fileName = source?.text("fileName")
        mimeType = source?.text("mimeType")
        sizeBytes = source?.integer("sizeBytes")
        let content = wire.nested("content")
        pageCount = content?.integer("pageCount")
        language = content?.text("language")
        let status = wire.nested("status")
        ingestionState = status?.text("ingestionState")
        extractionState = status?.text("extractionState")
        lastError = status?.nested("lastError")?.text("message")
        lastCompletedAt = status?.date("lastCompletedAt")
        isDeleted = wire.flag("isDeleted") ?? false
        createdAt = wire.date("createdAt")
        updatedAt = wire.date("updatedAt")
        guard serverId != nil || title != nil || fileName != nil else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Documento senza id né titolo"))
        }
    }

    var displayTitle: String { title ?? fileName ?? serverId ?? "" }
}
