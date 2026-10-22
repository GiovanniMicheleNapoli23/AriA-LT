//
//  AdminDocumentRunsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le run di pipeline del documento, dalla più recente (le ultime 20).
//

import SwiftUI

struct AdminDocumentRunsCard: View {
    let viewModel: AdminDocumentDetailViewModel

    var body: some View {
        AdminCard(title: "Runs", systemImage: "clock.arrow.circlepath") {
            if let total = viewModel.runsTotal, total > viewModel.runs.count {
                Text("Latest \(viewModel.runs.count) of \(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } content: {
            if let message = viewModel.runsError, viewModel.runs.isEmpty {
                AdminSectionNotice(text: message, isError: true)
            } else if !viewModel.hasLoadedRuns {
                ProgressView().frame(maxWidth: .infinity)
            } else if viewModel.runs.isEmpty {
                AdminSectionNotice(text: String(localized: "No runs yet."))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.runs) { run in
                        AdminDocumentRunRow(run: run, showsDivider: run.id != viewModel.runs.last?.id)
                    }
                }
            }
        }
    }
}
