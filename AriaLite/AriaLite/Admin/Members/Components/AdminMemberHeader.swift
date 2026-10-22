//
//  AdminMemberHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: avatar grande, nome, email (da toccare per scrivere), ruolo e stato.
//

import SwiftUI

struct AdminMemberHeader: View {
    let member: AdminMember

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            AdminMemberAvatar(initials: member.initials, isActive: member.isActive, isLarge: true)
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
                HStack(spacing: 6) {
                    if let role = member.roleLabel { AdminMemberBadge(text: role) }
                    AdminMemberBadge(text: statusText, tint: member.isActive ? .green : .secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusText: String {
        member.isActive ? String(localized: "Active") : String(localized: "Inactive")
    }
}
