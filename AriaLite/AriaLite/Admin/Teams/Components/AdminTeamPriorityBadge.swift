//
//  AdminTeamPriorityBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il badge della priorità di un ordine, nel colore della priorità.
//

import SwiftUI

struct AdminTeamPriorityBadge: View {
    let priority: AdminTeamWorkOrderPriority

    var body: some View {
        Text(priority.label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(priority.tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(priority.tint.opacity(0.14), in: Capsule())
    }
}
