//
//  AdminReviewAction.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Le decisioni di revisione su un asset, un allarme, un ricambio o un piano, come nella guida "Roles & Rights":
//  da una bozza Approve o Reject, da un approvato Unapprove o Reject, da un rifiutato Back to draft o Approve.
//  Ognuna è un PATCH dello stato; il ruolo decide quali si vedono (`AriaRights.canMove`).
//

import Foundation

nonisolated enum AdminReviewAction: String, Hashable, Sendable {
    case approve
    case unapprove
    case reject
    case backToDraft

    /// Lo stato mandato nel PATCH.
    var target: String {
        switch self {
        case .approve: "approved"
        case .unapprove, .backToDraft: "draft"
        case .reject: "rejected"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .approve: "Approve"
        case .unapprove: "Unapprove"
        case .reject: "Reject"
        case .backToDraft: "Back to draft"
        }
    }

    var systemImage: String {
        switch self {
        case .approve: "checkmark.seal"
        case .unapprove, .backToDraft: "arrow.uturn.backward"
        case .reject: "xmark"
        }
    }

    /// Approve è in evidenza (pieno nel colore dell'app); le altre sono di vetro.
    var isPrimary: Bool { self == .approve }

    /// Chiede conferma prima della chiamata: rifiutare toglie il record dal lavoro dell'assistente.
    var needsConfirmation: Bool { self == .reject || self == .unapprove }

    /// Le decisioni che si possono prendere su un record nello stato `stored`, nell'ordine dei pulsanti (la
    /// principale per ultima), tolte quelle per cui il ruolo non ha gli switch.
    static func available(from stored: String, in section: AriaSection, rights: AriaRights) -> [Self] {
        let candidates: [Self] = switch stored {
        case "approved": [.reject, .unapprove]
        case "rejected": [.backToDraft, .approve]
        default: [.reject, .approve]
        }
        return candidates.filter { rights.canMove(from: stored, to: $0.target, in: section) }
    }
}

/// Lo stato del record visto dal riquadro di revisione: titolo e icona.
nonisolated enum AdminReviewStage: Sendable {
    case pending
    case approved
    case rejected

    init(stored: String) {
        switch stored {
        case "approved": self = .approved
        case "rejected": self = .rejected
        default: self = .pending
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .pending: "Waiting for review"
        case .approved: "Approved"
        case .rejected: "Rejected"
        }
    }

    var systemImage: String {
        switch self {
        case .pending: "clock.badge.questionmark"
        case .approved: "checkmark.seal"
        case .rejected: "xmark.seal"
        }
    }
}
