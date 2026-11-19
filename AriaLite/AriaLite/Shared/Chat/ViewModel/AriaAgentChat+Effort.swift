//
//  AriaAgentChat+Effort.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il livello di sforzo di una conversazione: quello scelto dalla persona, quello salvato sul server
//  e quello che parte col prossimo messaggio. Come useChatEffort della web.
//

import Foundation

extension AriaAgentChat {
    /// Il livello mostrato: la scelta di questa visita, poi quello salvato, poi il predefinito della config.
    /// Una scelta fatta prima che il server rispondesse vince sempre su quello salvato.
    var effortLevel: AriaEffortLevel? {
        effortChoice ?? savedEffort ?? usageConfig?.effort?.defaultLevel
    }

    /// Cosa manda il prossimo messaggio: il livello solo se la config è letta e dice `chat.reply`.
    /// Con la config in lettura o illeggibile non si manda niente e decide il server. Un livello che il piano
    /// non offre più si manda lo stesso: il server abbassa la risposta e lo dice.
    var effortForTurn: AriaEffortLevel? {
        guard let config = usageConfig, config.chatEffortEnabled else { return nil }
        // Il server ha un livello che l'app non sa nominare: non lo si sovrascrive col predefinito, decide il server
        // finché la persona non sceglie.
        if effortChoice == nil, savedEffortIsUnreadable || awaitingSavedEffort { return nil }
        return effortLevel
    }

    /// Conversazione nuova o aperta: si riparte dal livello predefinito (o da quello che il server ha salvato).
    func resetEffort() {
        effortChoice = nil
        savedEffort = nil
        savedEffortIsUnreadable = false
        awaitingSavedEffort = false
        warning = nil
    }

    /// Legge il livello salvato senza bloccare il transcript (gli account che non seguono i turni sul server).
    /// Una conversazione cambiata nel frattempo non lo riceve; una scelta già fatta vince comunque (vedi `effortLevel`).
    func loadSavedEffort(of sessionId: String) async {
        guard let state = try? await AriaChatAPI(api: backend.api).sessionState(sessionId: sessionId),
              sessionId == self.sessionId else { return }
        restoreEffort(state.effort)
    }

    /// Il livello salvato che torna con la sessione. Non si riscrive mai sul server: cambia solo se la persona sceglie.
    func restoreEffort(_ raw: String?) {
        // Il server ha risposto: ora il livello di partenza è quello vero.
        awaitingSavedEffort = false
        guard let raw else { return }
        guard let level = AriaEffortLevel(rawValue: raw) else {
            savedEffortIsUnreadable = true
            return
        }
        savedEffort = level
    }

    /// La persona sceglie un livello. Se il server ha già la conversazione lo salva subito; prima del primo
    /// messaggio non c'è niente da salvare, lo porta il messaggio stesso.
    func chooseEffort(_ level: AriaEffortLevel) {
        effortChoice = level
        // Prima che il server abbia la conversazione non c'è niente da salvare: lo porta il primo messaggio.
        guard serverHoldsSession else { return }
        let api = AriaChatAPI(api: backend.api)
        let sessionId = self.sessionId
        let previous = effortSave
        effortSave = Task { [weak self] in
            await previous?.value
            do {
                try await api.saveEffort(level, sessionId: sessionId)
            } catch AriaError.http(status: 404, _) {
                // Il server non ha ancora la sessione (il primo messaggio non è partito): lo porterà il prossimo.
            } catch {
                // Conversazione cambiata o scelta già superata da un'altra: l'avviso non avrebbe senso.
                guard let self, self.sessionId == sessionId, self.effortChoice == level,
                      !(error is CancellationError) else { return }
                self.warning = String(localized: "Couldn't save this setting. Your next message will still use \(level.title).")
            }
        }
    }
}
