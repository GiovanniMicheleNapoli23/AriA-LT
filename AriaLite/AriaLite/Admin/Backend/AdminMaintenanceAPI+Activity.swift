//
//  AdminMaintenanceAPI+Activity.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Allegati e storico di un piano: GET/POST/DELETE /v1/attachments, GET /download-url, GET /v1/audit-log.
//  Il `entity_type` dei piani non è documentato: `maintenance_plan` è un'IPOTESI e serve solo al caricamento.
//  Elenco allegati e storico chiedono per `entity_id` senza tipo, così una scelta sbagliata non svuota le liste
//  (gli id non si ripetono fra tipi). URL firmato e scaricamento non dipendono dall'entità: si riusano
//  da AdminWorkOrdersAPI. Il caricamento è multipart e non passa da `AriaAPIClient.data` (limite di 8 KB sul body).
//

import Foundation

nonisolated extension AdminMaintenanceAPI {
    /// Valore indovinato: verificare dal vivo guardando `entity_type` delle righe create.
    static let entityType = "maintenance_plan"

    static func attachments(planId: String) -> AriaEndpoint<AdminWorkOrderActivityList<AdminWorkOrderAttachment>> {
        AriaEndpoint.get("v1/attachments", query: ["entity_id": planId]).snakeCased()
    }

    static func deleteAttachment(id: String) -> AriaEndpoint<AriaNoContent> {
        AriaEndpoint.delete("v1/attachments/\(id)").snakeCased()
    }

    /// Le modifiche del piano, dalla più recente.
    static func auditLog(planId: String, limit: Int, offset: Int) -> AriaEndpoint<AdminWorkOrderAuditPage> {
        AriaEndpoint.get("v1/audit-log", query: [
            "entity_id": planId,
            "sort_order": "desc",
            "limit": String(limit),
            "offset": String(offset),
        ]).snakeCased()
    }

    /// Carica un file sul piano (multipart: `file`, `entity_type`, `entity_id`, `uploaded_by`).
    /// `progress` riceve la frazione inviata (0…1) da un thread qualsiasi.
    /// Restituisce l'allegato creato, o `nil` se la risposta non si legge (il file è comunque caricato).
    @concurrent
    static func uploadAttachment(_ file: AdminWorkOrderAttachmentFile, planId: String, uploadedBy: String?, api: AriaAPIClient,
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
        field("entity_type", entityType)
        field("entity_id", planId)
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
            let req = try await uploadRequest(boundary: boundary, api: api)
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
    private static func uploadRequest(boundary: String, api: AriaAPIClient) async throws -> URLRequest {
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
}
