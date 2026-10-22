//
//  AdminKnowledgeGraphEntityView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un'entità: intestazione, testi, le entità collegate per tipo (ognuna apre il suo\n//  dettaglio, così si cammina nel grafo) e la scheda. Per un documento, anche le elaborazioni.
//

import SwiftUI

struct AdminKnowledgeGraphEntityView: View {
    let viewModel: AdminKnowledgeGraphViewModel
    let ref: AdminKnowledgeGraphRef

    var body: some View {
        Group {
            if let node = viewModel.node(for: ref) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        AdminKnowledgeGraphEntityHeader(node: node, linkSummary: viewModel.linkSummary(for: ref))
                        relations
                        ForEach(viewModel.texts(of: ref)) { AdminKnowledgeGraphTextCard(block: $0) }
                        if ref.kind == .document { AdminKnowledgeGraphRunsCard(viewModel: viewModel, ref: ref) }
                        details
                    }
                    .padding(20)
                    .ariaReadableWidth()
                }
                .navigationTitle(node.title)
            } else {
                // Dopo un aggiornamento l'entità non c'è più (cancellata, o la sua lista ora è negata).
                ContentUnavailableView("Not in the graph anymore", systemImage: ref.kind.systemImage,
                                       description: Text("It may have been deleted, or its list is no longer available."))
            }
        }
        .liteBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task(id: ref) { await viewModel.detailAppeared(ref) }
    }

    @ViewBuilder
    private var relations: some View {
        let groups = viewModel.relations(of: ref)
        if let note = viewModel.missingRelationsNote(for: ref) {
            AdminSectionNotice(text: note, systemImage: "point.3.connected.trianglepath.dotted")
        }
        ForEach(groups) { group in
            AdminKnowledgeGraphRelationCard(group: group, showAll: .related(ref, group.kind))
        }
    }

    @ViewBuilder
    private var details: some View {
        let fields = viewModel.fields(of: ref)
        if !fields.isEmpty {
            AdminCard(title: "Details", systemImage: "list.bullet.rectangle") {
                VStack(spacing: 0) {
                    ForEach(fields) { field in
                        AdminFieldRow(field: field, showsDivider: field != fields.last)
                    }
                }
            }
        }
    }
}
