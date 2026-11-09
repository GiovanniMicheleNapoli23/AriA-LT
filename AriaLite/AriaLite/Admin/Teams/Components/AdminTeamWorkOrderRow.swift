//
//  AdminTeamWorkOrderRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga degli ordini della squadra nel dettaglio: titolo, priorità, stato, asset e scadenza.
//

import SwiftUI

struct AdminTeamWorkOrderRow: View {
    let order: AdminTeamWorkOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(verbatim: order.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if order.priority != .unknown { AdminTeamPriorityBadge(priority: order.priority) }
            }
            HStack(spacing: 12) {
                Label(order.status.label, systemImage: order.status.systemImage)
                    .foregroundStyle(order.status.tint)
                if let due = order.dueDate {
                    Label(due.formatted(date: .abbreviated, time: .omitted),
                          systemImage: order.isOverdue() ? "exclamationmark.clock.fill" : "calendar")
                        .foregroundStyle(order.isOverdue() ? Color.red : Color.secondary)
                }
            }
            .font(.caption)
            if let place = order.place {
                Label(place, systemImage: "gearshape.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
