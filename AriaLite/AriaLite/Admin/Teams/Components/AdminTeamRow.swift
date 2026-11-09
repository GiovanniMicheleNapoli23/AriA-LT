//
//  AdminTeamRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Scheda di una squadra nella lista: nome e badge ad hoc, stabilimento e numero di membri, barra del carico.
//

import SwiftUI

struct AdminTeamRow: View {
    let team: AdminTeam
    let plantName: String?
    let workload: AdminTeamWorkload?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: team.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            if team.isAdHoc { AdminTeamAdHocBadge(team: team) }
            HStack(spacing: 12) {
                if let plantName {
                    Label(plantName, systemImage: "building.2")
                }
                Label("\(team.members.count) members", systemImage: "person.2")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            AdminTeamLoadBar(workload: workload)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
