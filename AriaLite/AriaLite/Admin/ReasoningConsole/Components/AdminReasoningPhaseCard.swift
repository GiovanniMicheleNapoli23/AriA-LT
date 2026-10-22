//
//  AdminReasoningPhaseCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una fase della trace (perception, retrieval, prompt, generation…) come sezione chiusa di default:
//  il titolo dice quanto contiene, si apre per leggerla.
//

import SwiftUI

struct AdminReasoningPhaseCard: View {
    let phase: AdminReasoningPhase

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            AdminReasoningFieldsAndBlocks(fields: phase.fields, blocks: phase.blocks)
                .padding(.top, 8)
        } label: {
            HStack(spacing: 10) {
                Label(phase.title, systemImage: phase.systemImage)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(phase.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .tint(Color.liteAccent)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
