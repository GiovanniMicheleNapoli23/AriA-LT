//
//  AdminMaintenanceBadges.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le pastiglie colorate di un piano: lo stato, come quello di un allarme (icona e testo; approvato nel
//  colore dell'app, bozza in ambra, scartato in grigio), e la scadenza (scaduto rosso, in scadenza arancio).
//

import SwiftUI

struct AdminMaintenanceStatusBadge: View {
    let status: String

    private var known: AdminMaintenanceStatus? { AdminMaintenanceStatus(rawValue: status) }

    private var color: Color {
        switch known {
        // Positivo nel colore dell'app, negativo in grigio: il rosso resta per gli errori.
        case .approved: .liteAccent
        case .draft, .staged: .liteWarning
        case .rejected, .superseded, nil: .secondary
        }
    }

    var body: some View {
        Label(AdminMaintenanceStatus.label(for: status), systemImage: known?.systemImage ?? "questionmark.circle")
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .fixedSize()
    }
}

/// Scaduto o in scadenza; per gli altri stati non c'è niente da segnalare.
struct AdminMaintenanceDueBadge: View {
    let state: AdminMaintenanceDueState

    private var color: Color? {
        switch state {
        case .overdue: .red
        case .dueSoon: .orange
        case .later, .unscheduled: nil
        }
    }

    var body: some View {
        if let color {
            Label(state.label, systemImage: state.systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.14), in: Capsule())
                .fixedSize()
        }
    }
}
