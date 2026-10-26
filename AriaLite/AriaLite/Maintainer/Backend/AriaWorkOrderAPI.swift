//
//  AriaWorkOrderAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Chiamate condivise `/v1/work-orders` per elenco, dettaglio, passi della procedura, foto e completamento
//  (le rotte `/v1/mobile` non esistono più). Ogni chiamata manda Authorization e Company-Id (AriaAPIClient)
//  e risponde 404 per un ordine che non è dell'operatore.
//
//  • I lavori, i passi e le foto arrivano in snake_case (`step_progress`, `reported_at`): le risposte si
//    portano in camelCase una volta sola, qui (`workOrderData`), così i modelli, la copia offline e la coda
//    non cambiano. `/v1/me` e la disponibilità sono già camelCase.
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

/// Quali ordini elencare (`status_group` di GET /v1/work-orders).
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

    private enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case sizeBytes = "size_bytes"
    }
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

    private enum CodingKeys: String, CodingKey {
        case photoId = "photo_id"
        case upload
        case expiresIn = "expires_in"
    }
}

private nonisolated struct AriaCompleteBody: Encodable, Sendable {
    let resolutionNotes: String

    private enum CodingKeys: String, CodingKey { case resolutionNotes = "resolution_notes" }
}

private extension String {
    nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension AriaAPIClient {
    private static let maxPhotoBytes = 10 * 1024 * 1024
    private static let maxNoteLength = 2000

    /// Una risposta sui lavori con le chiavi in camelCase (vedi l'intestazione). Vuota (204) resta vuota.
    @concurrent
    func workOrderData(_ method: String, _ path: String, query: [URLQueryItem] = [],
                       body: (any Encodable & Sendable)? = nil) async throws -> Data {
        let raw = try await data(method, path, query: query, body: try body.map { try JSONEncoder().encode($0) })
        return Self.camelCased(raw)
    }

    /// nonisolated: in un'estensione varrebbe il MainActor di default, e la conversione girerebbe sul main thread.
    nonisolated static func camelCased(_ raw: Data) -> Data {
        guard !raw.isEmpty, let json = try? JSONDecoder().decode(AriaJSON.self, from: raw),
              let converted = try? JSONEncoder().encode(json.camelCased()) else { return raw }
        return converted
    }

    /// Ordine con la procedura. 404 = non è più dell'operatore (`AriaError.http`, status 404).
    /// Rete e decodifica fuori dal main thread (`@concurrent`).
    @concurrent
    func workOrder(id: String) async throws -> AriaWorkOrder {
        let raw = try await workOrderData("GET", "v1/work-orders/\(id)", query: [URLQueryItem(name: "include", value: "procedure")])
        do { return try JSONDecoder().decode(AriaWorkOrder.self, from: raw) }
        catch { throw AriaError.decoding("AriaWorkOrder: \(error)") }
    }

    /// Gli ordini assegnati, a pagine di `pageSize` con `offset` crescente finché una pagina è più corta
    /// (nel frattempo ne possono arrivare o sparire: un ordine visto due volte resta uno). `maxPages` ferma
    /// un server che non finisce mai. Le chiavi sono già in camelCase.
    /// Rete, validazione e decodifica delle pagine fuori dal main thread (`@concurrent`): `AriaJSON` è Sendable.
    @concurrent
    func workOrders(_ filter: AriaWorkOrderFilter, pageSize: Int = 50, maxPages: Int = 20) async throws -> [AriaJSON] {
        let pageSize = min(max(pageSize, 1), 200)
        var orders: [AriaJSON] = []
        var seen: Set<String> = []
        for page in 0..<maxPages {
            let raw = try await workOrderData("GET", "v1/work-orders", query: [
                URLQueryItem(name: "status_group", value: filter.rawValue),
                URLQueryItem(name: "limit", value: String(pageSize)),
                URLQueryItem(name: "offset", value: String(page * pageSize)),
            ])
            // Si decodifica comunque con il modello: una risposta che l'app non sa leggere non sostituisce la copia buona.
            do { _ = try JSONDecoder().decode(AriaWorkOrderList.self, from: raw) }
            catch { throw AriaError.decoding("AriaWorkOrderList: \(error)") }
            guard let items = AriaWorkOrderOverlay.orders(inList: raw) else { throw AriaError.decoding("AriaWorkOrderList") }
            for item in items {
                guard let id = item["id"]?.stringValue else { continue }
                if seen.insert(id).inserted { orders.append(item) }
            }
            if items.count < pageSize { break }
        }
        return orders
    }

    /// Il dettaglio con la procedura come JSON libero (camelCase), per salvarlo com'è nella copia locale.
    /// Prima si controlla che l'app lo sappia leggere: uno che non si legge non sostituisce la copia buona.
    /// Tutto fuori dal main thread (`@concurrent`).
    @concurrent
    func workOrderJSON(id: String) async throws -> AriaJSON {
        let raw = try await workOrderData("GET", "v1/work-orders/\(id)", query: [URLQueryItem(name: "include", value: "procedure")])
        do { _ = try JSONDecoder().decode(AriaWorkOrder.self, from: raw) }
        catch { throw AriaError.decoding("AriaWorkOrder: \(error)") }
        return try JSONDecoder().decode(AriaJSON.self, from: raw)
    }

    // MARK: Passi

    /// Mette il risultato di un passo (o lo cambia: le foto restano). Restituisce il risultato com'è sul server
    /// (nel PUT è al livello più alto, non dentro un passo). Se la risposta non si legge, la scrittura è andata
    /// comunque a buon fine: si restituisce quello che si è mandato.
    @discardableResult
    func report(_ result: AriaStepResult, step stepId: String, of orderId: String) async throws -> AriaStepReport {
        let body = AriaStepBody(result)
        // Controlli che il server rifarebbe (422): evitano un giro a vuoto.
        if case .notDone = result, body.note.isNilOrEmpty { throw AriaError.workOrder(.noteRequired) }
        if (body.note?.count ?? 0) > Self.maxNoteLength { throw AriaError.workOrder(.noteTooLong) }
        let raw = try await workOrderData("PUT", "v1/work-orders/\(orderId)/steps/\(stepId)", body: body)
        return (try? JSONDecoder().decode(AriaStepReport.self, from: raw))
            ?? AriaStepReport(status: body.status, note: body.note)
    }

    /// Annulla il risultato di un passo e le sue foto (204).
    func clearReport(step stepId: String, of orderId: String) async throws {
        _ = try await data("DELETE", "v1/work-orders/\(orderId)/steps/\(stepId)")
    }

    // MARK: Foto

    /// Aggiunge una foto JPEG a un passo che ha già un risultato. Restituisce il passo con la foto.
    func addPhoto(jpeg: Data, step stepId: String, of orderId: String) async throws -> AriaProcedureStep {
        guard jpeg.count <= Self.maxPhotoBytes else { throw AriaError.workOrder(.photoTooLarge) }
        let base = "v1/work-orders/\(orderId)/steps/\(stepId)/photos"
        let ticket: AriaPhotoTicket = try await send(
            "POST", base, body: AriaPhotoRequestBody(mimeType: "image/jpeg", sizeBytes: jpeg.count))
        try await Self.upload(jpeg, mimeType: "image/jpeg", to: ticket.upload.url, fields: ticket.upload.fields,
                              within: TimeInterval(ticket.expiresIn))
        // Ripetere la conferma non fa danni.
        let raw = try await workOrderData("POST", "\(base)/\(ticket.photoId)/confirm")
        return try Self.decodeStep(raw)
    }

    /// Toglie una foto da un passo. Restituisce il passo.
    func removePhoto(_ photoId: String, step stepId: String, of orderId: String) async throws -> AriaProcedureStep {
        let raw = try await workOrderData("DELETE", "v1/work-orders/\(orderId)/steps/\(stepId)/photos/\(photoId)")
        return try Self.decodeStep(raw)
    }

    private nonisolated static func decodeStep(_ raw: Data) throws -> AriaProcedureStep {
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
        let session = AriaHTTP.cookielessSession()
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.upload(for: req, from: body)
        guard let http = response as? HTTPURLResponse else { throw AriaError.stream("No HTTP response") }
        // 204 = caricata. Il resto è S3 (XML), non il nostro formato d'errore.
        guard http.statusCode == 204 || (200..<300).contains(http.statusCode) else {
            throw AriaError.http(status: http.statusCode, detail: String(decoding: data.prefix(300), as: UTF8.self))
        }
    }

    // MARK: Completamento

    /// Chiude l'ordine (`completed`). Ogni passo deve avere un risultato (`steps_incomplete` con
    /// `missing`); dopo, ogni chiamata sui passi risponde `work_order_closed`. La verifica resta al desktop.
    @concurrent
    func complete(order orderId: String, resolutionNotes: String) async throws -> AriaWorkOrder {
        let raw = try await completeData(order: orderId, resolutionNotes: resolutionNotes)
        do { return try JSONDecoder().decode(AriaWorkOrder.self, from: raw) }
        catch { throw AriaError.decoding("AriaWorkOrder: \(error)") }
    }

    /// Come `complete`, con l'ordine chiuso così com'è (camelCase) per salvarlo senza rileggerlo.
    @concurrent
    func completeData(order orderId: String, resolutionNotes: String) async throws -> Data {
        let notes = resolutionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if notes.isEmpty { throw AriaError.workOrder(.resolutionNotesRequired) }
        return try await workOrderData("POST", "v1/work-orders/\(orderId)/complete",
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
