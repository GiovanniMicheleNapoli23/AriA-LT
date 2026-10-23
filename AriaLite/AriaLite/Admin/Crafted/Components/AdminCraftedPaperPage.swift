//
//  AdminCraftedPaperPage.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La pagina del rapporto: carta bianca (anche in scuro) con i paragrafi e le tabelle in ordine di
//  lettura, allo zoom scelto. Il pizzico cambia lo zoom; la pagina scorre solo in verticale.
//

import SwiftUI

struct AdminCraftedPaperPage: View {
    let viewModel: AdminCraftedReportReaderViewModel

    @ScaledMetric private var margin = 20.0

    var body: some View {
        AdminCraftedPaperZoom(zoom: viewModel.zoom) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.layout) { item in
                    switch item {
                    case .block(let index):
                        AdminCraftedPaperBlock(viewModel: viewModel, index: index)
                    case .table(_, let rows):
                        AdminCraftedPaperTable(viewModel: viewModel, rows: rows)
                    }
                }
            }
            .padding(margin)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(AdminCraftedPaperStyle.paper, in: RoundedRectangle(cornerRadius: 3))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            // Sulla carta anche i controlli di sistema (cursore, selezione) restano quelli del chiaro.
            .environment(\.colorScheme, .light)
        }
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { viewModel.pinchChanged($0.magnification) }
                .onEnded { _ in viewModel.pinchEnded() }
        )
        .accessibilityElement(children: .contain)
    }
}
