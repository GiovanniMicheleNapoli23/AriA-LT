//
//  AdminPurchaseOrderStatus.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di un ordine di acquisto. Il backend lo manda come testo libero: si normalizza (minuscolo,
//  spazi e trattini in underscore) e uno stato sconosciuto resta `unknown` con il testo originale.
//  Le regole dei pulsanti (approva, rifiuta, ricevi, modifica) stanno qui, non nelle viste.
//

import Foundation

nonisolated enum AdminPurchaseOrderStatus: Sendable, Hashable {
    case draft
    case pendingApproval
    case approved
    case rejected
    case ordered
    case partiallyReceived
    case received
    case cancelled
    case unknown(String)

    init(raw: String?) {
        let original = raw ?? ""
        let key = original
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        switch key {
        case "draft": self = .draft
        case "pending_approval", "pending", "submitted": self = .pendingApproval
        case "approved": self = .approved
        case "rejected": self = .rejected
        case "ordered": self = .ordered
        case "partially_received": self = .partiallyReceived
        case "received": self = .received
        case "cancelled", "canceled": self = .cancelled
        default: self = .unknown(original)
        }
    }

    /// Gli stati noti, nell'ordine dei filtri.
    static let filterCases: [AdminPurchaseOrderStatus] = [
        .draft, .pendingApproval, .approved, .rejected, .ordered, .partiallyReceived, .received, .cancelled
    ]

    /// Il valore da mandare come `status=` nel filtro della lista. Per uno stato sconosciuto, il testo originale.
    var rawFilterValue: String {
        switch self {
        case .draft: "draft"
        case .pendingApproval: "pending_approval"
        case .approved: "approved"
        case .rejected: "rejected"
        case .ordered: "ordered"
        case .partiallyReceived: "partially_received"
        case .received: "received"
        case .cancelled: "cancelled"
        case .unknown(let raw): raw
        }
    }

    var label: String {
        switch self {
        case .draft: String(localized: "Draft")
        case .pendingApproval: String(localized: "Pending approval")
        case .approved: String(localized: "Approved")
        case .rejected: String(localized: "Rejected")
        case .ordered: String(localized: "Ordered")
        case .partiallyReceived: String(localized: "Partially received")
        case .received: String(localized: "Received")
        case .cancelled: String(localized: "Cancelled")
        case .unknown(let raw):
            raw.isEmpty ? String(localized: "Unknown status") : raw
        }
    }

    var systemImage: String {
        switch self {
        case .draft: "doc.text"
        case .pendingApproval: "clock"
        case .approved: "checkmark.seal"
        case .rejected: "xmark.octagon"
        case .ordered: "shippingbox"
        case .partiallyReceived: "tray.and.arrow.down"
        case .received: "checkmark.circle"
        case .cancelled: "slash.circle"
        case .unknown: "questionmark.circle"
        }
    }

    /// Si può approvare: in bozza o in attesa di approvazione. Uno stato sconosciuto lascia decidere al server
    /// (gli stati non sono nell'OpenAPI): se dice di no, l'errore arriva nell'alert.
    var canApprove: Bool {
        switch self {
        case .draft, .pendingApproval, .unknown: true
        default: false
        }
    }

    /// Si può rifiutare: in bozza o in attesa di approvazione (o uno stato sconosciuto, vedi sopra).
    var canReject: Bool {
        switch self {
        case .draft, .pendingApproval, .unknown: true
        default: false
        }
    }

    /// Si può registrare la ricezione: approvato, ordinato o già ricevuto in parte (o uno stato sconosciuto).
    var canReceive: Bool {
        switch self {
        case .approved, .ordered, .partiallyReceived, .unknown: true
        default: false
        }
    }

    /// Si possono cambiare testata e righe: bozza, in attesa, o uno stato che non si conosce.
    var isEditable: Bool {
        switch self {
        case .draft, .pendingApproval, .unknown: true
        default: false
        }
    }
}
