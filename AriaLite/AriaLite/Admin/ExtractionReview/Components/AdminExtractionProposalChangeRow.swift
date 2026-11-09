//
//  AdminExtractionProposalChangeRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un campo che l'AI propone di cambiare: il valore di adesso (barrato) e quello proposto.
//

import SwiftUI

struct AdminExtractionProposalChangeRow: View {
    let change: AdminExtractionAIProposal.Change

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(change.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if !change.current.isEmpty {
                Text(change.current)
                    .font(.footnote)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            Text(change.proposed)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
