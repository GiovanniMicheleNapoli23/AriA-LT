//
//  AdminDocumentUploadFile.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un file scelto da Files, già scritto su disco come corpo multipart di POST /v1/documents/upload.
//  Il caricamento in background parte solo da un file: lo si prepara subito, finché l'accesso
//  "security scoped" è aperto, e a pezzi (un PDF di manuale pesa decine di MB, non sta in memoria).
//

import Foundation
import UniformTypeIdentifiers

nonisolated struct AdminDocumentUploadFile: Sendable, Identifiable {
    let id: UUID
    let filename: String
    let mimeType: String
    let boundary: String
    let size: Int

    /// Legge un URL di `.fileImporter` e ne scrive il corpo multipart nella cartella dei caricamenti.
    @concurrent
    static func read(_ url: URL, into store: AdminDocumentUploadStore) async throws -> AdminDocumentUploadFile {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let id = UUID()
        let filename = url.lastPathComponent
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        let boundary = "aria-\(UUID().uuidString)"
        let size = try store.writeBody(from: url, id: id, filename: filename, mimeType: mime, boundary: boundary)
        return AdminDocumentUploadFile(id: id, filename: filename, mimeType: mime, boundary: boundary, size: size)
    }
}
