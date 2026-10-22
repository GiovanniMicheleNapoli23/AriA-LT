//
//  AdminAgentStudioRunStepRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il verdetto di un nodo in un run: nodo o agente, esito, motivo, durata e costo.
//  L'output dell'agente si apre a richiesta (può essere lungo).
//

import SwiftUI

struct AdminAgentStudioRunStepRow: View {
    let step: AdminAgentStudioRunStep
    var showsDivider = true

    @State private var showsOutput = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(step.agentName ?? step.nodeId)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    if let iteration = step.iteration {
                        Text("#\(iteration)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    AdminAgentStudioBadge(status: step.outcome)
                }
                if let reason = step.reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let metrics = step.metricsLine {
                    Text(metrics)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if let output = step.output {
                    DisclosureGroup(isExpanded: $showsOutput) {
                        Text(output)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    } label: {
                        Text("Output").font(.caption.weight(.semibold))
                    }
                    .tint(Color.liteAccent)
                }
            }
            .padding(.vertical, 10)
            if showsDivider { Divider() }
        }
    }
}
