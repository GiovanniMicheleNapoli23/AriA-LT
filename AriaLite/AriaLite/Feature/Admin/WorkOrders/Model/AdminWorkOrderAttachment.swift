//
//  AdminWorkOrderAttachment.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un allegato di un ordine (AttachmentResponse di /v1/attachments) e le righe della scheda File:
//  quelle già caricate e quelle in caricamento.
//

import Foundation

nonisolated struct AdminWorkOrderAttachment: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    var filename: String?
    var mimeType: String?
    var sizeBytes: Int?
    var uploadedBy: String?
    var createdAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, underscoreId = "_id", attachmentId
        case filename, originalFilename, name, mimeType, contentType, sizeBytes, size, uploadedBy, createdAt
    }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        guard let id = f.id(.id) ?? f.id(.underscoreId) ?? f.id(.attachmentId) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "id"))
        }
        self.id = id
        filename = f.text(.filename) ?? f.text(.originalFilename) ?? f.text(.name)
        mimeType = f.text(.mimeType) ?? f.text(.contentType)
        sizeBytes = f.int(.sizeBytes) ?? f.int(.size)
        uploadedBy = f.text(.uploadedBy)
        createdAt = f.date(.createdAt)
    }
}

/// Riga di un allegato già sul server.
nonisolated struct AdminWorkOrderAttachmentRowItem: Identifiable, Hashable, Sendable {
    let id: String
    let filename: String
    let icon: String
    /// "1,2 MB · Mario Rossi · 2 h fa".
    let subtitle: String
    let isOpening: Bool
}

/// Un file in caricamento: resta in lista con la sua barra finché il server non risponde.
nonisolated struct AdminWorkOrderAttachmentUpload: Identifiable, Hashable, Sendable {
    let id: UUID
    let filename: String
    /// 0…1.
    var progress: Double
}

/// Un file pronto da mandare.
nonisolated struct AdminWorkOrderAttachmentFile: Sendable {
    let data: Data
    let filename: String
    let mimeType: String
}

nonisolated enum AdminWorkOrderAttachmentKind {
    /// Simbolo SF per tipo MIME, o per estensione se il tipo manca.
    static func icon(mimeType: String?, filename: String?) -> String {
        let mime = mimeType?.lowercased() ?? ""
        let ext = (filename as NSString?)?.pathExtension.lowercased() ?? ""
        if mime.hasPrefix("image/") || ["jpg", "jpeg", "png", "heic", "gif", "webp"].contains(ext) { return "photo" }
        if mime.hasPrefix("video/") || ["mov", "mp4", "m4v"].contains(ext) { return "film" }
        if mime.hasPrefix("audio/") || ["m4a", "mp3", "wav"].contains(ext) { return "waveform" }
        if mime == "application/pdf" || ext == "pdf" { return "doc.richtext" }
        if mime.contains("spreadsheet") || mime.contains("excel") || ["xls", "xlsx", "csv", "numbers"].contains(ext) {
            return "tablecells"
        }
        if mime.contains("zip") || ["zip", "rar", "7z"].contains(ext) { return "doc.zipper" }
        if mime.hasPrefix("text/") || mime.contains("word") || ["txt", "doc", "docx", "rtf", "md"].contains(ext) {
            return "doc.text"
        }
        return "doc"
    }
}
