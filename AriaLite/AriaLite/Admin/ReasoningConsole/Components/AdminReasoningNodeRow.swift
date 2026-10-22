//
//  AdminReasoningNodeRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un nodo del grafo nella cascata del turno: nome, durata con la barra rispetto al più lento,
//  esito ed errore. Si apre per i valori e i blocchi JSON (input, output, argomenti dei tool…).
//

import SwiftUI

struct AdminReasoningNodeRow: View {
    let node: AdminReasoningNode

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if let error = node.error {
                    Text(error)
                        .font(.caption.monospaced())
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                AdminReasoningFieldsAndBlocks(fields: node.fields, blocks: node.blocks)
            }
            .padding(.top, 6)
        } label: {
            header
        }
        .tint(.secondary)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if node.hasError {
                    Image(systemName: "exclamationmark.octagon.fill").foregroundStyle(.red)
                }
                Text(node.name)
                    .font(.subheadline.weight(.semibold).monospaced())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if let duration = node.durationText {
                    Text(duration)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if node.durationMs != nil {
                // La barra della cascata: lunga quanto il nodo rispetto al più lento.
                Capsule()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(node.hasError ? Color.red : Color.liteAccent)
                            .scaleEffect(x: max(node.share, 0.02), y: 1, anchor: .leading)
                    }
                    .accessibilityHidden(true)
            }
            if let status = node.status {
                Text(AdminReasoningFormat.humanize(status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
