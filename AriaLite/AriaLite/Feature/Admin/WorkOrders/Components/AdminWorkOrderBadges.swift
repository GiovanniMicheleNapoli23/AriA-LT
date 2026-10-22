//
//  AdminWorkOrderBadges.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le capsule di stato e priorità degli ordini, nella lista e nel dettaglio.
//

import SwiftUI

struct AdminWorkOrderStatusBadge: View {
    let status: AdminWorkOrderStatus

    private var color: Color {
        switch status {
        case .proposed: .purple
        case .planned: .secondary
        case .assigned: .blue
        case .inProgress: .orange
        case .completed, .verified: .green
        case .cancelled, .unknown: .gray
        }
    }

    var body: some View {
        Text(status.localized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .fixedSize()
    }
}

struct AdminWorkOrderPriorityBadge: View {
    let priority: AdminWorkOrderPriority

    private var color: Color {
        switch priority {
        case .high: .red
        case .medium: .orange
        case .low: .green
        case .unknown: .secondary
        }
    }

    var body: some View {
        Text(priority.localized)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .fixedSize()
    }
}

/// La barra sottile dell'avanzamento dei passi.
struct AdminWorkOrderProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.liteAccent.opacity(0.12))
                Capsule()
                    .fill(fraction >= 1 ? Color.green : Color.liteAccent)
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    }
}
