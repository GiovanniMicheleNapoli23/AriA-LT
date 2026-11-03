//
//  AdminDocumentUploadJob.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Un documento in caricamento: tutto quello che serve per (ri)fare POST /v1/documents/upload senza il foglio
//  che l'ha scelto. Si salva su disco accanto al corpo multipart: un caricamento sopravvive all'app sospesa
//  o chiusa dal sistema, e alla riapertura si ritrova (in corso, oppure fallito con il motivo).
//

import Foundation

nonisolated struct AdminDocumentUploadJob: Codable, Sendable, Identifiable, Hashable {
    let id: UUID
    let filename: String
    let mimeType: String
    /// Peso del file scelto (non del corpo multipart).
    let size: Int
    let boundary: String
    let companyId: String
    let plantId: String
    let pipelines: [String]
    let replaceExisting: Bool
    let createdAt: Date
    /// Il motivo dell'ultimo fallimento: il job resta in lista per riprovare o toglierlo.
    var failure: String?
    /// Tentativi fatti con un token nuovo dopo un 401.
    var authRetries = 0

    init(file: AdminDocumentUploadFile, companyId: String, plantId: String, pipelines: [String],
         replaceExisting: Bool, createdAt: Date = .now) {
        id = file.id
        filename = file.filename
        mimeType = file.mimeType
        size = file.size
        boundary = file.boundary
        self.companyId = companyId
        self.plantId = plantId
        self.pipelines = pipelines
        self.replaceExisting = replaceExisting
        self.createdAt = createdAt
    }

    var isFailed: Bool { failure != nil }
}
