//
//  AdminAgentStudioStepRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un passo del workflow in sola lettura: numero, simbolo del tipo di nodo, titolo e dettaglio
//  (il compito dell'agente, la funzione del connettore…).
//

import SwiftUI

struct AdminAgentStudioStepRow: View {
    let index: Int
    let step: AdminAgentStudioWorkflowStep
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(index)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 18, alignment: .trailing)
                    .padding(.top, 2)
                Image(systemName: step.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liteAccent)
                    .frame(minWidth: 22)
                    .padding(.top, 1)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                        .textSelection(.enabled)
                    if let detail = step.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .textSelection(.enabled)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            if showsDivider { Divider() }
        }
        .accessibilityElement(children: .combine)
    }
}
