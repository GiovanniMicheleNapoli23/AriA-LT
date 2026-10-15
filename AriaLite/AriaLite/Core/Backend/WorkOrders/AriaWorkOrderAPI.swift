//
//  AriaWorkOrderAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Chiamate /v1/mobile dei passi della procedura, delle foto e del completamento.
//  Ogni chiamata manda Authorization e Company-Id (AriaAPIClient) e risponde 404 per un ordine
//  che non è dell'operatore.
//
//  • Un passo si indirizza per `id`, mai per `number`.
//  • Mettere un risultato è idempotente: si può rimandare dopo una caduta di rete.
//    Il PRIMO risultato porta l'ordine in `in_progress`.
//  • Foto: il passo deve avere già un risultato; al massimo 3 per passo, 10 MB, JPEG.
//    1) si chiede il permesso, 2) si carica su S3 (non sul nostro host: niente Authorization),
//    3) si conferma. Il permesso dura `expiresIn` secondi.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Quali ordini elencare (`status` di GET /v1/mobile/work-orders).
nonisolated enum AriaWorkOrderFilter: String, Sendable {
    case open, closed, all
}

private nonisolated struct AriaStepBody: Encodable, Sendable {
    let status: String
    let note: String?

    init(_ result: AriaStepResult) {
        switch result {
        case .done(let note):
            status = "done"
            self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        case .notDone(let note):
            status = "not_done"
            self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private enum CodingKeys: String, CodingKey { case status, note }

    /// Senza `note` il campo manca del tutto: per `done` è facoltativo.
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(note, forKey: .note)
    }
}

private nonisolated struct AriaPhotoRequestBody: Encodable, Sendable {
    let mimeType: String
    let sizeBytes: Int
}

/// 201 di POST …/photos: dove caricare il file.
private nonisolated struct AriaPhotoTicket: Decodable, Sendable {
    struct Upload: Decodable, Sendable {
        let url: URL
        let fields: [String: String]
    }
    let photoId: String
    let upload: Upload
    let expiresIn: Int
}

private nonisolated struct AriaCompleteBody: Encodable, Sendable {
    let resolutionNotes: String
}

private extension String {
    nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension AriaAPIClient {
    private static let maxPhotoBytes = 10 * 1024 * 1024
    private static let maxNoteLength = 2000

    /// Ordine con la procedura. 404 = non è più dell'operatore (`AriaError.http`, status 404).
    func workOrder(id: String) async throws -> AriaWorkOrder {
        try await get("v1/mobile/work-orders/\(id)")
    }

    // MARK: Passi

    /// Mette il risultato di un passo (o lo cambia: le foto restano). Restituisce il passo.
    func report(_ result: AriaStepResult, step stepId: String, of orderId: String) async throws -> AriaProcedureStep {
        let body = AriaStepBody(result)
        // Controlli che il server rifarebbe (422): evitano un giro a vuoto.
        if case .notDone = result, body.note.isNilOrEmpty { throw AriaError.workOrder(.noteRequired) }
        if (body.note?.count ?? 0) > Self.maxNoteLength { throw AriaError.workOrder(.noteTooLong) }
        return try await send("PUT", "v1/mobile/work-orders/\(orderId)/steps/\(stepId)", body: body)
    }

    /// Annulla il risultato di un passo e le sue foto (204).
    func clearReport(step stepId: String, of orderId: String) async throws {
        _ = try await data("DELETE", "v1/mobile/work-orders/\(orderId)/steps/\(stepId)")
    }

    // MARK: Foto

    /// Aggiunge una foto JPEG a un passo che ha già un risultato. Restituisce il passo con la foto.
    func addPhoto(jpeg: Data, step stepId: String, of orderId: String) async throws -> AriaProcedureStep {
        guard jpeg.count <= Self.maxPhotoBytes else { throw AriaError.workOrder(.photoTooLarge) }
        let base = "v1/mobile/work-orders/\(orderId)/steps/\(stepId)/photos"
        let ticket: AriaPhotoTicket = try await send(
            "POST", base, body: AriaPhotoRequestBody(mimeType: "image/jpeg", sizeBytes: jpeg.count))
        try await Self.upload(jpeg, mimeType: "image/jpeg", to: ticket.upload.url, fields: ticket.upload.fields,
                              within: TimeInterval(ticket.expiresIn))
        // Ripetere la conferma non fa danni.
        let raw = try await data("POST", "\(base)/\(ticket.photoId)/confirm")
        return try Self.decodeStep(raw)
    }

    /// Toglie una foto da un passo. Restituisce il passo.
    func removePhoto(_ photoId: String, step stepId: String, of orderId: String) async throws -> AriaProcedureStep {
        let raw = try await data("DELETE", "v1/mobile/work-orders/\(orderId)/steps/\(stepId)/photos/\(photoId)")
        return try Self.decodeStep(raw)
    }

    private static func decodeStep(_ raw: Data) throws -> AriaProcedureStep {
        do { return try JSONDecoder().decode(AriaProcedureStep.self, from: raw) }
        catch { throw AriaError.decoding("AriaProcedureStep: \(error)") }
    }

    /// POST multipart a S3: ogni `fields` come parte di testo, poi il file per ULTIMO con nome `file`.
    /// Il `Content-Type` del file deve essere quello dichiarato e la dimensione non oltre quella dichiarata,
    /// altrimenti S3 risponde 403. Niente Authorization: non è il nostro host.
    private static func upload(_ file: Data, mimeType: String, to url: URL, fields: [String: String],
                               within seconds: TimeInterval) async throws {
        // L'URL viene dal server: solo https. Nomi e valori finiscono nel body come testo: niente a capo
        // (né virgolette nei nomi) che spezzino le parti. Si controlla prima di mandare qualsiasi cosa.
        guard url.scheme?.lowercased() == "https" else { throw AriaError.decoding("upload url") }
        func hasBreak(_ text: String) -> Bool { text.unicodeScalars.contains { $0 == "\r" || $0 == "\n" } }
        for (name, value) in fields where hasBreak(name) || name.contains("\"") || hasBreak(value) {
            throw AriaError.decoding("upload field")
        }
        let boundary = "aria-\(UUID().uuidString)"
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }
        for (name, value) in fields {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(file)
        append("\r\n--\(boundary)--\r\n")

        var req = URLRequest(url: url, timeoutInterval: max(10, seconds))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await AriaHTTP.cookielessSession().upload(for: req, from: body)
        guard let http = response as? HTTPURLResponse else { throw AriaError.stream("No HTTP response") }
        // 204 = caricata. Il resto è S3 (XML), non il nostro formato d'errore.
        guard http.statusCode == 204 || (200..<300).contains(http.statusCode) else {
            throw AriaError.http(status: http.statusCode, detail: String(decoding: data.prefix(300), as: UTF8.self))
        }
    }

    // MARK: Completamento

    /// Chiude l'ordine (`completed`). Ogni passo deve avere un risultato (`steps_incomplete` con
    /// `missing`); dopo, ogni chiamata sui passi risponde `work_order_closed`. La verifica resta al desktop.
    func complete(order orderId: String, resolutionNotes: String) async throws -> AriaWorkOrder {
        let notes = resolutionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if notes.isEmpty { throw AriaError.workOrder(.resolutionNotesRequired) }
        return try await send("POST", "v1/mobile/work-orders/\(orderId)/complete",
                              body: AriaCompleteBody(resolutionNotes: notes))
    }
}

private extension Optional where Wrapped == String {
    nonisolated var isNilOrEmpty: Bool { self?.isEmpty ?? true }
}

#if canImport(UIKit)
/// La foto scattata (o scelta) in JPEG sotto il limite di 10 MB: i desktop non mostrano HEIC.
nonisolated enum AriaPhoto {
    /// `nil` se i dati non sono un'immagine. Riduce la qualità, poi le dimensioni, finché ci sta.
    static func jpeg(from data: Data, maxBytes: Int = 10 * 1024 * 1024) -> Data? {
        UIImage(data: data).flatMap { jpeg(from: $0, maxBytes: maxBytes) }
    }

    static func jpeg(from source: UIImage, maxBytes: Int = 10 * 1024 * 1024) -> Data? {
        var image = source
        for _ in 0..<4 {
            for quality in [0.85, 0.6, 0.4] {
                if let jpeg = image.jpegData(compressionQuality: quality), jpeg.count <= maxBytes { return jpeg }
            }
            // Scala 1: la dimensione è in pixel, non in punti.
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            let size = CGSize(width: image.size.width * image.scale * 0.7, height: image.size.height * image.scale * 0.7)
            image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }
        return nil
    }
}
#endif
