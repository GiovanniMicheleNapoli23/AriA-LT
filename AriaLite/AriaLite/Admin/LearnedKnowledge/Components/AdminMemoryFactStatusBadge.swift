//
//  AdminMemoryFactStatusBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di un fatto in una capsula colorata: da rivedere, approvato, rifiutato, in conflitto…
//

import SwiftUI

struct AdminMemoryFactStatusBadge: View {
    let status: String

    private var color: Color {
        switch AdminMemoryFactStatus(rawValue: status) {
        case .approved: .green
        case .pending: .orange
        case .rejected: .red
        case .conflict: .pink
        case .contested: .purple
        case .superseded, nil: .secondary
        }
    }

    var body: some View {
        Label(AdminMemoryFactStatus.label(for: status),
              systemImage: AdminMemoryFactStatus(rawValue: status)?.systemImage ?? "circle")
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .fixedSize()
    }
}
