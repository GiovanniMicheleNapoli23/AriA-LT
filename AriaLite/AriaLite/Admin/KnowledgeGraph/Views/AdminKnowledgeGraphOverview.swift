//
//  AdminKnowledgeGraphOverview.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La panoramica: quante entità per tipo (caselle che aprono la lista), gli asset più collegati da\n//  cui partire e, se qualche lista manca, quale e perché.
//

import SwiftUI

struct AdminKnowledgeGraphOverview: View {
    let viewModel: AdminKnowledgeGraphViewModel

    @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if viewModel.hasLoaded {
                Text(viewModel.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: 12)], spacing: 12) {
                ForEach(viewModel.tiles) { tile in
                    if tile.isAvailable {
                        NavigationLink(value: AdminKnowledgeGraphRoute.kind(tile.kind)) {
                            AdminKnowledgeGraphKindTile(tile: tile)
                        }
                        .buttonStyle(.plain)
                    } else {
                        AdminKnowledgeGraphKindTile(tile: tile)
                    }
                }
            }
            if !viewModel.hubs.isEmpty { hubs }
            if !viewModel.unavailableKinds.isEmpty {
                AdminSectionNotice(text: String(localized: "Some lists aren't available. Their links are missing from the graph."),
                                   isError: true)
            }
            if viewModel.hasStaleKinds {
                AdminSectionNotice(text: String(localized: "Couldn't refresh some lists. Showing the last loaded data."),
                                   isError: true)
            }
            if let updated = viewModel.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var hubs: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Most connected assets", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.headline)
            Text("Start exploring from the assets with the most links.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(viewModel.hubs) { hub in
                NavigationLink(value: AdminKnowledgeGraphRoute.entity(hub.node.ref)) {
                    AdminKnowledgeGraphNodeRow(node: hub.node, links: hub.links)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
