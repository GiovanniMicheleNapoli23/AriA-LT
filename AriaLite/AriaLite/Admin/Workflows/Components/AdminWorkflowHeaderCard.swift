//
//  AdminWorkflowHeaderCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: stato, nome, descrizione, date e i numeri del flusso (revisione,
//  versione pubblicata, passi, collegamenti).
//

import SwiftUI

struct AdminWorkflowHeaderCard: View {
    let flow: AdminWorkflow
    let datesLine: String
    let stats: [AdminWorkflowDetailViewModel.Stat]

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AdminWorkflowStatusBadge(status: flow.knownStatus)
                if flow.isPublished { AdminWorkflowPublishedBadge(version: flow.definitionVersion) }
            }
            Text(flow.name)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.leading)
            if let description = flow.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            if !datesLine.isEmpty {
                Text(datesLine)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(stats) { AdminStatTile(title: $0.title, value: $0.value, systemImage: $0.systemImage) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
