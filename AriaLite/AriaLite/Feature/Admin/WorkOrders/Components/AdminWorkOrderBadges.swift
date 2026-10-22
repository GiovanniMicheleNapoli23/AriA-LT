//
//  AdminWorkOrderBadges.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le capsule di stato e priorità degli ordini, il pallino di stato delle righe e la barra dei passi,
//  nella lista e nel dettaglio. Piccoli: la lista è densa.
//

import SwiftUI

extension AdminWorkOrderStatus {
    /// Il colore dello stato, uguale in capsula, pallino e menu.
    var tint: Color {
        switch self {
        case .proposed: .purple
        case .planned: .secondary
        case .assigned: .blue
        case .inProgress: .orange
        case .completed, .verified: .green
        case .cancelled, .unknown: .gray
        }
    }
}

extension AdminWorkOrderPriority {
    var tint: Color {
        switch self {
        case .high: .red
        case .medium: .orange
        case .low: .green
        case .unknown: .secondary
        }
    }
}

struct AdminWorkOrderStatusBadge: View {
    let status: AdminWorkOrderStatus

    var body: some View {
        Text(status.localized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(status.tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status.tint.opacity(0.14), in: Capsule())
            .fixedSize()
    }
}

struct AdminWorkOrderPriorityBadge: View {
    let priority: AdminWorkOrderPriority
    /// Nelle card della lista: più grande, con la bandierina.
    var large = false

    var body: some View {
        HStack(spacing: 4) {
            if large { Image(systemName: "flag.fill").font(.caption2) }
            Text(priority.localized)
        }
        .font(large ? .footnote.weight(.bold) : .caption2.weight(.bold))
        .foregroundStyle(priority.tint)
        .padding(.horizontal, large ? 10 : 6)
        .padding(.vertical, large ? 5 : 2)
        .background(priority.tint.opacity(0.14), in: Capsule())
        .fixedSize()
    }
}

/// Il pallino colorato dello stato in testa alla riga; il nome lo legge VoiceOver.
struct AdminWorkOrderStatusDot: View {
    let status: AdminWorkOrderStatus?

    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill((status ?? .unknown).tint)
            .frame(width: size, height: size)
            .accessibilityLabel(Text((status ?? .unknown).localized))
    }
}

/// La barra sottile dell'avanzamento dei passi.
struct AdminWorkOrderProgressBar: View {
    let fraction: Double
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.liteAccent.opacity(0.12))
                Capsule()
                    .fill(fraction >= 1 ? Color.green : Color.liteAccent)
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    }
}
