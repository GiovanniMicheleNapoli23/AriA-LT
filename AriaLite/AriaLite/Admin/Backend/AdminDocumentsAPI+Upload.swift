//
//  AdminDocumentsAPI+Upload.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  POST /v1/documents/upload: multipart con la sola parte `file`; azienda, stabilimento, pipeline e
//  `replace_existing` vanno in query. Non passa da `AriaAPIClient.data` (rifiuta i body oltre 8 KB):
//  la richiesta si costruisce qui con gli stessi header, come `uploadAttachment` degli ordini di lavoro.
//

import Foundation

nonisolated struct AdminDocumentsUploader: Sendable {
    let api: AriaAPIClient

    /// Carica un file e fa partire le pipeline scelte. La risposta (202) non è documentata: non si legge,
    /// chi chiama ricarica la lista. `progress` riceve la frazione inviata (0…1) da un thread qualsiasi.
    @concurrent
    func upload(_ file: AdminDocumentUploadFile, companyId: String, plantId: String,
                pipelines: [String], replaceExisting: Bool,
                progress: @escaping @Sendable (Double) -> Void) async throws {
        let boundary = "aria-\(UUID().uuidString)"
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }
        // Finiscono negli header della parte: via virgolette e a capo.
        func header(_ value: String) -> String {
            String(String.UnicodeScalarView(value.unicodeScalars.filter { $0 != "\"" && $0 != "\r" && $0 != "\n" }))
        }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(header(file.filename))\"\r\n")
        append("Content-Type: \(header(file.mimeType))\r\n\r\n")
        body.append(file.data)
        append("\r\n--\(boundary)--\r\n")

        let query = [
            URLQueryItem(name: "company_id", value: companyId),
            URLQueryItem(name: "plant_id", value: plantId),
            URLQueryItem(name: "pipelines", value: pipelines.joined(separator: ",")),
            URLQueryItem(name: "replace_existing", value: replaceExisting ? "true" : "false"),
        ]
        let session = AriaHTTP.cookielessSession(.default)
        defer { session.finishTasksAndInvalidate() }
        let delegate = AdminDocumentUploadProgress(onProgress: progress)
        var retried = false
        while true {
            let req = try await request(query: query, boundary: boundary)
            let (data, response) = try await session.upload(for: req, from: body, delegate: delegate)
            // Token scaduto durante l'invio: si rinnova e si riprova una volta.
            if (response as? HTTPURLResponse)?.statusCode == 401, !retried {
                retried = true
                await api.auth.invalidate()
                continue
            }
            if let offline = AriaHTTP.hostDownError(response) { throw offline }
            try AriaHTTP.check(response, data)
            return
        }
    }

    /// Gli stessi header di `AriaAPIClient.request`, con il Content-Type multipart.
    private func request(query: [URLQueryItem], boundary: String) async throws -> URLRequest {
        let url = api.config.apiBaseURL.appending(path: "v1/documents/upload").appending(queryItems: query)
        var req = URLRequest(url: url, timeoutInterval: 300)
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

/// Avanzamento dell'invio di un documento.
nonisolated final class AdminDocumentUploadProgress: NSObject, URLSessionTaskDelegate, Sendable {
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
