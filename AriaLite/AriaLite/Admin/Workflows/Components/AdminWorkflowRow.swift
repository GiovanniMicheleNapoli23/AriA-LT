//
//  AdminWorkflowRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di un flusso nella lista: stato, nome, descrizione e quanti passi ha.
//

import SwiftUI

struct AdminWorkflowRow: View {
    let flow: AdminWorkflow

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AdminWorkflowStatusBadge(status: flow.knownStatus)
                if flow.isPublished { AdminWorkflowPublishedBadge(version: flow.definitionVersion) }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            Text(flow.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            if let description = flow.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 6 : 2)
            }
            HStack(spacing: 12) {
                Label("\(flow.graph.nodes.count) steps", systemImage: "square.stack.3d.up")
                if let updated = flow.updatedAt {
                    Label(updated.formatted(.relative(presentation: .named)), systemImage: "clock")
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
