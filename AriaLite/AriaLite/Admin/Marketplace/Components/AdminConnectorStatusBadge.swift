//
//  AdminConnectorStatusBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di un connettore (o della connessione di un membro) come pastiglia colorata con icona.
//

import SwiftUI

struct AdminConnectorStatusBadge: View {
    let status: String

    var body: some View {
        let known = AdminConnectorStatus(raw: status)
        Label(AdminConnectorStatus.label(for: status), systemImage: known.systemImage)
            .font(.caption2.weight(.bold))
            .foregroundStyle(known.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(known.tint.opacity(0.14), in: Capsule())
            .fixedSize()
    }
}
