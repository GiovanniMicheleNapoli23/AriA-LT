//
//  AdminKnowledgeGraphSearchResults.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La ricerca globale: i nodi di ogni tipo che contengono il testo, a gruppi; "Show all" apre la\n//  lista del tipo con la stessa ricerca.
//

import SwiftUI

struct AdminKnowledgeGraphSearchResults: View {
    let viewModel: AdminKnowledgeGraphViewModel

    var body: some View {
        let groups = viewModel.searchResults
        if groups.isEmpty {
            ContentUnavailableView.search(text: viewModel.searchText)
                .padding(.top, 40)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(groups) { group in
                    AdminKnowledgeGraphRelationCard(group: group, showAll: .kind(group.kind))
                }
            }
        }
    }
}
