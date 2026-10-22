//
//  AdminWorkOrderRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di un ordine nella lista admin: titolo, stato e priorità, asset e zona, chi lo esegue,
//  scadenza e avanzamento dei passi. Stesso vetro delle task dell'operatore.
//

import SwiftUI

struct AdminWorkOrderRow: View {
    let item: AdminWorkOrderRowItem

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Testo molto grande: i badge vanno sotto il titolo invece di schiacciarlo.
        let isAX = dynamicTypeSize.isAccessibilitySize
        let header = isAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        VStack(alignment: .leading, spacing: 8) {
            header {
                Text(item.order.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    if let priority = item.priority { AdminWorkOrderPriorityBadge(priority: priority) }
                    if let status = item.status { AdminWorkOrderStatusBadge(status: status) }
                }
            }
            if !item.place.isEmpty || item.assignee != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { placeLabel; assigneeLabel; Spacer(minLength: 0) }
                    VStack(alignment: .leading, spacing: 4) { placeLabel; assigneeLabel }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if item.due != nil || item.progressText != nil {
                HStack(spacing: 8) {
                    if let due = item.due {
                        Label(due, systemImage: item.isOverdue ? "exclamationmark.clock.fill" : "clock")
                            .foregroundStyle(item.isOverdue ? Color.red : Color.secondary)
                    }
                    Spacer(minLength: 0)
                    if let progress = item.progressText {
                        Text(progress).foregroundStyle(.secondary)
                    }
                }
                .font(.caption2.weight(.medium))
                .lineLimit(1)
            }
            if let fraction = item.progress {
                AdminWorkOrderProgressBar(fraction: fraction)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .opacity(item.order.isClosed ? 0.7 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var placeLabel: some View {
        if !item.place.isEmpty {
            Label(item.place, systemImage: "gearshape.2").lineLimit(1)
        }
    }

    @ViewBuilder
    private var assigneeLabel: some View {
        if let assignee = item.assignee {
            Label(assignee, systemImage: "person").lineLimit(1)
        }
    }
}
