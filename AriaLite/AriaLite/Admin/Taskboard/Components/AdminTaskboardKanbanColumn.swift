//
//  AdminTaskboardKanbanColumn.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Una colonna della kanban: intestazione fissa e card che scorrono in verticale per conto loro. Le card si
//  trascinano (portano l'id dell'ordine); la colonna si accende quando ci passa sopra una card.
//

import SwiftUI

struct AdminTaskboardKanbanColumn<CardView: View>: View {
    let status: AdminWorkOrderStatus
    let items: [AdminWorkOrderRowItem]
    /// Gli id delle card lasciate qui; `false` se lo spostamento non è permesso.
    let onDrop: ([String]) -> Bool
    @ViewBuilder var card: (AdminWorkOrderRowItem) -> CardView

    @State private var isTargeted = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 20, style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AdminTaskboardColumnHeader(status: status, count: items.count)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)
            ScrollView {
                LazyVStack(spacing: 8) {
                    if items.isEmpty {
                        AdminSectionNotice(text: String(localized: "No tasks here."), systemImage: "tray")
                            .padding(.vertical, 8)
                    }
                    ForEach(items) { item in
                        card(item).draggable(item.id)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(status.tint.opacity(isTargeted ? 0.16 : 0.06), in: shape)
        .overlay { shape.strokeBorder(status.tint.opacity(isTargeted ? 0.6 : 0), lineWidth: 2) }
        .dropDestination(for: String.self) { ids, _ in
            onDrop(ids)
        } isTargeted: { isTargeted = $0 }
        .animation(.snappy(duration: 0.2), value: isTargeted)
    }
}
