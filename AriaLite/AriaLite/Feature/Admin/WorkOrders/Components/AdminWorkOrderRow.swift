//
//  AdminWorkOrderRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La card di un ordine nella lista admin: titolo (fino a due righe) e priorità; stato con il suo colore,
//  chi lo esegue e l'asset; in fondo l'avanzamento dei passi e la scadenza. Le righe di dettagli vanno a
//  capo se non ci stanno (iPhone stretto, testo grande).
//

import SwiftUI

struct AdminWorkOrderRow: View {
    let item: AdminWorkOrderRowItem

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(item.order.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.liteText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if item.isBusy {
                    ProgressView().controlSize(.small)
                } else if let priority = item.priority {
                    AdminWorkOrderPriorityBadge(priority: priority, large: true)
                }
            }
            details
            if item.progress != nil || item.due != nil { footer }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(item.order.isClosed ? 0.7 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// Stato, assegnatario e asset: in riga se ci stanno, altrimenti uno sotto l'altro.
    private var details: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { detailItems }
            VStack(alignment: .leading, spacing: 6) { detailItems }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    @ViewBuilder
    private var detailItems: some View {
        if let status = item.status {
            HStack(spacing: 6) {
                AdminWorkOrderStatusDot(status: status)
                Text(status.localized).fontWeight(.semibold)
            }
            .foregroundStyle(status.tint)
            .fixedSize()
        }
        if let assignee = item.assignee {
            Label(assignee, systemImage: "person")
        }
        if !item.place.isEmpty {
            Label(item.place, systemImage: "gearshape.2")
        }
    }

    /// Avanzamento dei passi (barra e "3/10") e scadenza, rossa se in ritardo.
    private var footer: some View {
        HStack(spacing: 12) {
            if let progress = item.progress, let text = item.progressText {
                AdminWorkOrderProgressBar(fraction: progress, height: 6)
                    .frame(maxWidth: 140)
                Text(text)
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(progress >= 1 ? Color.green : Color.secondary)
                    .accessibilityLabel(Text("Steps \(text)"))
            }
            Spacer(minLength: 0)
            if let due = item.due {
                Label(due, systemImage: item.isOverdue ? "exclamationmark.clock.fill" : "calendar")
                    .font(.footnote.weight(item.isOverdue ? .semibold : .regular))
                    .foregroundStyle(item.isOverdue ? Color.red : Color.secondary)
                    .lineLimit(1)
            }
        }
    }
}
