//
//  AdminPurchaseOrderDetailConfirmation.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le azioni del dettaglio che chiedono conferma (approva, rifiuta, ricevi, elimina, togli una riga) con titolo,
//  spiegazione ed etichetta del pulsante.
//

import Foundation

/// Cosa sta girando: serve a disabilitare gli altri pulsanti e a mostrare il progresso sul pulsante giusto.
enum AdminPurchaseOrderDetailAction: Hashable {
    case approve, reject, receive, delete
    case removeLine(String)
}

enum AdminPurchaseOrderDetailConfirmation: Identifiable, Hashable {
    case approve
    case reject
    case receive
    case delete
    case removeLine(id: String, name: String)

    var id: String {
        switch self {
        case .approve: "approve"
        case .reject: "reject"
        case .receive: "receive"
        case .delete: "delete"
        case .removeLine(let id, _): "removeLine-\(id)"
        }
    }

    var action: AdminPurchaseOrderDetailAction {
        switch self {
        case .approve: .approve
        case .reject: .reject
        case .receive: .receive
        case .delete: .delete
        case .removeLine(let id, _): .removeLine(id)
        }
    }

    var title: String {
        switch self {
        case .approve: String(localized: "Approve this order?")
        case .reject: String(localized: "Reject this order?")
        case .receive: String(localized: "Mark this order as received?")
        case .delete: String(localized: "Delete this order?")
        case .removeLine: String(localized: "Remove this line?")
        }
    }

    var message: String {
        switch self {
        case .approve:
            String(localized: "The order is approved in your name.")
        case .reject:
            String(localized: "The order is rejected and can't be approved or received any more.")
        case .receive:
            String(localized: "This books the delivery of the order. Do it only once the goods have arrived.")
        case .delete:
            String(localized: "The order and all its lines are deleted for good. This can't be undone.")
        case .removeLine(_, let name):
            String(localized: "\(name) is removed from this order.")
        }
    }

    var confirmLabel: String {
        switch self {
        case .approve: String(localized: "Approve")
        case .reject: String(localized: "Reject")
        case .receive: String(localized: "Mark as received")
        case .delete: String(localized: "Delete")
        case .removeLine: String(localized: "Remove")
        }
    }

    var isDestructive: Bool {
        switch self {
        case .reject, .delete, .removeLine: true
        case .approve, .receive: false
        }
    }
}
