//
//  AdminAgentStudioRecentRunsSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  "Recent runs": gli ultimi cinque run in un blocco di vetro, con "Show all (n)" per il resto;
//  l'errore e il vuoto stanno dentro il blocco.
//

import SwiftUI

struct AdminAgentStudioRecentRunsSection: View {
    let viewModel: AdminAgentStudioWorkflowViewModel

    var body: some View {
        let shown = viewModel.visibleRuns
        VStack(alignment: .leading, spacing: 12) {
            AdminAgentStudioSectionHeader(title: "Recent runs")
            AdminAgentStudioGlassGroup {
                if let message = viewModel.runsError {
                    AdminSectionNotice(text: message, isError: true).padding(14)
                } else if viewModel.runs.isEmpty {
                    AdminSectionNotice(text: String(localized: "No runs yet."), systemImage: "clock").padding(14)
                }
                ForEach(shown) { run in
                    NavigationLink(value: AdminAgentStudioRoute.run(workflowId: viewModel.workflowId, runId: run.id)) {
                        AdminAgentStudioRunSummaryRow(
                            symbol: viewModel.statusSymbol(for: run),
                            tone: viewModel.statusTone(for: run),
                            statusLabel: viewModel.runStatusLabel(for: run),
                            modeLabel: viewModel.modeLabel(for: run),
                            counts: viewModel.countsLine(for: run),
                            relativeTime: viewModel.relativeStart(for: run)
                        )
                    }
                    .buttonStyle(.plain)
                    if run.id != shown.last?.id || viewModel.showsShowAllRuns { Divider().padding(.leading, 14) }
                }
                if viewModel.showsShowAllRuns {
                    Button { viewModel.showAllRuns() } label: {
                        Text("Show all (\(viewModel.runs.count))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liteAccent)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
