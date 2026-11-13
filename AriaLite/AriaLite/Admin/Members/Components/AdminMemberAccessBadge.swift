//
//  AdminMemberAccessBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il badge di stato di una persona (sospesa in azienda, stato dell'app). Niente rosso: sospeso e app sospesa
//  sono grigi, invito scaduto arancio, app attiva verde, invitato nel colore dell'app.
//

import SwiftUI

struct AdminMemberAccessBadge: View {
    let kind: AdminMemberBadgeKind

    var body: some View {
        AdminMemberBadge(text: text, tint: tint)
    }

    private var text: String {
        switch kind {
        case .companySuspended: String(localized: "Suspended")
        case .appInvited: String(localized: "Invited to the app")
        case .appInviteExpired: String(localized: "Invite expired")
        case .appSuspended: String(localized: "App suspended")
        case .appActive: String(localized: "App active")
        }
    }

    private var tint: Color {
        switch kind {
        case .companySuspended, .appSuspended: .secondary
        case .appInviteExpired: .orange
        case .appActive: .green
        case .appInvited: Color.liteAccent
        }
    }
}
