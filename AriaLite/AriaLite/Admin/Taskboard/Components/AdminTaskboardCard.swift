//
//  AdminTaskboardCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La card di un ordine nella bacheca: titolo, priorità, asset e zona, chi lo esegue (persona e squadra),
//  avanzamento dei passi e scadenza (rossa se superata). Il menu contestuale lo mette chi la usa.
//  Compatta (kanban) è più bassa, così in una colonna se ne vedono di più. Fuori dalle colonne (persone,
//  calendario) mostra anche lo stato, che lì non si capirebbe dalla posizione.
//

import SwiftUI

struct AdminTaskboardCard: View {
    let item: AdminWorkOrderRowItem
    var isCompact = false
    var showsStatus = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: isCompact ? 14 : 16, style: .continuous) }

    private var titleLines: Int {
        switch (isCompact, dynamicTypeSize.isAccessibilitySize) {
        case (true, false): 2
        case (true, true): 4
        case (false, false): 3
        case (false, true): 5
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(item.order.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liteText)
                    .lineLimit(titleLines)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if item.isBusy {
                    ProgressView().controlSize(.small)
                } else if let priority = item.priority {
                    AdminWorkOrderPriorityBadge(priority: priority)
                }
            }
            if showsStatus, let status = item.status, status != .unknown {
                Label(status.localized, systemImage: status.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.tint)
                    .lineLimit(1)
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
        .padding(isCompact ? 10 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: shape)
        .opacity(item.order.isClosed ? 0.75 : 1)
        .contentShape(shape)
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
