//
//  AdminPurchaseOrderStatusBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di un ordine di acquisto come capsula colorata (lista e dettaglio): bozza grigia, in attesa
//  arancio, approvato verde acqua, ordinato blu, ricevuto verde, rifiutato rosso, annullato grigio.
//

import SwiftUI

struct AdminPurchaseOrderStatusBadge: View {
    let status: AdminPurchaseOrderStatus

    private var color: Color {
        switch status {
        case .draft, .cancelled, .unknown: .secondary
        case .pendingApproval: .orange
        case .approved: .teal
        case .rejected: .red
        case .ordered: .blue
        case .partiallyReceived: .indigo
        case .received: .green
        }
    }

    var body: some View {
        Label(status.label, systemImage: status.systemImage)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}
