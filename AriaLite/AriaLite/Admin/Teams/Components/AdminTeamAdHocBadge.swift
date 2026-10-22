//
//  AdminTeamAdHocBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il badge delle squadre ad hoc, con la data di fine se c'è (e "Expired" se è passata).
//

import SwiftUI

struct AdminTeamAdHocBadge: View {
    let team: AdminTeam

    private var text: String {
        guard let expiresAt = team.expiresAt else { return String(localized: "Ad hoc") }
        if team.isExpired() { return String(localized: "Ad hoc · expired") }
        return String(localized: "Ad hoc · until \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
    }

    var body: some View {
        let tint: Color = team.isExpired() ? .red : .orange
        Label(text, systemImage: "clock.badge")
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule())
    }
}
