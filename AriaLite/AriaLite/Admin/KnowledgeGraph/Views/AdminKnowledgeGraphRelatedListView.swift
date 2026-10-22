//
//  AdminKnowledgeGraphRelatedListView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Tutte le entità di un tipo collegate a un'altra ("Show all" dal dettaglio).
//

import SwiftUI

struct AdminKnowledgeGraphRelatedListView: View {
    let viewModel: AdminKnowledgeGraphViewModel
    let ref: AdminKnowledgeGraphRef
    let kind: AdminKnowledgeGraphKind

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if let node = viewModel.node(for: ref) {
                    Label(node.title, systemImage: ref.kind.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                ForEach(viewModel.related(kind, of: ref)) { node in
                    NavigationLink(value: AdminKnowledgeGraphRoute.entity(node.ref)) {
                        AdminKnowledgeGraphNodeRow(node: node)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(kind.pluralTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
