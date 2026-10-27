//
//  AdminAgentStudioNodeInspector.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Il pannello delle opzioni del nodo scelto sul canvas: barra di navigazione di sistema con il titolo
//  del nodo e il bottone di chiusura, poi una scheda per sezione. Sola lettura: il workflow si modifica sulla web.
//

import SwiftUI

struct AdminAgentStudioNodeInspector: View {
    let viewModel: AdminAgentStudioCanvasViewModel

    var body: some View {
        if let node = viewModel.selectedNode {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(viewModel.inspectorSections(for: node)) { section in
                            AdminCard(title: LocalizedStringKey(section.title), systemImage: section.systemImage) {
                                VStack(spacing: 0) {
                                    ForEach(Array(section.rows.enumerated()), id: \.offset) { index, field in
                                        AdminFieldRow(field: field, showsDivider: index < section.rows.count - 1)
                                    }
                                }
                            }
                        }
                        Text("Edit this workflow on the web.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                    .padding(16)
                }
                .navigationTitle(node.step.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if #available(iOS 26.0, *) {
                            Button(role: .close) { viewModel.clearSelection() }
                        } else {
                            Button("Close", systemImage: "xmark") { viewModel.clearSelection() }
                        }
                    }
                }
                // Lascia trasparire il vetro del foglio e del pannello laterale.
                .containerBackground(.clear, for: .navigation)
            }
        }
    }
}
