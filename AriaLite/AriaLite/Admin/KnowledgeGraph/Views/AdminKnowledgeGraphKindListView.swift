//
//  AdminKnowledgeGraphKindListView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Tutte le entità di un tipo, con una ricerca solo per loro. Ogni riga apre il dettaglio.
//

import SwiftUI

struct AdminKnowledgeGraphKindListView: View {
    let viewModel: AdminKnowledgeGraphViewModel
    let kind: AdminKnowledgeGraphKind

    var body: some View {
        let nodes = viewModel.nodes(of: kind)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if nodes.isEmpty {
                    if viewModel.listQuery(for: kind).isEmpty {
                        ContentUnavailableView(kind.pluralTitle, systemImage: kind.systemImage,
                                               description: Text("None found for this company."))
                            .padding(.top, 40)
                    } else {
                        ContentUnavailableView.search(text: viewModel.listQuery(for: kind))
                    }
                } else {
                    Text(viewModel.listSubtitle(for: kind))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.top, 4)
                    ForEach(nodes) { node in
                        NavigationLink(value: AdminKnowledgeGraphRoute.entity(node.ref)) {
                            AdminKnowledgeGraphNodeRow(node: node)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(kind.pluralTitle)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: Binding(get: { viewModel.listQuery(for: kind) },
                                  set: { viewModel.setListQuery($0, for: kind) }),
                    prompt: Text("Search"))
        .onAppear { viewModel.listAppeared(kind) }
    }
}
