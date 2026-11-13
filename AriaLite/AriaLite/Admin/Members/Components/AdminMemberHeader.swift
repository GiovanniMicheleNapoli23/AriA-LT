//
//  AdminMemberHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: avatar grande, nome, email (da toccare per scrivere), riga del ruolo e badge di
//  stato. La riga e il badge li decide il view model (AdminMemberRules); qui si mostrano soltanto.
//

import SwiftUI

struct AdminMemberHeader: View {
    let member: AdminMember
    /// "Owner", "Admin", il ruolo o "Needs a role".
    let roleLine: String?
    /// "Needs a role" si legge in grigio, un ruolo vero nel colore dell'app.
    var roleLineIsMuted = false
    let badge: AdminMemberBadgeKind?

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            AdminMemberAvatar(initials: member.initials, isActive: member.isActive && !member.isSuspendedInCompany,
                              isLarge: true)
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: member.displayName)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if let email = member.secondaryLine {
                    if let url = URL(string: "mailto:\(email)") {
                        Link(destination: url) {
                            Text(verbatim: email).font(.subheadline)
                        }
                    } else {
                        Text(verbatim: email).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                badges
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var badges: some View {
        AdminMobileUserFlowLayout(spacing: 6) {
            if let roleLine { AdminMemberBadge(text: roleLine, tint: roleLineIsMuted ? .secondary : .liteAccent) }
            if let badge { AdminMemberAccessBadge(kind: badge) }
        }
    }
}
