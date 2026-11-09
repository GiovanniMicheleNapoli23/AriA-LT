//
//  AdminTeamBoardTeamMenu.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il menu per scegliere di quale squadra è la bacheca.
//

import SwiftUI

struct AdminTeamBoardTeamMenu: View {
    let title: String
    let teams: [AdminTeam]
    let selectedId: String?
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(teams) { team in
                Button {
                    onSelect(team.id)
                } label: {
                    if team.id == selectedId {
                        Label(team.title, systemImage: "checkmark")
                    } else {
                        Text(verbatim: team.title)
                    }
                }
            }
        } label: {
            Label {
                Text(verbatim: title).lineLimit(1)
            } icon: {
                Image(systemName: "person.3")
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule(), interactive: true)
        }
        .tint(.primary)
    }
}
