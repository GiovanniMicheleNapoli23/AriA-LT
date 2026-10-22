//
//  AdminReasoningNodesCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I nodi del grafo eseguiti nel turno, in ordine, con la durata di ognuno: una cascata da leggere
//  dall'alto. Se la trace manca lo dice, con "Retry" (un turno appena finito può non averla ancora).
//

import SwiftUI

struct AdminReasoningNodesCard: View {
    let viewModel: AdminReasoningTurnViewModel

    var body: some View {
        AdminCard(title: "Nodes", systemImage: "point.3.connected.trianglepath.dotted") {
            if viewModel.failedNodeCount > 0 {
                Label("\(viewModel.failedNodeCount) failed", systemImage: "exclamationmark.octagon.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        } content: {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let message = viewModel.traceError {
            VStack(alignment: .leading, spacing: 10) {
                AdminSectionNotice(text: message, systemImage: "doc.questionmark", isError: !viewModel.traceMissing)
                Button("Retry") { Task { await viewModel.load() } }
                    .font(.subheadline.weight(.semibold))
                    .disabled(viewModel.isLoading)
            }
        } else if !viewModel.hasLoaded {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
        } else if viewModel.nodes.isEmpty {
            AdminSectionNotice(text: String(localized: "No nodes recorded for this turn."))
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.nodes) { node in
                    AdminReasoningNodeRow(node: node)
                        .padding(.vertical, 8)
                    if node.id != viewModel.nodes.last?.id { Divider() }
                }
            }
        }
    }
}
