//
//  AdminUsageBillingViewModel+Recipients.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Usage notices" (contratto 5.3). Non c'è un bottone "Save": ogni aggiunta o rimozione manda la lista intera, una
//  richiesta alla volta. I membri li legge la pagina (la stessa chiamata dà i nomi); dopo il PUT la risposta torna alla
//  pagina (`applyRecipients`). Un id che il server tiene ma non è fra i membri attivi si vede solo dal 422.
//

import Foundation

extension AdminUsageBillingViewModel {
    // MARK: Cosa mostra la scheda

    /// I membri attivi, dalla pagina.
    var members: [AriaNoticeRecipients.Member] { page.members }

    /// La lista degli aggiunti: la bozza finché il salvataggio non si chiude, altrimenti `added` dei membri.
    var recipientIds: [String] {
        AdminUsageNoticeRecipientsBuilder.ids(members: page.members, draft: recipientDraft)
    }

    var recipientsCard: AdminUsageNoticeRecipientsCard {
        AdminUsageNoticeRecipientsBuilder.card(
            members: page.members, ids: recipientIds, refused: recipientRefused,
            emailEnabled: backend.usage.config?.emailNotificationsEnabled == true, locale: page.locale)
    }

    func candidates(matching query: String) -> [AdminUsageNoticeRecipientsCard.Candidate] {
        AdminUsageNoticeRecipientsBuilder.candidates(members: page.members, ids: recipientIds, query: query)
    }

    var hasCandidates: Bool {
        AdminUsageNoticeRecipientsBuilder.hasCandidates(members: page.members, ids: recipientIds)
    }

    /// I membri si stanno leggendo / non si sono letti: "Recipients could not be loaded. Notices still reach owners." e Riprova.
    var recipientsPhase: AdminUsagePhase { page.membersPhase }

    /// "Not saved" mostra "Retry" solo quando riprovare può servire: non dopo una persona rifiutata.
    var recipientsCanRetry: Bool { recipientRefused.isEmpty }

    /// Salvataggio fallito senza un motivo da correggere: "The recipients were not saved. Try again.".
    var recipientsSaveFailed: Bool { recipientsSaver.state == .error && recipientRefused.isEmpty }

    // MARK: Modifiche

    func addRecipient(_ id: String) {
        let ids = recipientIds
        guard !ids.contains(id) else { return }
        change(recipients: ids + [id])
    }

    func removeRecipient(_ id: String) {
        change(recipients: recipientIds.filter { $0 != id })
    }

    func retryRecipients() {
        recipientsSaver.retry()
    }

    func retryMembers() async {
        await page.retryMembers()
    }

    private func change(recipients ids: [String]) {
        recipientDraft = ids
        recipientsSaver.schedule(ids)
    }

    // MARK: Scrittura

    /// PUT /v1/usage/notice-recipients con la lista intera. `true` se il server l'ha accettata.
    func sendRecipients(_ ids: [String]) async -> Bool {
        let stamp = currentStamp()
        recipientRefused = []
        do {
            let answer = try await api.saveNoticeRecipients(ids)
            guard isCurrent(stamp) else { return false }
            page.applyRecipients(answer)
            // La bozza se ne va quando il server tiene esattamente quella: una modifica fatta nel frattempo resta.
            if let draft = recipientDraft, Set(draft) == Set(ids) { recipientDraft = nil }
            return true
        } catch {
            guard isCurrent(stamp) else { return false }
            if let refusal = Self.refusal(error), refusal.code == .recipientNotActiveMember {
                // Nessuno è stato salvato: si segnano "Inactive" le persone rifiutate, col nome che avevano.
                recipientRefused = refusal.userIds.map { id in
                    AdminUsageRefusedPerson(id: id, name: page.members.first { $0.userId == id }?.displayName
                        ?? AdminUsagePersonName.formerMember.text ?? "")
                }
            } else {
                handle(error)
            }
            return false
        }
    }
}
