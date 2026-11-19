//
//  AdminUsageNoticeRecipientsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Usage notices" (contratto 5.3) già scritta: chi è sempre avvisato, chi si avvisa in più, l'elenco di chi si
//  può aggiungere e come arrivano gli avvisi.
//

import Foundation

nonisolated struct AdminUsageNoticeRecipientsCard: Sendable, Equatable {
    /// "Usage notices".
    var title: String
    /// "Who else hears your company's usage notices."
    var description: String
    /// "Always notified" e "Owners".
    var alwaysTitle: String
    var alwaysHint: String
    var always: [Person]
    /// "Also notify" e "Members get notices without EUR amounts".
    var alsoTitle: String
    var alsoHint: String
    var also: [Person]
    /// "No one else yet." quando `also` è vuota.
    var alsoEmpty: String
    /// "Add a member".
    var addLabel: String
    /// "Notices arrive in the app and by email." o "…Email delivery is coming soon."
    var delivery: String
    var deliveryIsEmail: Bool
    /// "{name} is no longer an active member and can't receive notices. Remove them to save again." per ogni persona rifiutata e ancora nella lista.
    var inactiveNotes: [String]

    nonisolated struct Person: Sendable, Equatable, Identifiable {
        var id: String
        var name: String
        /// "Owner" o "Member".
        var role: String
        /// "Inactive": non è più un membro attivo (il server l'ha rifiutata).
        var inactiveChip: String?
        /// "Remove {name}".
        var removeLabel: String
    }

    /// Un membro che si può aggiungere.
    nonisolated struct Candidate: Sendable, Equatable, Identifiable {
        var id: String
        var name: String
        var role: String
    }
}

/// Una persona rifiutata dal server (422 `recipient_not_active_member`), col nome che aveva allora.
nonisolated struct AdminUsageRefusedPerson: Sendable, Equatable {
    var id: String
    var name: String
}
