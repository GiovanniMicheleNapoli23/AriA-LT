//
//  AdminUserShiftRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Una riga della cronologia: il team (con "Ad hoc") e sotto il turno e le note. Il giorno sta nell'intestazione.
//

import SwiftUI

struct AdminUserShiftRow: View {
    let shift: AdminMemberShift

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(verbatim: shift.teamTitle)
                    .font(.body)
                if shift.teamIsAdHoc { AdminMemberBadge(text: String(localized: "Ad hoc"), tint: .orange) }
            }
            Text(verbatim: [shift.typeLabel, shift.notes].compactMap { $0 }.joined(separator: " · "))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
