//
//  AdminSparePartStatusBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di un ricambio come capsula colorata (approvato verde, in revisione arancio, rifiutato rosso).
//

import SwiftUI

struct AdminSparePartStatusBadge: View {
    let status: AdminSparePartStatus

    private var color: Color {
        switch status {
        case .approved: .green
        case .staged: .orange
        case .rejected: .red
        case .draft: Color.liteAccent
        case .superseded, .unknown: .secondary
        }
    }

    var body: some View {
        Text(status.localized)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }
}
