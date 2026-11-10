//
//  AdminAlarmDiagnosisResult.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il risultato della diagnosi: gravità e fiducia, la causa probabile in evidenza, passi di riparazione,
//  ricambi e il pulsante "Create work order" (che apre il modulo precompilato). Le parti vuote non si
//  mostrano.
//

import SwiftUI

struct AdminAlarmDiagnosisResult: View {
    let diagnosis: AdminAlarmDiagnosis
    let viewModel: AdminAlarmDiagnosisViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !diagnosis.severity.isEmpty { AdminAlarmSeverityBadge(severity: diagnosis.severity) }
            AdminAlarmConfidenceMeter(title: "Confidence", fraction: Double(diagnosis.confidencePercent) / 100)
            if !diagnosis.rootCause.isEmpty { rootCause }
            if !diagnosis.repairSteps.isEmpty {
                section("Repair steps") {
                    AdminAlarmNumberedList(items: diagnosis.repairSteps.map { .init(title: $0.title, detail: $0.detail) })
                }
            }
            if !diagnosis.spareParts.isEmpty {
                section("Spare parts") { parts }
            }
            workOrder
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold))
            content()
        }
    }

    private var rootCause: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Likely root cause", systemImage: "scope")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: diagnosis.rootCause)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.liteAccent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var parts: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(diagnosis.spareParts.enumerated()), id: \.offset) { index, part in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "shippingbox")
                        .font(.subheadline)
                        .foregroundStyle(Color.liteAccent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: part.name).font(.subheadline)
                        let meta = [part.code, part.availability].compactMap { $0 }.joined(separator: " · ")
                        if !meta.isEmpty {
                            Text(verbatim: meta).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    if let quantity = part.quantity {
                        Text("Qty \(quantity)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .textSelection(.enabled)
                .accessibilityElement(children: .combine)
                if index < diagnosis.spareParts.count - 1 { Divider() }
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
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.liteAccent)
            }
            .font(.subheadline.weight(.semibold))
        } else if viewModel.canCreateWorkOrder {
            Button { viewModel.startWorkOrder() } label: {
                Label("Create work order", systemImage: "wrench.and.screwdriver")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .ariaGlassButtonStyle()
        }
    }
}
