//
//  AdminMemoryFactConfirmation.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un'azione che chiede conferma prima di partire: rifiutare un fatto (esce dalla memoria di Aria)
//  o eliminarlo per sempre. Titolo, spiegazione e pulsante per il dialogo.
//

import Foundation

nonisolated enum AdminMemoryFactConfirmation: Sendable, Hashable {
    case reject(AdminMemoryFact)
    case delete(AdminMemoryFact)

    var fact: AdminMemoryFact {
        switch self {
        case .reject(let fact), .delete(let fact): fact
        }
    }

    var title: String {
        switch self {
        case .reject: String(localized: "Reject this fact?")
        case .delete: String(localized: "Delete this fact?")
        }
    }

    var message: String {
        switch self {
        case .reject(let fact) where fact.knownStatus == .approved:
            String(localized: "Aria will stop using it in its answers. You can approve it again later.")
        case .reject:
            String(localized: "Aria won't learn it. You can approve it again later.")
        case .delete:
            String(localized: "It will be removed from the company memory for good.")
        }
    }

    var actionTitle: String {
        switch self {
        case .reject: String(localized: "Reject")
        case .delete: String(localized: "Delete")
        }
    }
}
