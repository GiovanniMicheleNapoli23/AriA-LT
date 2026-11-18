//
//  AriaAgentChat+Credits.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I crediti sotto una risposta: la config che li descrive, e il recupero di quanto è costata una risposta
//  fermata o interrotta, che lo stream non ha fatto in tempo a dire.
//

import Foundation

extension AriaAgentChat {
    /// Dopo quanto si riprova a leggere il costo di una risposta fermata (il server la chiude qualche istante dopo).
    static var usageBackfillDelay: Duration = .seconds(3)

    /// La config dei crediti dell'azienda attiva (nil finché non è letta, o se non si è riusciti a leggerla).
    var usageConfig: AriaUsageConfig? { backend.usage.config }

    /// La config serve a decidere se il messaggio porta il livello: se non c'è ancora si chiede, senza aspettarla.
    func warmUsageConfig() {
        // Il negozio applica da solo i 60 s di freschezza e unisce le richieste uguali: si chiede sempre.
        Task { [usage = backend.usage] in await usage.loadConfig() }
    }

    /// Una risposta che non è finita col suo evento di fine (Stop, stream chiuso prima, errore dopo che lo stream era
    /// partito) e non ha il costo: lo si legge dal messaggio salvato dal server, riconosciuto dall'id della risposta.
    /// Una volta subito e una dopo ~3 s se ancora manca; in silenzio. Chi chiama lo fa solo per i turni finiti così.
    func backfillTurnUsage(of messageId: String) {
        // Senza nota sotto la risposta (`ui.credit_note_mode` spento) il costo non serve.
        guard usageConfig?.showsCreditNote != false else { return }
        guard let message = messages.first(where: { $0.id == messageId }), message.role == .assistant,
              message.turnUsage == nil, let responseId = message.responseId else { return }
        let sessionId = self.sessionId
        let api = AriaChatAPI(api: backend.api)
        Task { [weak self] in
            for attempt in 0..<2 {
                if attempt > 0 { try? await Task.sleep(for: Self.usageBackfillDelay) }
                // Un'altra conversazione aperta nel frattempo non si tocca.
                guard let self, self.sessionId == sessionId else { return }
                guard let rows = try? await api.messages(sessionId: sessionId) else { continue }
                let row = rows.first { $0.role == "assistant" && $0.responseId == responseId }
                let events = AriaAgentMessage.turnUsageEvents(in: row?.pipeline)
                // Dopo la risposta del server la conversazione può essere cambiata, o il costo essere già arrivato.
                guard self.sessionId == sessionId,
                      let current = self.messages.first(where: { $0.id == messageId }), current.turnUsage == nil else { return }
                guard !events.isEmpty else { continue }
                self.update(messageId) { $0.turnUsageEvents = events }
                // La risposta è saldata: il saldo letto a fine turno poteva non contarla ancora.
                self.backend.usage.refreshAllowanceLater()
                return
            }
        }
    }
}
