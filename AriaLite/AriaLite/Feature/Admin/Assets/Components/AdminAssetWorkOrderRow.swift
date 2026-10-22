//
//  AdminAssetWorkOrderRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un ordine di lavoro dell'asset, in sola lettura: titolo, stato, tipo, priorità e data.
//

import SwiftUI

struct AdminAssetWorkOrderRow: View {
    let order: AdminAssetWorkOrder

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(order.title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text(order.detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                if let level = order.priorityLevel { AriaPriorityBadge(level: level) }
                if let dateText = order.dateText {
                    Text(dateText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 10)
        .opacity(order.isClosed ? 0.65 : 1)
        .accessibilityElement(children: .combine)
    }
}
