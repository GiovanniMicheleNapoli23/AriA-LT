//
//  AdminInspectionStatusBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di un'ispezione come pastiglia colorata (in corso blu, completata verde…); con la scadenza
//  superata si può mostrare "Overdue" al suo posto.
//

import SwiftUI

struct AdminInspectionStatusBadge: View {
    let status: String?
    var isOverdue = false

    private var color: Color {
        if isOverdue { return .red }
        return switch AdminInspectionStatus(raw: status) {
        case .pending?: .orange
        case .inProgress?: .blue
        case .completed?: .green
        case .cancelled?, nil: .secondary
        }
    }

    private var label: String {
        if isOverdue { return String(localized: "Overdue") }
        return status.map(AdminInspectionStatus.label(for:)) ?? String(localized: "Pending")
    }

    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .fixedSize()
    }
}
