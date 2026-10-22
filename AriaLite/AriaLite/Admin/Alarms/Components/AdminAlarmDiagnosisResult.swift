//
//  AdminAlarmDiagnosisResult.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il risultato della diagnosi: gravità e fiducia, causa probabile, passi di riparazione, ricambi e il
//  pulsante "Create work order" (che apre il modulo precompilato). Le parti vuote non si mostrano.
//

import SwiftUI

struct AdminAlarmDiagnosisResult: View {
    let diagnosis: AdminAlarmDiagnosis
    let viewModel: AdminAlarmDiagnosisViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                if !diagnosis.severity.isEmpty { AdminAlarmSeverityBadge(severity: diagnosis.severity) }
                Label("Confidence \(diagnosis.confidencePercent)%", systemImage: "gauge.with.dots.needle.50percent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if !diagnosis.rootCause.isEmpty {
                section("Likely root cause") {
                    Text(verbatim: diagnosis.rootCause).font(.subheadline).textSelection(.enabled)
                }
            }
            if !diagnosis.repairSteps.isEmpty {
                section("Repair steps") { steps }
            }
            if !diagnosis.spareParts.isEmpty {
                section("Spare parts") { parts }
            }
            workOrder
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            content()
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(diagnosis.repairSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "\(index + 1).")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: step.title).font(.subheadline)
                        if let detail = step.detail {
                            Text(verbatim: detail).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .textSelection(.enabled)
                }
            }
        }
    }

    private var parts: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(diagnosis.spareParts.enumerated()), id: \.offset) { _, part in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: part.name).font(.subheadline)
                    let meta = [part.code, part.quantity.map { String(localized: "Qty \($0)") }, part.availability]
                        .compactMap { $0 }.joined(separator: " · ")
                    if !meta.isEmpty {
                        Text(verbatim: meta).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private var workOrder: some View {
        if let created = viewModel.createdWorkOrder {
            Label {
                if let title = created.title {
                    Text("Work order created: \(title)")
                } else {
                    Text("Work order created")
                }
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            .font(.subheadline.weight(.semibold))
        } else {
            Button { viewModel.startWorkOrder() } label: {
                Label("Create work order", systemImage: "wrench.and.screwdriver")
            }
            .ariaGlassButtonStyle()
        }
    }
}
