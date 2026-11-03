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
                pipelineRow(title: String(localized: "Indexing for answers"), label: viewModel.ingestionLabel,
                            progress: viewModel.ingestionProgress)
                pipelineRow(title: String(localized: "Maintenance data extraction"), label: viewModel.extractionLabel,
                            progress: viewModel.extractionProgress, showsDivider: false)
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

    /// La riga dello stato e, finché la pipeline è attiva, la sua barra di avanzamento.
    private func pipelineRow(title: String, label: String?, progress: AdminDocumentPipelineProgress?,
                             showsDivider: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            AdminFieldRow(field: AdminAssetField(title: title, value: label ?? String(localized: "Not run")),
                          showsDivider: showsDivider && progress == nil)
            if let progress {
                AdminDocumentPipelineProgressBar(progress: progress)
                    .padding(.bottom, 10)
                if showsDivider { Divider() }
            }
        }
    }
}
