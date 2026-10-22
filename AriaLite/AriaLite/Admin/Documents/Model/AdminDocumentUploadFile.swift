//
//  AdminDocumentUploadFile.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un file scelto da Files, già letto in memoria, pronto per POST /v1/documents/upload.
//  La lettura avviene fuori dal main actor: un PDF di manuale pesa decine di MB.
//

import Foundation
import UniformTypeIdentifiers

nonisolated struct AdminDocumentUploadFile: Sendable, Identifiable {
    let id = UUID()
    let data: Data
    let filename: String
    let mimeType: String

    var size: Int { data.count }

    /// Legge un URL di `.fileImporter` (con accesso "security scoped").
    @concurrent
    static func read(_ url: URL) async throws -> AdminDocumentUploadFile {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        return AdminDocumentUploadFile(data: data, filename: url.lastPathComponent, mimeType: mime)
    }
}
