//
//  AriaChatAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 25/09/26.
//
//  Endpoint REST usati dalla chat oltre allo stream: storico sessioni, turni, checklist,
//  suggerimenti, contesto, feedback, memoria, closeout e report. Ogni rotta è un AriaEndpoint (vedi AriaEndpoint.swift).
//
//  Le rotte sono quelle condivise del backend (`/v1/mobile/*` non esiste più): storico, turni (riaggancio e
//  Stop), checklist, rinomina ed elimina stanno sotto /v1/agent/sessions; feedback, review, learning e il
//  contatore del contesto sotto /v1/chat/sessions; fatti imparati, closeout e report sotto /v1/companies/{id}.
//  Dal 20/10/2026 l'operatore ha anche suggerimenti, contesto, conferma e traduzione dei fatti, closeout,
//  report e .docx (guida "operator member parity"). Su un backend che non le ha ancora rispondono
//  403 `operation_forbidden` → `AriaError.notOnPhone`: la funzione si nasconde, non si riprova.
//  Closeout, report, .docx e contesto valgono solo per le sessioni dell'operatore: quelle degli altri sono 404.
//

import Foundation

nonisolated struct AriaChatAPI: Sendable {
    let api: AriaAPIClient

    /// L'operatore (accesso col link): ha solo le operazioni da campo elencate nella guida.
    var isOperator: Bool { api.auth.isMobileSession }

    /// Storico, messaggi, turni e checklist di una sessione.
    private let history = "v1/agent/sessions"
    /// Feedback, review e learning di una sessione.
    private let feedback = "v1/chat/sessions"

    // MARK: Sessioni

    /// Una pagina di storico. Le sessioni `__briefing-*` sono interne e si nascondono.
    func sessions(limit: Int = 60, offset: Int = 0) async throws -> [AriaSessionSummary] {
        try await api.call(.get(history, query: ["limit": "\(limit)", "offset": "\(offset)"]))
    }

    func messages(sessionId: String) async throws -> [AriaPersistedMessage] {
        let rows: AriaLossyArray<AriaPersistedMessage> = try await api.call(.get("\(history)/\(sessionId)/messages"))
        return rows.items
    }

    /// `{"interrupt": null}` quando non c'è nessuna pausa; un 404 vuol dire solo sessione sconosciuta: mai un errore.
    func pendingInterrupt(sessionId: String) async -> AriaInterrupt? {
        let response: AriaPendingInterruptResponse? = try? await api.call(.get("\(history)/\(sessionId)/pending-interrupt"))
        return response?.interrupt
    }

    func rename(sessionId: String, title: String) async throws {
        try await api.perform("PATCH", "v1/agent/sessions/\(sessionId)", body: ["title": title])
    }

    func delete(sessionId: String) async throws {
        try await api.perform("DELETE", "v1/agent/sessions/\(sessionId)")
    }

    // MARK: Turni e checklist

    /// Spunte salvate e turno ancora aperto (`active_turn`: `running` o `paused`).
    func sessionState(sessionId: String) async throws -> AriaChatSessionState {
        try await api.call(.get("\(history)/\(sessionId)"))
    }

    /// Lo stato del turno: si interroga ogni ~2 s finché resta `running`.
    func turn(_ responseId: String, sessionId: String) async throws -> AriaTurn {
        try await api.call(.get("\(history)/\(sessionId)/turns/\(responseId)"))
    }

    /// Stop: chiudere lo stream di un turno in background non ferma la risposta. 202, poi si segue il turno finché non è più `running`.
    /// Un turno già finito (409 `turn_not_running`) non è un errore.
    func cancelTurn(_ responseId: String, sessionId: String) async throws {
        do {
            try await api.perform("POST", "\(history)/\(sessionId)/turns/\(responseId)/cancel")
        } catch AriaError.turnConflict(let conflict) where conflict.code == .turnNotRunning {
            return
        }
    }

    /// Sostituisce tutte le spunte della sessione: si mandano solo quelle spuntate (body sotto gli 8 KB).
    func saveChecklist(_ checked: some Sequence<String>, sessionId: String) async throws {
        try await api.perform("PUT", "\(history)/\(sessionId)/checklist", body: AriaChecklist(checked: checked))
    }

    // MARK: Suggerimenti e contesto

    /// I chip di una chat vuota, nella lingua di `Accept-Language` (la lingua dell'app). Una lista vuota è
    /// una risposta valida (utente nuovo, generazione non disponibile): niente chip, nessun errore.
    func suggestions() async throws -> [String] {
        let response: AriaSuggestionsResponse = try await api.call(.get("v1/chat/suggestions"))
        return response.suggestions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// Quanto della finestra di contesto usa la sessione. 404 = sessione che il server non conosce ancora
    /// (chat nuova) o di un altro: nessun contatore.
    func contextUsage(sessionId: String) async throws -> AriaContextUsage? {
        do { return try await api.call(.get("\(feedback)/\(sessionId)/context")) }
        catch AriaError.http(let status, _) where status == 404 { return nil }
    }

    /// "Fai spazio": riassume subito i turni più vecchi. Restituisce l'uso DOPO la compattazione; una sessione
    /// senza niente da riassumere torna uguale, non è un errore. Lo storico salvato resta intero.
    func compactContext(sessionId: String) async throws -> AriaContextUsage? {
        do { return try await api.call(.post("\(feedback)/\(sessionId)/context/compact")) }
        catch AriaError.http(let status, _) where status == 404 { return nil }
    }

    // MARK: Feedback

    private nonisolated struct AnswerFeedback: Encodable, Sendable {
        let vote: String
        let messageId: String
        let note: String?
        let answer: String?
        let question: String?
    }

    /// Pollice su/giù. Ripetere lo stesso voto lo ritira: decide il campo `vote` della risposta.
    func answerFeedback(sessionId: String, vote: String, messageId: String, note: String?,
                        answer: String?, question: String?) async throws -> AriaAnswerFeedbackResponse {
        try await api.call(.post("\(feedback)/\(sessionId)/feedback/answer",
                                 body: AnswerFeedback(vote: vote, messageId: messageId, note: note, answer: answer, question: question)))
    }

    private nonisolated struct StepFeedback: Encodable, Sendable {
        let action: String
        let step: Int
        let task: String
        let stepKind: String
        let stepTitle: String
        let stepLabel: String
    }

    /// Segnale su un task di procedura: failed | unclear | modify | custom.
    func stepFeedback(sessionId: String, action: String, taskList: AriaTaskList, task: String) async {
        let body = StepFeedback(action: action, step: taskList.stepNumber, task: task,
                                stepKind: taskList.isSafety ? "safety" : "technical",
                                stepTitle: taskList.stepTitle, stepLabel: taskList.label)
        try? await api.perform("POST", "\(feedback)/\(sessionId)/feedback/step", body: body)
    }

    private nonisolated struct Review: Encodable, Sendable {
        let outcome: String
        let rating: Int?
        let issues: String?
    }

    func review(sessionId: String, outcome: String, rating: Int?, issues: String?) async throws {
        try await api.perform("POST", "\(feedback)/\(sessionId)/review",
                              body: Review(outcome: outcome, rating: rating, issues: issues))
    }

    private nonisolated struct LearningAnswer: Encodable, Sendable {
        let key: String?
        let value: String?
        let text: String
        let custom: String
    }

    func learning(sessionId: String, answers: [AriaElicitationAnswer]) async {
        let body = ["answers": answers.map { LearningAnswer(key: $0.key, value: $0.value, text: $0.text, custom: $0.custom) }]
        try? await api.perform("POST", "\(feedback)/\(sessionId)/learning", body: body)
    }

    // MARK: Memoria

    private nonisolated struct Validation: Encodable, Sendable {
        let question: String
        let answer: String
        let feedback: String
        let plantId: String
        let sessionId: String?
    }

    /// Risposta al Real-time Learning: diventa conoscenza dello stabilimento (fatti PENDING), mai un turno di chat.
    /// `plantId` è obbligatorio, e se la sessione ha già uno stabilimento deve essere lo stesso (422).
    /// I campi si tagliano ai limiti del server (buildValidationBody della web): meglio corto che un 422.
    func submitValidation(companyId: String, plantId: String, sessionId: String, question: String,
                          answer: String, feedback: String) async throws -> AriaMemoryValidationResponse {
        let body = Validation(question: String(question.prefix(4000)), answer: String(answer.prefix(8000)),
                              feedback: String(feedback.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000)),
                              plantId: plantId, sessionId: sessionId)
        return try await api.call(.post("v1/companies/\(companyId)/memory-facts/validation", body: body))
    }

    /// La scelta sulla card di un fatto imparato. `accept` è una segnalazione, non un'approvazione: il fatto
    /// resta in attesa e va agli owner e admin dell'azienda ("inviato per la revisione", non "salvato").
    /// `content`: la formulazione corretta dall'operatore (non per un fatto in `conflict`: 422).
    /// 404 = il fatto non c'è più (si toglie la card); 409 = già deciso o cambiato (si mostra `error.message`).
    @discardableResult
    func confirmMemory(companyId: String, factId: String, accept: Bool, content: String? = nil) async throws -> AriaMemoryFact {
        let content = content?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = AriaMemoryDecision(decision: accept ? .accept : .reject,
                                      content: accept && content?.isEmpty == false ? content : nil)
        return try await api.call(.post("v1/companies/\(companyId)/memory-facts/\(factId)/confirm", body: body))
    }

    /// I fatti nella lingua dell'operatore: chiave (scelta dall'app) → testo tradotto. Una chiave che manca
    /// vuol dire "mostra l'originale". Il server traduce al massimo 60 testi per richiesta e il firewall
    /// ferma i body da 8 KB: si manda a lotti. Un lotto che fallisce lascia i suoi testi in originale;
    /// solo `notOnPhone` (backend senza la rotta) esce, per nascondere la funzione.
    func translateFacts(companyId: String, locale: String, _ texts: [String: String]) async throws -> [String: String] {
        let items = texts.sorted { $0.key < $1.key }.compactMap { key, text -> AriaFactTranslationRequest.Item? in
            let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text.count <= AriaFactTranslationRequest.maxTextLength else { return nil }
            return .init(id: key, text: text)
        }
        var out: [String: String] = [:]
        for batch in Self.translationBatches(items, locale: locale, maxBytes: api.config.maxBodyBytes) {
            do {
                let response: AriaFactTranslationResponse = try await api.call(.post(
                    "v1/companies/\(companyId)/memory-facts/translations",
                    body: AriaFactTranslationRequest(locale: locale, items: batch)))
                for (key, value) in response.translations where !value.isEmpty { out[key] = value }
            } catch AriaError.notOnPhone {
                throw AriaError.notOnPhone
            } catch {
                continue
            }
        }
        return out
    }

    /// Lotti di al massimo 60 testi il cui body JSON resta sotto `maxBytes`. Un testo che da solo non ci sta
    /// resta fuori (si mostra l'originale).
    static func translationBatches(_ items: [AriaFactTranslationRequest.Item], locale: String,
                                   maxBytes: Int) -> [[AriaFactTranslationRequest.Item]] {
        func size(_ batch: [AriaFactTranslationRequest.Item]) -> Int {
            (try? JSONEncoder().encode(AriaFactTranslationRequest(locale: locale, items: batch)).count) ?? .max
        }
        var batches: [[AriaFactTranslationRequest.Item]] = []
        var current: [AriaFactTranslationRequest.Item] = []
        for item in items {
            guard size([item]) <= maxBytes else { continue }
            if current.count == AriaFactTranslationRequest.maxItems || size(current + [item]) > maxBytes {
                batches.append(current)
                current = []
            }
            current.append(item)
        }
        if !current.isEmpty { batches.append(current) }
        return batches
    }

    // MARK: Closeout e report

    private func sessionPath(_ companyId: String, _ sessionId: String) -> String {
        "v1/companies/\(companyId)/sessions/\(sessionId)"
    }

    /// Senza `confirm` restituisce solo la proposta (niente scritto); con `confirm: true` scrive in ARIA
    /// (e MaintainX). Riprovare `confirm: true` dopo un errore a metà è sicuro: l'ordine già creato torna, non
    /// se ne crea un secondo. Per l'operatore il body passa da `limitedToOperator` (mai "shift", assegnatario
    /// solo sé stesso): il server risponderebbe 422.
    func closeout(companyId: String, sessionId: String, _ request: AriaCloseoutRequest,
                  operatorId: String? = nil) async throws -> AriaCloseoutResult {
        let body = isOperator ? request.limitedToOperator(operatorId) : request
        return try await api.call(.post("\(sessionPath(companyId, sessionId))/closeout", body: body))
    }

    /// Archivia il report senza closeout. `workOrderId` deve essere un ordine assegnato all'operatore
    /// (altrimenti 404 `work_order_not_found`); senza, il report va sulla sessione di chat.
    func archiveReport(companyId: String, sessionId: String,
                       _ request: AriaReportArchiveRequest = .init()) async throws -> AriaReportArchive {
        try await api.call(.post("\(sessionPath(companyId, sessionId))/report", body: request))
    }

    static let docxType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

    /// Il report come file Word, scritto in un file temporaneo da condividere. Niente si salva sul server.
    /// `locale`: la lingua del report (la conversazione non si traduce); `episode`: una procedura precedente
    /// della stessa chat (da 1); `workOrderId`: l'ordine stampato sul documento.
    @concurrent
    func reportDocument(companyId: String, sessionId: String, locale: String, episode: Int? = nil,
                        title: String? = nil, workOrderId: String? = nil) async throws -> AriaReportFile {
        var query = [URLQueryItem(name: "locale", value: locale)]
        if let episode { query.append(URLQueryItem(name: "episode", value: "\(episode)")) }
        if let title, !title.isEmpty { query.append(URLQueryItem(name: "title", value: title)) }
        if let workOrderId { query.append(URLQueryItem(name: "work_order_id", value: workOrderId)) }
        let (data, http) = try await api.response("GET", "\(sessionPath(companyId, sessionId))/report.docx",
                                                  query: query, headers: ["Accept": Self.docxType])
        let filename = Self.filename(fromContentDisposition: http.value(forHTTPHeaderField: "Content-Disposition"))
            ?? "Aria report.docx"
        let folder = FileManager.default.temporaryDirectory.appending(path: "aria-report-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: filename)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        return AriaReportFile(url: url, filename: filename)
    }

    /// Il nome da `Content-Disposition` (`filename*=UTF-8''…` vince su `filename="…"`), senza percorsi.
    static func filename(fromContentDisposition header: String?) -> String? {
        guard let header else { return nil }
        var plain: String?
        var extended: String?
        for part in header.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard pair.count == 2 else { continue }
            switch pair[0].lowercased() {
            case "filename*":
                let value = pair[1].split(separator: "'", maxSplits: 2, omittingEmptySubsequences: false).last.map(String.init)
                extended = value?.removingPercentEncoding
            case "filename":
                plain = pair[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            default: break
            }
        }
        guard let name = (extended ?? plain)?.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init),
              !name.isEmpty, name != ".", name != ".." else { return nil }
        return name
    }
}

/// Una risposta a un passo di domanda guidata (ElicitationAnswer della web).
nonisolated struct AriaElicitationAnswer: Sendable, Hashable {
    var key: String?
    var value: String?
    var text: String
    var custom: String
    var file: String?
}
