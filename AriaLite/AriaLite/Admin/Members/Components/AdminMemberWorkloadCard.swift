//
//  AdminMemberWorkloadCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il carico di lavoro del membro: ordini aperti, tempo stimato e quanti sono in ritardo.
//

import SwiftUI

struct AdminMemberWorkloadCard: View {
    let workload: AdminMemberWorkload

    var body: some View {
        AdminCard(title: "Workload", systemImage: "gauge.with.dots.needle.33percent") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), alignment: .leading)],
                      alignment: .leading, spacing: 12) {
                stat(value: "\(workload.openCount)", label: "Open")
                stat(value: workload.durationText ?? "0", label: "Estimated time")
                stat(value: "\(workload.overdueCount)", label: "Overdue", isAlert: workload.overdueCount > 0)
            }
        }
    }

    private func stat(value: String, label: LocalizedStringKey, isAlert: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isAlert ? Color.red : Color.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
