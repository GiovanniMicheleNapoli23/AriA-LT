//
//  AdminMaintenanceSummary.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il riepilogo sopra la lista: quanti piani, quanti scaduti, quanti in scadenza (sui piani che passano
//  i filtri). Un tocco su una tile filtra la lista per quella scadenza. Griglia adattiva.
//

import SwiftUI

struct AdminMaintenanceSummary: View {
    let viewModel: AdminMaintenanceViewModel
    @ScaledMetric(relativeTo: .body) private var minTile: CGFloat = 110

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minTile), spacing: 8)], spacing: 8) {
            AdminStatTile(title: String(localized: "Plans"), value: viewModel.totalCount.formatted(),
                          systemImage: "calendar.badge.clock")
            tile(.overdue, tint: .red)
            tile(.dueSoon, tint: .orange)
        }
    }

    private func tile(_ state: AdminMaintenanceDueState, tint: Color) -> some View {
        let isSelected = viewModel.dueFilter == state
        return Button {
            withAnimation(.snappy) { viewModel.toggleDueFilter(state) }
        } label: {
            AdminStatTile(title: state.label, value: viewModel.count(state).formatted(),
                          systemImage: state.systemImage, tint: tint)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? tint : .clear, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text("Filters the list"))
    }
}
