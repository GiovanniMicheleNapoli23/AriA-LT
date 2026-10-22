//
//  AdminMobileUserWorkOrderRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un ordine di lavoro aperto dell'operatore: titolo, stato, asset, scadenza e priorità. Si apre sui passi.
//

import SwiftUI

struct AdminMobileUserWorkOrderRow: View {
    let order: AdminMobileUserWorkOrder

    private var detailLine: String {
        var parts = [order.statusLabel]
        if let tag = order.assetTag, !tag.isEmpty { parts.append(tag) }
        if let progress = order.stepProgress, progress.total > 0 {
            parts.append(String(localized: "\(progress.done)/\(progress.total) steps"))
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(order.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text(detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                if let level = order.priorityLevel { AriaPriorityBadge(level: level) }
                if let due = order.dueDate ?? order.scheduledDate {
                    Text(due.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
