//
//  AdminMaintenanceBadges.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le pastiglie colorate di un piano: lo stato (approvato verde, bozza arancio…) e la scadenza
//  (scaduto rosso, in scadenza arancio).
//

import SwiftUI

struct AdminMaintenanceStatusBadge: View {
    let status: String

    private var color: Color {
        switch AdminMaintenanceStatus(rawValue: status) {
        case .approved: .green
        case .draft: .orange
        case .staged: .blue
        case .rejected: .red
        case .superseded, nil: .secondary
        }
    }

    var body: some View {
        Text(AdminMaintenanceStatus.label(for: status))
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
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
