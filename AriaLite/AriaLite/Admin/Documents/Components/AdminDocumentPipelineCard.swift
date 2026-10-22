//
//  AdminDocumentPipelineCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato delle due pipeline (indicizzazione per le risposte, estrazione dei dati di manutenzione),
//  l'ultimo errore e, mentre lavorano, il pulsante per fermarle.
//

import SwiftUI

struct AdminDocumentPipelineCard: View {
    let viewModel: AdminDocumentDetailViewModel

    var body: some View {
        AdminCard(title: "Processing", systemImage: "gearshape.2") {
            if viewModel.isWorking { ProgressView().controlSize(.small) }
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                AdminFieldRow(field: AdminAssetField(title: String(localized: "Indexing for answers"),
                                                     value: viewModel.ingestionLabel ?? String(localized: "Not run")))
                AdminFieldRow(field: AdminAssetField(title: String(localized: "Maintenance data extraction"),
                                                     value: viewModel.extractionLabel ?? String(localized: "Not run")),
                              showsDivider: false)
                if let error = viewModel.document.lastError {
                    AdminSectionNotice(text: error, isError: true)
                        .padding(.top, 10)
                }
                if viewModel.canCancel {
                    Button(role: .destructive) {
                        viewModel.ask(.cancel)
                    } label: {
                        Label("Stop processing", systemImage: "stop.circle")
                            .font(.subheadline.weight(.semibold))
                    }
                    .ariaGlassButtonStyle()
                    .padding(.top, 12)
                }
            }
        }
    }
}
