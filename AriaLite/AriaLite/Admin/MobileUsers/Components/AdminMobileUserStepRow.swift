//
//  AdminMobileUserStepRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un passo dell'ordine di lavoro in sola lettura: testo, fatto o non fatto, nota dell'operatore, quante
//  foto e chi l'ha segnato e quando. Un passo senza report è "Not reported yet".
//

import SwiftUI

struct AdminMobileUserStepRow: View {
    let data: AdminMobileUserStepRowData

    private var title: String {
        if let text = data.text { return text }
        return String(localized: "Step no longer in the procedure")
    }

    private var statusColor: Color {
        guard let report = data.report else { return .secondary }
        return report.isDone ? .green : .orange
    }

    private var statusText: String {
        guard let report = data.report else { return String(localized: "Not reported yet") }
        return report.isDone ? String(localized: "Done") : String(localized: "Not done")
    }

    private var statusIcon: String {
        guard let report = data.report else { return "circle.dashed" }
        return report.isDone ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var byLine: String? {
        guard let report = data.report else { return nil }
        let name = report.statusByName ?? report.reportedByName
        let date = (report.statusAt ?? report.reportedAt)?.formatted(date: .abbreviated, time: .shortened)
        let line = [name, date].compactMap { $0 }.joined(separator: " · ")
        return line.isEmpty ? nil : line
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                if let number = data.number {
                    Text("Step \(number)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                if let note = data.report?.note {
                    Text(note)
                        .font(.footnote)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.liteAccent.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                if let report = data.report, report.photoCount > 0 {
                    Label("\(report.photoCount) photos", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let byLine {
                    Text(byLine)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
