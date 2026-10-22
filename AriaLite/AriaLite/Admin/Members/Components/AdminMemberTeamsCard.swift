//
//  AdminMemberTeamsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Dove si trova il membro: il team di oggi con il turno e i team di appartenenza (con il ruolo nel team).
//

import SwiftUI

struct AdminMemberTeamsCard: View {
    let member: AdminMember

    var body: some View {
        AdminCard(title: "Teams", systemImage: "person.3") {
            VStack(alignment: .leading, spacing: 12) {
                line(title: "Today", text: member.currentSummary ?? String(localized: "Not on shift today"),
                     isAdHoc: member.currentTeam?.isAdHoc == true, isMuted: member.currentSummary == nil)
                if !member.homeTeams.isEmpty {
                    Divider()
                    ForEach(member.homeTeams) { team in
                        homeLine(role: team.roleInTeam.map(AdminMemberRole.pretty), text: team.teamName,
                                 isAdHoc: team.isAdHoc)
                    }
                }
            }
        }
    }

    private func line(title: LocalizedStringKey, text: String, isAdHoc: Bool, isMuted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            teamText(text, isAdHoc: isAdHoc, isMuted: isMuted)
        }
    }

    private func homeLine(role: String?, text: String, isAdHoc: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let role { Text(verbatim: role).font(.caption).foregroundStyle(.secondary) }
            teamText(text, isAdHoc: isAdHoc, isMuted: false)
        }
    }

    private func teamText(_ text: String, isAdHoc: Bool, isMuted: Bool) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: text)
                .font(.subheadline)
                .foregroundStyle(isMuted ? .secondary : .primary)
            if isAdHoc { AdminMemberBadge(text: String(localized: "Ad hoc"), tint: .orange) }
        }
    }
}
