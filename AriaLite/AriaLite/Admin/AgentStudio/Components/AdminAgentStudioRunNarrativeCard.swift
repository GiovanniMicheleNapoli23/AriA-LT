//
//  AdminAgentStudioRunNarrativeCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  La scheda "Summary" del run: il testo arriva a pezzi dallo stream, quindi lo legge la scheda stessa
//  e si aggiorna da sola, senza far rifare tutta la schermata a ogni pezzo.
//

import SwiftUI

struct AdminAgentStudioRunNarrativeCard: View {
    let viewModel: AdminAgentStudioRunViewModel

    var body: some View {
        AdminCard(title: "Summary", systemImage: "text.alignleft") {
            Text(viewModel.narrativeText ?? "")
                .font(.subheadline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
