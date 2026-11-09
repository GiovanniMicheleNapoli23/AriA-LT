//
//  AdminAssetStatusBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di un asset come pastiglia colorata (approvato verde, bozza arancio…).
//

import SwiftUI

struct AdminAssetStatusBadge: View {
    let status: String

    private var color: Color {
        switch AdminAssetStatus(rawValue: status) {
        case .approved: .green
        case .draft: .orange
        case .staged: .blue
        case .rejected: .red
        case .superseded, nil: .secondary
        }
    }

    var body: some View {
        Text(AdminAssetStatus.label(for: status))
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .fixedSize()
    }
}
