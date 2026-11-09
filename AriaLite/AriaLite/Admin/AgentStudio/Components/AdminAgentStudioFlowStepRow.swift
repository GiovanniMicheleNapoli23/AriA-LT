//
//  AdminAgentStudioFlowStepRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Un passo del flusso "How it works": bolla con il simbolo del nodo, filo sottile verso il passo dopo,
//  titolo leggibile e dettaglio su al massimo tre righe. Niente testo selezionabile.
//

import SwiftUI

struct AdminAgentStudioFlowStepRow: View {
    let step: AdminAgentStudioWorkflowStep
    var isLast = false

    @ScaledMetric(relativeTo: .subheadline) private var bubble: CGFloat = 32
    @ScaledMetric(relativeTo: .subheadline) private var lineWidth: CGFloat = 2

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Image(systemName: step.systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.liteAccent)
                    .frame(width: bubble, height: bubble)
                    .background(Color.liteAccent.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                if !isLast {
                    Capsule()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: lineWidth)
                        .frame(maxHeight: .infinity)
                        .padding(.bottom, 4)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(step.flowTitle)
                    .font(.subheadline.weight(.semibold))
                if let detail = step.flowDetail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .multilineTextAlignment(.leading)
            .frame(minHeight: bubble, alignment: .leading)
            .padding(.bottom, isLast ? 0 : 12)
            Spacer(minLength: 8)
        }
        .accessibilityElement(children: .combine)
    }
}
