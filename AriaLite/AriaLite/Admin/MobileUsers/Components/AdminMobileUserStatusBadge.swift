//
//  AdminMobileUserStatusBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di un operatore in una capsula colorata: attivo, invitato, invito scaduto, sospeso, revocato.
//

import SwiftUI

struct AdminMobileUserStatusBadge: View {
    let status: String

    private var known: AdminMobileUserStatus? { AdminMobileUserStatus(rawValue: status) }

    private var color: Color {
        switch known {
        case .active: .green
        case .invited: .blue
        case .expired: .orange
        case .suspended: .purple
        case .revoked: .red
        case nil: .secondary
        }
    }

    var body: some View {
        Label(AdminMobileUserStatus.label(for: status), systemImage: known?.systemImage ?? "circle")
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .fixedSize()
    }
}
