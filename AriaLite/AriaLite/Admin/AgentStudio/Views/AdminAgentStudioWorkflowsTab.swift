//
//  AdminAgentStudioWorkflowsTab.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda "Workflows": numeri in alto (workflow, attivi, run di oggi, run vivi, approvazioni in attesa),
//  la lista dei workflow e l'accuratezza degli agenti.
//

import SwiftUI

struct AdminAgentStudioWorkflowsTab: View {
    let viewModel: AdminAgentStudioViewModel

    @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.hasLoaded { summary }
            AdminAgentStudioLoadState(
                hasLoaded: viewModel.hasLoaded,
                isEmpty: viewModel.workflows.isEmpty,
                errorMessage: viewModel.workflowsError,
                failureTitle: "Can't load workflows",
                emptyTitle: "No workflows",
                emptyImage: "flowchart",
                emptyDescription: "Workflows are built in Agent Studio on the web. Once saved, they show up here.",
                retry: { await viewModel.load() }
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.sortedWorkflows) { workflow in
                        NavigationLink(value: AdminAgentStudioRoute.workflow(id: workflow.id)) {
                            AdminAgentStudioListRow(
                                systemImage: "flowchart",
                                title: workflow.name,
                                subtitle: viewModel.subtitle(for: workflow),
                                footnote: viewModel.footnote(for: workflow),
                                badge: workflow.enabled
                                    ? AdminAgentStudioBadge(text: String(localized: "Enabled"), tone: .positive)
                                    : AdminAgentStudioBadge(text: String(localized: "Disabled"), tone: .neutral),
                                iconTint: workflow.enabled ? .liteAccent : .secondary
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if viewModel.hasLoaded {
                AdminAgentStudioAccuracyCard(agents: viewModel.accuracy, window: viewModel.accuracyWindow,
                                             errorMessage: viewModel.accuracyError)
            }
        }
    }

    private var summary: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: 10)], spacing: 10) {
            AdminStatTile(title: String(localized: "Workflows"), value: "\(viewModel.workflows.count)",
                          systemImage: "flowchart")
            AdminStatTile(title: String(localized: "Enabled"), value: "\(viewModel.enabledCount)",
                          systemImage: "checkmark.circle", tint: .green)
            AdminStatTile(title: String(localized: "Runs today"), value: "\(viewModel.runsTodayCount)",
                          systemImage: "play.circle")
            AdminStatTile(title: String(localized: "Active runs"), value: "\(viewModel.activeRuns.count)",
                          systemImage: "bolt.horizontal.circle", tint: .blue)
            AdminStatTile(title: String(localized: "Pending approvals"), value: "\(viewModel.pendingApprovals.count)",
                          systemImage: "person.badge.shield.checkmark",
                          tint: viewModel.pendingApprovals.isEmpty ? .liteAccent : .orange)
        }
    }
}
