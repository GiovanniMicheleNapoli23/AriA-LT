//
//  AdminCraftedAriaEditor+Turn.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Un turno di Aria, dall'inizio alla fine (turn, askOnce, readOnce, checkRoom e fileSession della web): lo
//  stesso stream della chat, piegato con `AriaAgentMessage.apply`; la risposta letta come modifiche, o come
//  "non ho potuto" con le sue parole; il controllo che la lettura intera ci stia nella finestra di contesto;
//  il nome e l'archiviazione delle sessioni.
//

import Foundation

extension AdminCraftedAriaEditor {
    /// Un turno, finché finisce. Si ferma subito se la richiesta è annullata o un'altra parte ha fallito.
    private func turn(_ input: String, fields: AdminCraftedAriaFields, run: AdminCraftedAriaRun?) async throws -> AriaAgentMessage {
        var message = AriaAgentMessage(id: "edit-\(fields.sessionId)", role: .assistant, finished: false)
        let request = AdminCraftedAriaPlan.request(input: input, fields: fields)
        for try await event in backend.api.stream(request) {
            if Task.isCancelled || run?.stopped == true { throw CancellationError() }
            message.apply(event)
        }
        // Uno stream interrotto da un annullamento finisce senza errore: non è una risposta intera.
        if Task.isCancelled || run?.stopped == true { throw CancellationError() }
        return message
    }

    /// Cosa ha fatto un turno invece di rispondere a parole: un errore, una domanda, una pausa, i tool.
    private func whatItDid(_ message: AriaAgentMessage) -> String {
        if let error = message.error { return "error: \(error)" }
        if let interrupt = message.interrupt { return "paused for \(interrupt.kind.rawValue)" }
        if message.elicitation != nil { return "asked a question" }
        if !message.toolCalls.isEmpty { return "ran \(message.toolCalls.map(\.name).joined(separator: ", ")) and wrote nothing" }
        return "empty answer"
    }

    func askOnce(_ input: String, blocks: [AdminCraftedAriaBlock], fields: AdminCraftedAriaFields,
                 run: AdminCraftedAriaRun?) async throws -> AdminCraftedAriaAnswer {
        let message = try await turn(input, fields: fields, run: run)
        if let answer = AdminCraftedAriaProposalParser.parse(message.text, blocks: blocks) { return answer }
        let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        throw AdminCraftedAriaError.noEdit(text: text, reason: text.isEmpty ? whatItDid(message) : nil)
    }

    /// Una parte mandata prima, da leggere e basta: quello che Aria risponde non conta, solo che il turno finisca bene.
    func readOnce(_ input: String, fields: AdminCraftedAriaFields) async throws {
        let message = try await turn(input, fields: fields, run: nil)
        if message.error != nil || message.interrupt != nil || message.elicitation != nil {
            throw AdminCraftedAriaError.noEdit(text: message.text.trimmingCharacters(in: .whitespacesAndNewlines),
                                               reason: whatItDid(message))
        }
    }

    /// Una sessione vicina alla fine della finestra riassume i suoi turni più vecchi: le prime parti
    /// arriverebbero riassunte, e una modifica fatta su un riassunto riscrive quello che non ha letto. Meglio
    /// dirlo che lasciarla indovinare. Il contatore che non risponde non è un motivo per fermarsi.
    func checkRoom(_ sessionId: String, input: String) async throws {
        guard let usage = try? await AriaChatAPI(api: backend.api).contextUsage(sessionId: sessionId) else { return }
        // Circa tre byte a token: largo, perché la stima sbagli dalla parte del pieno.
        let tokens = Double(usage.usedTokens) + Double(input.utf8.count) / 3
        let percent = usage.limitTokens > 0 ? tokens / Double(usage.limitTokens) * 100 : 0
        if (usage.compactions ?? 0) > 0 || percent >= (usage.autoCompactAt ?? .infinity) {
            throw AdminCraftedAriaError.tooLong
        }
    }

    /// Una richiesta di modifica non è una conversazione da cui imparare: fuori dall'analisi degli scenari e
    /// dai suggerimenti, sempre. La principale ha un nome leggibile e resta nella cronologia (è quella a cui
    /// "Apri la conversazione" porta); quelle in più che un documento lungo richiede si archiviano. Se il
    /// server non risponde non succede niente.
    func fileSession(_ id: String, title: String, extra: Bool) {
        let patch = AdminCraftedAriaSessionPatch(title: String(title.prefix(120)), status: extra ? "archived" : nil)
        let api = backend.api
        Task(name: "aria.crafted.fileSession") {
            _ = try? await api.perform("PATCH", "v1/agent/sessions/\(id)", body: patch)
        }
    }
}
