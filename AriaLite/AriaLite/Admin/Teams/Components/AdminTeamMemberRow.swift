//
//  AdminTeamMemberRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga di membro: nome, ruolo nella squadra, specialità, e un segno se non è attivo.
//

import SwiftUI

struct AdminTeamMemberRow: View {
    let name: String
    let member: AdminTeamMember

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if !member.active {
                    Text("Inactive")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
            }
            if let role = member.trimmedRole {
                Text(verbatim: role).font(.footnote).foregroundStyle(.secondary)
            }
            if !member.specialties.isEmpty { AdminTeamChipFlow(titles: member.specialties) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(member.active ? 1 : 0.7)
        .contentShape(Rectangle())
    }
}
