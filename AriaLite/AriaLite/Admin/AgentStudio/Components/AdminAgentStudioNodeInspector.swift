//
//  AdminAgentStudioNodeInspector.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Il pannello delle opzioni del nodo scelto sul canvas: tipo e titolo, poi una scheda per sezione.
//  Sola lettura: il workflow si modifica sulla web.
//

import SwiftUI

struct AdminAgentStudioNodeInspector: View {
    let viewModel: AdminAgentStudioCanvasViewModel

    @ScaledMetric(relativeTo: .headline) private var tileSide: CGFloat = 36

    var body: some View {
        if let node = viewModel.selectedNode {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(for: node)
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
        }
    }

    private func header(for node: AdminAgentStudioGraphNode) -> some View {
        let color = Color(adminAgentStudioHex: node.meta.colorHex)
        return HStack(spacing: 12) {
            Image(systemName: node.step.systemImage)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: tileSide, height: tileSide)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: node.meta.label)
                    .textCase(.uppercase)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
                Text(node.step.title)
                    .font(.headline)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 8)
            Button {
                viewModel.clearSelection()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }
}
