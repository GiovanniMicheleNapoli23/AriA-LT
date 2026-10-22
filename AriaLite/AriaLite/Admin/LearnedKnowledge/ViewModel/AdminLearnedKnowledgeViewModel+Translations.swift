//
//  AdminLearnedKnowledgeViewModel+Translations.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I fatti nella lingua del telefono, con la stessa rotta della chat (AriaChatAPI.translateFacts).
//  La chiave è l'id del fatto; un testo modificato si richiede da capo. Ciò che non torna resta in originale.
//

import Foundation

extension AdminLearnedKnowledgeViewModel {
    /// Il testo da mostrare: la traduzione se c'è (e non si chiede l'originale), altrimenti il testo vero.
    func displayText(for fact: AdminMemoryFact) -> String {
        guard !showsOriginals else { return fact.content }
        return translations[fact.id] ?? fact.content
    }

    /// A schermo c'è la traduzione (non l'originale).
    func isTranslated(_ fact: AdminMemoryFact) -> Bool {
        guard !showsOriginals, let text = translations[fact.id] else { return false }
        return text != fact.content
    }

    /// Almeno un fatto è davvero in un'altra lingua (il server può rimandare lo stesso testo).
    var hasTranslations: Bool { translations.contains { knownFacts[$0.key]?.content != $0.value } }

    /// Chiede in un colpo solo le traduzioni dei fatti appena arrivati. Ogni fatto si chiede una volta.
    func requestTranslations(for rows: [AdminMemoryFact]) {
        guard backend.isAvailable(.factTranslation), let companyId = backend.activeCompanyId else { return }
        var batch: [String: String] = [:]
        for fact in rows where requestedTranslations.insert(fact.id).inserted {
            batch[fact.id] = fact.content
        }
        guard !batch.isEmpty else { return }
        let api = AriaChatAPI(api: backend.api)
        let locale = backend.api.context.locale
        Task {
            do {
                let result = try await api.translateFacts(companyId: companyId, locale: locale, batch)
                // Nel frattempo l'azienda è cambiata o il testo è stato modificato: si tiene solo ciò che vale ancora.
                guard companyId == backend.activeCompanyId else { return }
                for (id, text) in result where knownFacts[id]?.content == batch[id] {
                    translations[id] = text
                }
            } catch {
                backend.markUnavailable(.factTranslation, ifRefused: error)
            }
        }
    }

    /// Dopo una modifica del testo la traduzione vecchia non vale più.
    func refreshTranslation(of fact: AdminMemoryFact, previous: AdminMemoryFact?) {
        guard let previous, previous.content != fact.content else { return }
        translations[fact.id] = nil
        requestedTranslations.remove(fact.id)
        requestTranslations(for: [fact])
    }
}
