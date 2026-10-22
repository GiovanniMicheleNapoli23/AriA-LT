//
//  AdminDocumentsSummary.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il riepilogo sopra la lista: quanti documenti, quanti pronti, in elaborazione e falliti
//  (sui documenti scaricati). Griglia adattiva: due colonne su iPhone, una riga su iPad.
//

import SwiftUI

struct AdminDocumentsSummary: View {
    let viewModel: AdminDocumentsViewModel
    @ScaledMetric(relativeTo: .body) private var minTile: CGFloat = 140

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minTile), spacing: 8)], spacing: 8) {
            AdminStatTile(title: String(localized: "Documents"),
                          value: (viewModel.total ?? viewModel.documents.count).formatted(),
                          systemImage: "doc.on.doc")
            AdminStatTile(title: AdminDocumentStatusGroup.ready.label,
                          value: viewModel.count(.ready).formatted(),
                          systemImage: AdminDocumentStatusGroup.ready.systemImage, tint: .green)
            AdminStatTile(title: AdminDocumentStatusGroup.processing.label,
                          value: viewModel.count(.processing).formatted(),
                          systemImage: AdminDocumentStatusGroup.processing.systemImage, tint: .blue)
            AdminStatTile(title: AdminDocumentStatusGroup.failed.label,
                          value: viewModel.count(.failed).formatted(),
                          systemImage: AdminDocumentStatusGroup.failed.systemImage, tint: .orange)
        }
    }
}
