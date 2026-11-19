//
//  AdminUserDetailViewModel+Status.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Stato della persona (§5.7): sospendere (con conferma), riattivare (subito) e rimuovere dall'azienda (con
//  conferma). Se la riattivazione è rifiutata per i posti, il messaggio è quello del §8. Dopo la rimozione la
//  riga sparisce dall'elenco riletto e la scheda si chiude da sola (`isGone`).
//

import Foundation

extension AdminUserDetailViewModel {
    func askSuspend() {
        guard !isWorking else { return }
        confirmation = .suspend
    }

    func askRemove() {
        guard !isWorking else { return }
        confirmation = .remove
    }

    func reactivate() {
        guard !isWorking, controls.reactivate else { return }
        Task { await sendStatus(suspended: false) }
    }

    func sendStatus(suspended: Bool) async {
        guard let api = owner.api, let name = row?.displayName else { return }
        await write {
            try await api.setStatus(userId: userId, suspended: suspended)
            return suspended ? String(localized: "\(name) is suspended.") : String(localized: "\(name) is active again.")
        }
    }

    func sendRemove() async {
        guard let api = owner.api, let name = row?.displayName else { return }
        await write {
            try await api.remove(userId: userId)
            return String(localized: "\(name) was removed.")
        }
    }

    // MARK: - Resend email (§5.6)

    /// Manda di nuovo l'email d'invito. `true` → "Email sent to {name}."; `false` o un errore → "The email didn't go out…".
    func resendEmail() {
        guard !isSendingEmail, let companyId = owner.companyId, let name = row?.displayName else { return }
        isSendingEmail = true
        Task {
            defer { isSendingEmail = false }
            do {
                let sent = try await owner.backend.api.auth.sendMobileInviteLink(companyId: companyId, userId: userId)
                if sent {
                    owner.show(String(localized: "Email sent to \(name)."))
                } else {
                    owner.show(Self.emailNotSent, isError: true)
                }
            } catch {
                owner.show(Self.emailNotSent, isError: true)
            }
        }
    }

    private static var emailNotSent: String { String(localized: "The email didn't go out. Try again in a few minutes.") }
}
