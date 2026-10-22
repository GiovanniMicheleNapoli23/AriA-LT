//
//  AdminTeamDetailHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: nome, badge ad hoc, stabilimento, numero di membri e descrizione.
//

import SwiftUI

struct AdminTeamDetailHeader: View {
    let team: AdminTeam
    let plantName: String?
    let memberCountText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: team.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.liteText)
            if team.isAdHoc { AdminTeamAdHocBadge(team: team) }
            VStack(alignment: .leading, spacing: 4) {
                if let plantName { Label(plantName, systemImage: "building.2") }
                Label(memberCountText, systemImage: "person.2")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if let description = team.trimmedDescription {
                Text(verbatim: description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
