//
//  AdminKnowledgeGraphRelationCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un gruppo di entità collegate (o trovate): i primi nodi, ognuno apre il suo dettaglio, e\n//  "Show all" quando sono di più.
//

import SwiftUI

struct AdminKnowledgeGraphRelationCard: View {
    let group: AdminKnowledgeGraphRelationGroup
    /// Dove porta "Show all"; `nil` = nessun link (si mostrano già tutti).
    let showAll: AdminKnowledgeGraphRoute?
    var previewLimit = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(group.kind.pluralTitle, systemImage: group.kind.systemImage)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(group.nodes.count, format: .number)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if let showAll, group.nodes.count > previewLimit {
                    NavigationLink(value: showAll) {
                        Text("Show all")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liteAccent)
                    }
                }
            }
            ForEach(group.nodes.prefix(previewLimit)) { node in
                NavigationLink(value: AdminKnowledgeGraphRoute.entity(node.ref)) {
                    AdminKnowledgeGraphNodeRow(node: node)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
