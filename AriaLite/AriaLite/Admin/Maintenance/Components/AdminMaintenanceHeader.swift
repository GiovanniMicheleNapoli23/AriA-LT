//
//  AdminMaintenanceHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio, come quella di un allarme: il nome come titolo e la descrizione; su una riga
//  stato e scadenza come pastiglie con frequenza, asset e luogo accanto; sotto, le date della programmazione
//  in due colonne ("Next due  12 dic · tra 4 settimane"). Niente icona né schede.
//

import SwiftUI

struct AdminMaintenanceHeader: View {
    let plan: AdminMaintenancePlan
    /// Frequenza, asset, zona, stabilimento e categoria in una riga.
    let summary: String
    let schedule: [AdminMaintenanceScheduleRow]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(plan.name)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            if let description = plan.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            metaLine
                .padding(.top, 2)
            if !schedule.isEmpty {
                scheduleGrid
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Pastiglie e sintesi su una riga; col testo molto grande la sintesi va sotto.
    private var metaLine: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
        return layout {
            if let status = plan.status { AdminMaintenanceStatusBadge(status: status) }
            AdminMaintenanceDueBadge(state: plan.dueState)
            if !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .textSelection(.enabled)
            }
        }
    }

    private var scheduleGrid: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 4) {
            ForEach(schedule) { row in
                GridRow {
                    Text(row.title)
                        .foregroundStyle(.secondary)
                    Text(row.value)
                        .fontWeight(.medium)
                        .foregroundStyle(tint(for: row.dueState))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .font(.subheadline)
    }

    /// Come la pastiglia della scadenza: scaduta rossa, in scadenza arancio.
    private func tint(for state: AdminMaintenanceDueState?) -> Color {
        switch state {
        case .overdue: .red
        case .dueSoon: .orange
        case .later, .unscheduled, nil: .primary
        }
    }
}
