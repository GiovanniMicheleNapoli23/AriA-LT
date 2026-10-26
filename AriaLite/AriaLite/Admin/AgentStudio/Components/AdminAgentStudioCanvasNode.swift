//
//  AdminAgentStudioCanvasNode.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  La scheda di un nodo sul canvas, come quella della web: icona e tipo nel suo colore, titolo, riassunto
//  (o avviso) e le uscite con un nome. Toccarla sceglie il nodo.
//

import SwiftUI

struct AdminAgentStudioCanvasNode: View {
    let node: AdminAgentStudioGraphNode
    let viewModel: AdminAgentStudioCanvasViewModel

    @ScaledMetric(relativeTo: .caption) private var tileSide: CGFloat = 24

    private var isSelected: Bool { viewModel.selectedNodeId == node.id }
    private var isLoop: Bool { node.kind == "loop" }
    private var color: Color { Color(adminAgentStudioHex: node.meta.colorHex) }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: isLoop ? 24 : 14, style: .continuous) }

    var body: some View {
        Button {
            viewModel.select(node.id)
        } label: {
            card
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "\(node.meta.label), \(node.step.title)"))
        .accessibilityValue(viewModel.summary(for: node) ?? viewModel.warning(for: node) ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: node.step.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: tileSide, height: tileSide)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityHidden(true)
                Text(verbatim: node.meta.label)
                    .textCase(.uppercase)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)
            }
            Text(node.step.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liteText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            detail
            if !isLoop { outlets }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.liteSurface, in: shape)
        .overlay { border }
        .overlay {
            if isSelected { shape.strokeBorder(color, lineWidth: 1.5) }
        }
        .shadow(color: isSelected ? color.opacity(0.35) : .black.opacity(0.06), radius: isSelected ? 10 : 3, y: isSelected ? 3 : 1)
        .contentShape(shape)
    }

    @ViewBuilder
    private var detail: some View {
        if let warning = viewModel.warning(for: node) {
            Text(warning)
                .font(.caption)
                .foregroundStyle(Color.liteWarning)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        } else if let summary = viewModel.summary(for: node) {
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private var outlets: some View {
        let labelled = node.labelledOutlets
        if !labelled.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(labelled.enumerated()), id: \.offset) { _, outlet in
                    Text(verbatim: "→ \(outlet.label ?? "")")
                        .font(.caption2)
                        .foregroundStyle(outlet.role == .error ? Color.liteDanger : Color.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    /// Un loop e un tipo sconosciuto hanno il bordo tratteggiato.
    @ViewBuilder
    private var border: some View {
        if isLoop || !node.meta.isKnown {
            shape.strokeBorder(color.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
        } else {
            shape.strokeBorder(Color.liteBorder, lineWidth: 0.5)
        }
    }
}
