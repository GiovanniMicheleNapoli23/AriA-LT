//
//  AdminDocumentsAPI+Upload.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  POST /v1/documents/upload: multipart con la sola parte `file`; azienda, stabilimento, pipeline e
//  `replace_existing` vanno in query. Non passa da `AriaAPIClient.data` (rifiuta i body oltre 8 KB) né dalla
//  sua sessione: il corpo parte da file con AdminDocumentUploadSession, che continua anche ad app sospesa.
//  Qui si costruisce la richiesta con gli stessi header di `AriaAPIClient.request`.
//

import Foundation

nonisolated enum AdminDocumentsUploadRequest {
    /// La richiesta per un job, con un token valido adesso. La risposta (202) non è documentata: non si legge,
    /// la lista si ricarica.
    static func make(for job: AdminDocumentUploadJob, api: AriaAPIClient) async throws -> URLRequest {
        let query = [
            URLQueryItem(name: "company_id", value: job.companyId),
            URLQueryItem(name: "plant_id", value: job.plantId),
            URLQueryItem(name: "pipelines", value: job.pipelines.joined(separator: ",")),
            URLQueryItem(name: "replace_existing", value: job.replaceExisting ? "true" : "false"),
        ]
        let url = api.config.apiBaseURL.appending(path: "v1/documents/upload").appending(queryItems: query)
        // Per una sessione in background è il tempo massimo senza dati, non la durata dell'invio.
        var req = URLRequest(url: url, timeoutInterval: 300)
        req.httpMethod = "POST"
        let token = try await api.auth.validAccessToken()
        let ctx = await api.context.snapshot()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(ctx.locale, forHTTPHeaderField: "Accept-Language")
        req.setValue(job.companyId, forHTTPHeaderField: "Company-Id")
        req.setValue(api.config.clientId, forHTTPHeaderField: "X-Aria-Client")
        req.setValue(api.config.userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("multipart/form-data; boundary=\(job.boundary)", forHTTPHeaderField: "Content-Type")
        return req
    }
}
