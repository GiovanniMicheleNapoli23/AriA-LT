//
//  AdminTeamBoardColumn.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una colonna della bacheca: intestazione con stato e conteggio (se richiesta) e le sue card in una griglia
//  adattiva. Nessuno scroll proprio.
//

import SwiftUI

struct AdminTeamBoardColumn<CardView: View>: View {
    let status: AdminTeamWorkOrderStatus
    let cards: [AdminTeamBoardCard]
    var showsHeader = true
    @ViewBuilder var card: (AdminTeamBoardCard) -> CardView

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsHeader { header }
            if cards.isEmpty {
                AdminSectionNotice(text: String(localized: "No work orders here."), systemImage: "tray")
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10, alignment: .top)],
                          alignment: .leading, spacing: 10) {
                    ForEach(cards) { item in card(item) }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: status.systemImage).foregroundStyle(status.tint)
            Text(status.label).font(.headline)
            Text(cards.count, format: .number)
                .font(.footnote.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(status.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(status.tint.opacity(0.14), in: Capsule())
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
