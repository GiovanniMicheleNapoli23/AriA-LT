//
//  AdminInspectionRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di un'ispezione nella lista: titolo, asset e zona, scadenza, avanzamento e stato.
//

import SwiftUI

struct AdminInspectionRow: View {
    let inspection: AdminInspection
    let plantName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(inspection.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer(minLength: 8)
                AdminInspectionStatusBadge(status: inspection.status, isOverdue: inspection.isOverdue())
            }
            if !inspection.placeLine.isEmpty {
                Text(inspection.placeLine)
                    .font(.caption.weight(.medium).monospaced())
                    .foregroundStyle(Color.liteAccent)
                    .lineLimit(1)
            }
            if inspection.totalCount > 0 {
                AdminInspectionProgressBar(checked: inspection.checkedCount, total: inspection.totalCount)
            }
            HStack(spacing: 12) {
                if let due = inspection.dueDate {
                    Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .foregroundStyle(inspection.isOverdue() ? Color.red : Color.secondary)
                }
                if let plantName {
                    Label(plantName, systemImage: "building.2").lineLimit(1)
                }
                if !inspection.flaggedItems.isEmpty {
                    Label("\(inspection.flaggedItems.count)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
