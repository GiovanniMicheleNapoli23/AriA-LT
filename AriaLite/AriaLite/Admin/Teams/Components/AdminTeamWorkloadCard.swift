//
//  AdminTeamWorkloadCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda del carico: barra di capacità contro carico, aperti e scaduti, specialità della squadra.
//

import SwiftUI

struct AdminTeamWorkloadCard: View {
    let workload: AdminTeamWorkload?
    let message: String?

    var body: some View {
        AdminCard(title: "Workload", systemImage: "gauge.with.dots.needle.33percent") {
            if let workload {
                content(workload)
            } else if let message {
                AdminSectionNotice(text: message, isError: true)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    private func content(_ workload: AdminTeamWorkload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            AdminTeamLoadBar(workload: workload)
            LabeledContent("Capacity per week") { Text(verbatim: workload.capacityText) }
            LabeledContent("Planned load") { Text(verbatim: workload.loadMinutesText) }
            LabeledContent("Open work orders") { Text(workload.openCount, format: .number) }
            LabeledContent("Overdue") {
                Text(workload.overdueCount, format: .number)
                    .foregroundStyle(workload.overdueCount > 0 ? Color.red : Color.primary)
            }
            if !workload.specialties.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Specialties").font(.footnote).foregroundStyle(.secondary)
                    AdminTeamChipFlow(titles: workload.specialties)
                }
            }
        }
        .font(.subheadline)
    }
}
