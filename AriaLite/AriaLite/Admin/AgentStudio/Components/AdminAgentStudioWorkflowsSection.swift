//
//  AdminAgentStudioWorkflowsSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Workflows" nella schermata principale: una riga di numeri (quanti, quanti attivi, run di oggi)
//  e la lista, con caricamento, errore o vuoto.
//

import SwiftUI

struct AdminAgentStudioWorkflowsSection: View {
    let viewModel: AdminAgentStudioViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdminAgentStudioSectionHeader(title: "Workflows", detail: viewModel.hasLoaded ? viewModel.statsLine : nil)
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
        }
    }
}
