//
//  AdminTaskboardCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La card di un ordine nella bacheca: titolo, priorità, asset e zona, chi lo esegue (persona e squadra),
//  avanzamento dei passi e scadenza (rossa se superata). Il menu contestuale lo mette chi la usa.
//

import SwiftUI

struct AdminTaskboardCard: View {
    let item: AdminWorkOrderRowItem

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(item.order.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liteText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 5 : 3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if item.isBusy {
                    ProgressView().controlSize(.small)
                } else if let priority = item.priority {
                    AdminWorkOrderPriorityBadge(priority: priority)
                }
            }
            if !item.place.isEmpty {
                Label(item.place, systemImage: "gearshape.2")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Label(item.assignee ?? String(localized: "Unassigned"), systemImage: "person")
                .font(.footnote)
                .foregroundStyle(item.assignee == nil ? .tertiary : .secondary)
                .lineLimit(1)
            if item.progress != nil || item.due != nil { footer }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(item.order.isClosed ? 0.75 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let progress = item.progress, let text = item.progressText {
                AdminWorkOrderProgressBar(fraction: progress, height: 5)
                    .frame(maxWidth: 90)
                Text(text)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(progress >= 1 ? Color.green : Color.secondary)
                    .accessibilityLabel(Text("Steps \(text)"))
            }
            Spacer(minLength: 0)
            if let due = item.due {
                Label(due, systemImage: item.isOverdue ? "exclamationmark.clock.fill" : "calendar")
                    .font(.caption.weight(item.isOverdue ? .semibold : .regular))
                    .foregroundStyle(item.isOverdue ? Color.red : Color.secondary)
                    .lineLimit(1)
            }
        }
    }
}
