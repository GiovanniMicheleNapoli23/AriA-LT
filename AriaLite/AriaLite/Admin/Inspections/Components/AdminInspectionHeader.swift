//
//  AdminInspectionHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: titolo, stato, asset e zona, stabilimento, assegnatario e scadenza.
//

import SwiftUI

struct AdminInspectionHeader: View {
    let inspection: AdminInspection
    let plantName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(inspection.title)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Spacer(minLength: 8)
                AdminInspectionStatusBadge(status: inspection.status, isOverdue: inspection.isOverdue())
            }
            VStack(alignment: .leading, spacing: 8) {
                if !inspection.placeLine.isEmpty {
                    line(inspection.placeLine, "gearshape.2")
                }
                if let plantName { line(plantName, "building.2") }
                if let assignee = inspection.assignedTo { line(assignee, "person") }
                if let due = inspection.dueDate {
                    line(String(localized: "Due \(due.formatted(date: .abbreviated, time: .omitted))"), "calendar",
                         tint: inspection.isOverdue() ? .red : nil)
                }
                if let done = inspection.completedAt {
                    line(String(localized: "Completed \(done.formatted(date: .abbreviated, time: .shortened))"),
                         "checkmark.seal", tint: .green)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private func line(_ text: String, _ systemImage: String, tint: Color? = nil) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(tint ?? Color.secondary)
            .labelStyle(AdminInspectionHeaderLabelStyle())
    }
}

/// Icona di larghezza fissa a sinistra, testo che va a capo allineato.
private struct AdminInspectionHeaderLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.frame(minWidth: 20)
            configuration.title.fixedSize(horizontal: false, vertical: true)
        }
    }
}
