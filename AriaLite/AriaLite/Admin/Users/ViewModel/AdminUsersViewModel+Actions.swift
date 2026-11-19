//
//  AdminUsersViewModel+Actions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le azioni dell'elenco di Users: aprire "Add a person" (§6.1) e revocare un invito per email (§6.3). Dopo una
//  scrittura si rilegge l'elenco e il tetto (regola 5); ogni rifiuto passa da AdminUsersFailure.
//

import Foundation

extension AdminUsersViewModel {
    /// Apre il modulo "Add a person": solo i titolari, e solo se il tetto lo permette.
    func startAdding() {
        guard viewer.isOwner, canAdd, addForm == nil else { return }
        addForm = AdminUserAddViewModel(owner: self)
    }

    /// Chiede conferma prima di revocare: solo i titolari, solo un invito per email.
    func askToRevoke(_ row: AdminUserRow) {
        guard canRevoke(row) else { return }
        invitationToRevoke = row
    }

    /// DELETE …/invites/{id}. Ogni rifiuto dice la stessa frase: la causa si legge dall'elenco riletto.
    func revoke(_ row: AdminUserRow) async {
        guard canRevoke(row), let invitationId = row.invitationId, let api else { return }
        let email = Self.invitationLabel(row)
        do {
            try await api.revokeInvite(invitationId: invitationId)
            show(String(localized: "The invitation to \(email) was revoked."))
            await afterWrite()
        } catch {
            // `nil`: annullata o sessione scaduta, non si dice niente.
            guard let failure = AdminUsersFailure.from(error, backend: backend) else { return }
            show(String(localized: "The invitation couldn't be revoked. Try again."), isError: true)
            await absorb(failure)
            // L'invito può non esserci più (accettato o scaduto): si rilegge.
            if failure.personGone { await refresh() }
        }
    }
}
