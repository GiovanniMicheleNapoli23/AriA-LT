//
//  AdminKnowledgeGraphRunsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le elaborazioni di un documento (GET /v1/documents/{id}/runs): si chiedono quando si apre il\n//  dettaglio; vuoto, errore e caricamento si dicono dentro la scheda.
//

import SwiftUI

struct AdminKnowledgeGraphRunsCard: View {
    let viewModel: AdminKnowledgeGraphViewModel
    let ref: AdminKnowledgeGraphRef

    var body: some View {
        AdminCard(title: "Processing runs", systemImage: "gearshape.arrow.triangle.2.circlepath") {
            let runs = viewModel.runs(for: ref)
            if runs.isEmpty {
                if viewModel.isLoadingRuns(for: ref) {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let message = viewModel.runError(for: ref) {
                    AdminSectionNotice(text: message, isError: true)
                } else {
                    AdminSectionNotice(text: String(localized: "No processing runs yet."))
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(runs) { run in
                        AdminKnowledgeGraphRunRow(run: run, title: viewModel.runTitle(run), summary: viewModel.runSummary(run))
                        if run.id != runs.last?.id { Divider() }
                    }
                }
            }
        }
    }
}
