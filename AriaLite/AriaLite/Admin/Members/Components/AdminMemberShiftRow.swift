//
//  AdminMemberShiftRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga dell'elenco dei turni: giorno, team, tipo di turno e note, con il menu per toglierlo.
//

import SwiftUI

struct AdminMemberShiftRow: View {
    let shift: AdminMemberShift
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: shift.dateText)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(verbatim: "\(shift.teamTitle) · \(shift.typeLabel)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if shift.teamIsAdHoc { AdminMemberBadge(text: String(localized: "Ad hoc"), tint: .orange) }
                }
                if let notes = shift.notes {
                    Text(verbatim: notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            Menu {
                Button("Remove shift", systemImage: "trash", role: .destructive, action: onRemove)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(Color.liteAccent)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Shift actions"))
        }
        .contextMenu {
            Button("Remove shift", systemImage: "trash", role: .destructive, action: onRemove)
        }
    }
}
