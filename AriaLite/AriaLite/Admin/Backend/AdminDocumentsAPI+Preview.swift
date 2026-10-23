//
//  AdminDocumentsAPI+Preview.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il file originale di un documento, scaricato in una cartella temporanea per Quick Look.
//  Il link è quello di `source.uri` (un URL pubblico o firmato): niente token né cookie, che a un
//  host esterno non vanno mandati. L'API non ha (ancora) una rotta che dia il file di un caricamento.
//

import Foundation
import UniformTypeIdentifiers

nonisolated extension AdminDocumentsAPI {
    /// Scarica il file e lo salva con il suo nome (Quick Look sceglie come mostrarlo dall'estensione).
    @concurrent
    static func downloadFile(_ url: URL, documentId: String, fileName: String?, mimeType: String?) async throws -> URL {
        guard url.scheme?.lowercased() == "https" else { throw AriaError.decoding("source.uri") }
        let session = AriaHTTP.cookielessSession()
        defer { session.finishTasksAndInvalidate() }
        let (temporary, response) = try await session.download(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AriaError.http(status: status, detail: String(localized: "Download failed"))
        }
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "AdminDocumentPreviews", directoryHint: .isDirectory)
            .appending(path: safeName(documentId), directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appending(path: previewName(fileName: fileName, url: url, mimeType: mimeType))
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }

    /// Il nome del file, poi l'ultimo pezzo del link; senza estensione la prende dal tipo MIME.
    private static func previewName(fileName: String?, url: URL, mimeType: String?) -> String {
        let base = safeName(fileName ?? url.lastPathComponent)
        guard (base as NSString).pathExtension.isEmpty,
              let ext = mimeType.flatMap({ UTType(mimeType: $0)?.preferredFilenameExtension }) else { return base }
        return "\(base).\(ext)"
    }

    private static func safeName(_ name: String) -> String {
        let cleaned = name.replacing("/", with: "-").replacing(":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return cleaned.isEmpty ? "document" : String(cleaned.prefix(120))
    }
}
