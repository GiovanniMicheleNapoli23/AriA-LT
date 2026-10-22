//
//  AdminWorkOrderTemplateRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La riga di un modello di ordine: titolo, priorità, tipo e dettagli, numero di passi e ricambi.
//

import SwiftUI

struct AdminWorkOrderTemplateRow: View {
    let title: String
    let subtitle: String
    let priority: AdminWorkOrderPriority?
    let steps: String
    let parts: String?
    let isBusy: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let priority { AdminWorkOrderPriorityBadge(priority: priority) }
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 10) {
                    Label(steps, systemImage: "list.number")
                    if let parts { Label(parts, systemImage: "shippingbox") }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            }
            Spacer(minLength: 0)
            if isBusy { ProgressView().controlSize(.small) }
        }
        .padding(.vertical, 2)
    }
}
