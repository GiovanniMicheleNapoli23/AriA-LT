//
//  AdminTeamBoardCardView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La card di un ordine nella bacheca: titolo, priorità, asset e zona, chi lo esegue e la scadenza (rossa se
//  superata). Il menu "Move to…" lo mette chi la usa.
//

import SwiftUI

struct AdminTeamBoardCardView: View {
    let card: AdminTeamBoardCard

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(verbatim: card.order.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liteText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 5 : 3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if card.isBusy {
                    ProgressView().controlSize(.small)
                } else if card.order.priority != .unknown {
                    AdminTeamPriorityBadge(priority: card.order.priority)
                }
            }
            if let place = card.order.place {
                Label(place, systemImage: "gearshape.2")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Label(card.assignee ?? String(localized: "Unassigned"), systemImage: "person")
                .font(.footnote)
                .foregroundStyle(card.assignee == nil ? .tertiary : .secondary)
                .lineLimit(1)
            if let due = card.due {
                Label(due, systemImage: card.isOverdue ? "exclamationmark.clock.fill" : "calendar")
                    .font(.caption.weight(card.isOverdue ? .semibold : .regular))
                    .foregroundStyle(card.isOverdue ? Color.red : Color.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(card.order.status.isClosed ? 0.75 : 1)
    }
}
