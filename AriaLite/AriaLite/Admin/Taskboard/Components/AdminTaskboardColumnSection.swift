//
//  AdminTaskboardColumnSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una colonna della bacheca: intestazione con stato e conteggio, poi le sue card in una griglia adattiva
//  (una colonna di card su telefono, più affiancate se c'è larghezza). Nessuno scroll proprio.
//

import SwiftUI

struct AdminTaskboardColumnSection<CardView: View>: View {
    let status: AdminWorkOrderStatus
    let items: [AdminWorkOrderRowItem]
    /// Larghezza minima di una card nella griglia.
    var minimumCardWidth: CGFloat = 300
    var showsHeader = true
    @ViewBuilder var card: (AdminWorkOrderRowItem) -> CardView

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsHeader { AdminTaskboardColumnHeader(status: status, count: items.count) }
            if items.isEmpty {
                AdminSectionNotice(text: String(localized: "No tasks here."), systemImage: "tray")
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumCardWidth), spacing: 10, alignment: .top)],
                          alignment: .leading, spacing: 10) {
                    ForEach(items) { item in card(item) }
                }
            }
        }
    }
}
