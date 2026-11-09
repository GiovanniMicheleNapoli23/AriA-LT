//
//  AdminTeamBoardMoveMenu.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il menu di una card: "Move to…" (gli stati in cui si può portare) e "Assign to team…" (le altre squadre). Sta
//  sulla card come pulsante "…" e nel menu contestuale.
//

import SwiftUI

struct AdminTeamBoardMoveMenu: View {
    let statuses: [AdminTeamWorkOrderStatus]
    let teams: [AdminTeam]
    let onMove: (AdminTeamWorkOrderStatus) -> Void
    let onAssign: (AdminTeam) -> Void

    var body: some View {
        Menu {
            ForEach(statuses, id: \.self) { status in
                Button(role: status == .cancelled ? .destructive : nil) {
                    onMove(status)
                } label: {
                    Label(status.label, systemImage: status.systemImage)
                }
            }
        } label: {
            Label("Move to…", systemImage: "arrow.left.arrow.right")
        }
        if !teams.isEmpty {
            Menu {
                ForEach(teams) { team in
                    Button(team.title) { onAssign(team) }
                }
            } label: {
                Label("Assign to team…", systemImage: "person.3")
            }
        }
    }
}
