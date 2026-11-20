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

    /// Il giro guidato indica il titolo e le prime righe: con tanti workflow l'intera lista uscirebbe dallo schermo.
    private static let tourRows = 3

    var body: some View {
        let workflows = viewModel.sortedWorkflows
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                AdminAgentStudioSectionHeader(title: "Workflows", detail: viewModel.hasLoaded ? viewModel.statsLine : nil)
                AdminAgentStudioLoadState(
                    hasLoaded: viewModel.hasLoaded,
                    isEmpty: workflows.isEmpty,
                    errorMessage: viewModel.workflowsError,
                    failureTitle: "Can't load workflows",
                    emptyTitle: "No workflows",
                    emptyImage: "flowchart",
                    emptyDescription: "Workflows are built in Agent Studio on the web. Once saved, they show up here.",
                    retry: { await viewModel.load() }
                ) {
                    rows(workflows.prefix(Self.tourRows))
                }
            }
            .ariaSetupTourAnchor(.workflows)

            // Le altre righe, fuori dal riquadro del giro (la lista c'è solo se caricata e non vuota).
            if viewModel.hasLoaded, workflows.count > Self.tourRows {
                rows(workflows.dropFirst(Self.tourRows))
            }
        }
    }

    private func rows(_ workflows: ArraySlice<AdminAgentStudioWorkflow>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(workflows) { workflow in
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
