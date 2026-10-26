//
//  AdminWorkOrdersAPI+Activity.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Attività e allegati di un ordine: messaggi (GET/POST /v1/work-orders/{id}/messages), storico
//  (GET /v1/audit-log) e file (GET/POST/DELETE /v1/attachments, GET /download-url).
//  L'entità degli ordini si chiama `work_order` sia nello storico sia negli allegati (non documentato).
//  Il caricamento non passa da `AriaAPIClient.data`: quel client rifiuta i body oltre `maxBodyBytes`
//  (8 KB, pensato per /v1/responses), quindi la richiesta multipart si costruisce qui con gli stessi header.
//

import Foundation

nonisolated extension AdminWorkOrdersAPI {
    static let entityType = "work_order"

    // MARK: Messaggi

    /// Il formato della risposta non è documentato: array semplice o `{items}`.
    func messages(_ id: String) async throws -> [AdminWorkOrderMessage] {
        let rows: AdminWorkOrderActivityList<AdminWorkOrderMessage> = try await api.call(.get("\(root)/\(id)/messages").snakeCased())
        return rows.items
    }

    /// 201 con un corpo non documentato: non si legge, chi chiama ricarica l'elenco.
    func postMessage(_ id: String, author: String, content: String) async throws {
        let body = AdminWorkOrderMessageCreate(author: author, content: content, workOrderId: id)
        let _: AriaNoContent = try await api.call(.post("\(root)/\(id)/messages", body: body).snakeCased())
    }

    // MARK: Storico

    /// Le modifiche dell'ordine, dalla più recente.
    func auditLog(_ id: String, limit: Int, offset: Int) async throws -> AdminWorkOrderAuditPage {
        try await api.call(.get("v1/audit-log", query: [
            "entity_type": Self.entityType,
            "entity_id": id,
            "sort_order": "desc",
            "limit": String(limit),
            "offset": String(offset),
        ]).snakeCased())
    }

    // MARK: Allegati

    func attachments(_ id: String) async throws -> [AdminWorkOrderAttachment] {
        let rows: AdminWorkOrderActivityList<AdminWorkOrderAttachment> = try await api.call(
            .get("v1/attachments", query: ["entity_type": Self.entityType, "entity_id": id]).snakeCased())
        return rows.items
    }

    func deleteAttachment(_ attachmentId: String) async throws {
        let _: AriaNoContent = try await api.call(.delete("v1/attachments/\(attachmentId)").snakeCased())
    }

    /// URL S3 firmato (vale 5 minuti). Risposta non documentata: `{url}`, `{download_url}` o una stringa.
    /// Solo https.
    func downloadURL(_ attachmentId: String) async throws -> URL {
        let raw = try await api.data("GET", "v1/attachments/\(attachmentId)/download-url")
        let text: String?
        if let json = try? JSONDecoder().decode(AriaJSON.self, from: raw) {
            text = json.nonEmptyString ?? json["url"]?.nonEmptyString ?? json["download_url"]?.nonEmptyString
                ?? json["downloadUrl"]?.nonEmptyString ?? json["presigned_url"]?.nonEmptyString
        } else {
            text = String(decoding: raw, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let text, let url = URL(string: text), url.scheme?.lowercased() == "https" else {
            throw AriaError.decoding("download-url")
        }
        return url
    }

    /// Scarica il file dall'URL firmato (niente Authorization: è S3) in una cartella temporanea, con il suo nome,
    /// così l'anteprima mostra il titolo giusto.
    @concurrent
    func download(_ url: URL, attachmentId: String, filename: String) async throws -> URL {
        guard url.scheme?.lowercased() == "https" else { throw AriaError.decoding("download-url") }
        let session = AriaHTTP.cookielessSession()
        defer { session.finishTasksAndInvalidate() }
        let (temporary, response) = try await session.download(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AriaError.http(status: status, detail: String(localized: "Download failed"))
        }
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "AdminWorkOrderFiles", directoryHint: .isDirectory)
            .appending(path: Self.safeName(attachmentId), directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appending(path: Self.safeName(filename))
        try FileManager.default.moveItem(at: temporary, to: destination)
        AriaLocalFiles.protect(destination)
        return destination
    }

    /// Carica un file sull'ordine (multipart: `file`, `entity_type`, `entity_id`, `uploaded_by`).
    /// `progress` riceve la frazione inviata (0…1) da un thread qualsiasi.
    /// Restituisce l'allegato creato, o `nil` se la risposta non si legge (il file è comunque caricato).
    @concurrent
    func uploadAttachment(_ file: AdminWorkOrderAttachmentFile, orderId: String, uploadedBy: String?,
                          progress: @escaping @Sendable (Double) -> Void) async throws -> AdminWorkOrderAttachment? {
        let boundary = "aria-\(UUID().uuidString)"
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }
        // Finiscono negli header delle parti: via virgolette e a capo.
        func header(_ value: String) -> String {
            String(String.UnicodeScalarView(value.unicodeScalars.filter { $0 != "\"" && $0 != "\r" && $0 != "\n" }))
        }
        func field(_ name: String, _ value: String) {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(header(value))\r\n")
        }
        field("entity_type", Self.entityType)
        field("entity_id", orderId)
        if let uploadedBy, !uploadedBy.isEmpty { field("uploaded_by", uploadedBy) }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(header(file.filename))\"\r\n")
        append("Content-Type: \(header(file.mimeType))\r\n\r\n")
        body.append(file.data)
        append("\r\n--\(boundary)--\r\n")

        let session = AriaHTTP.cookielessSession(.default)
        defer { session.finishTasksAndInvalidate() }
        let delegate = AdminWorkOrderAttachmentProgress(onProgress: progress)
        var retried = false
        while true {
            let req = try await uploadRequest(boundary: boundary)
            let (data, response) = try await session.upload(for: req, from: body, delegate: delegate)
            if (response as? HTTPURLResponse)?.statusCode == 401, !retried {
                retried = true
                await api.auth.invalidate()
                continue
            }
            if let offline = AriaHTTP.hostDownError(response) { throw offline }
            try AriaHTTP.check(response, data)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try? decoder.decode(AdminWorkOrderAttachment.self, from: data)
        }
    }

    /// Gli stessi header di `AriaAPIClient.request`, con il Content-Type multipart.
    private func uploadRequest(boundary: String) async throws -> URLRequest {
        var req = URLRequest(url: api.config.apiBaseURL.appending(path: "v1/attachments"), timeoutInterval: 300)
        req.httpMethod = "POST"
        let token = try await api.auth.validAccessToken()
        let ctx = await api.context.snapshot()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(ctx.locale, forHTTPHeaderField: "Accept-Language")
        if let companyId = ctx.companyId { req.setValue(companyId, forHTTPHeaderField: "Company-Id") }
        req.setValue(api.config.clientId, forHTTPHeaderField: "X-Aria-Client")
        req.setValue(api.config.userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        return req
    }

    /// Un nome di file sicuro per il disco: niente barre, niente nomi nascosti.
    private static func safeName(_ name: String) -> String {
        let cleaned = name.replacing("/", with: "-").replacing(":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return cleaned.isEmpty ? "file" : String(cleaned.prefix(120))
    }
}

/// Avanzamento dell'invio di un caricamento.
nonisolated final class AdminWorkOrderAttachmentProgress: NSObject, URLSessionTaskDelegate, Sendable {
    let onProgress: @Sendable (Double) -> Void

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        onProgress(min(1, Double(totalBytesSent) / Double(totalBytesExpectedToSend)))
    }
}
