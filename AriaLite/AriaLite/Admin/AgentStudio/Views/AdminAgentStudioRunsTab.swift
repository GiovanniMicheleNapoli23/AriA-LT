//
//  AdminAgentStudioRunsTab.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda "Active": i run in corso e quelli fermi ad aspettare una persona. Il dettaglio li segue
//  dal vivo e li può annullare.
//

import SwiftUI

struct AdminAgentStudioRunsTab: View {
    let viewModel: AdminAgentStudioViewModel

    var body: some View {
        AdminAgentStudioLoadState(
            hasLoaded: viewModel.hasLoaded,
            isEmpty: viewModel.activeRuns.isEmpty,
            errorMessage: viewModel.activeRunsError,
            failureTitle: "Can't load active runs",
            emptyTitle: "No active runs",
            emptyImage: "bolt.horizontal.circle",
            emptyDescription: "Runs that are going, or waiting for someone, show up here.",
            retry: { await viewModel.load() }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.activeRuns) { run in
                    NavigationLink(value: AdminAgentStudioRoute.run(workflowId: run.workflowId, runId: run.id)) {
                        AdminAgentStudioListRow(
                            systemImage: "bolt.horizontal.circle",
                            title: run.workflowName ?? run.id,
                            subtitle: viewModel.subtitle(for: run),
                            footnote: viewModel.footnote(for: run),
                            badge: run.status.map { AdminAgentStudioBadge(status: $0) }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
