//
//  AdminMemoryFactListRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Una riga della lista dei fatti: apre il dettaglio e ha il menu contestuale per moderare. Legge qui
//  testo, traduzione e riga di contesto, così la lista (pigra) costruisce solo le righe a schermo.
//

import SwiftUI

struct AdminMemoryFactListRow: View {
    let viewModel: AdminLearnedKnowledgeViewModel
    let fact: AdminMemoryFact
    /// La modifica apre un foglio che sta nella vista della lista.
    let onEdit: (AdminMemoryFact) -> Void

    var body: some View {
        NavigationLink(value: fact.id) {
            AdminMemoryFactRow(fact: fact, text: viewModel.displayText(for: fact),
                               isTranslated: viewModel.isTranslated(fact),
                               metaLine: viewModel.metaLine(for: fact), isBusy: viewModel.isBusy(fact))
        }
        .buttonStyle(.plain)
        .contextMenu {
            AdminMemoryFactActionButtons(
                canApprove: viewModel.canApprove(fact), canReject: viewModel.canReject(fact),
                onApprove: { Task { await viewModel.approve(fact) } },
                onReject: { viewModel.askToReject(fact) },
                onEdit: { onEdit(fact) },
                onDelete: { viewModel.askToDelete(fact) })
        }
    }
}
