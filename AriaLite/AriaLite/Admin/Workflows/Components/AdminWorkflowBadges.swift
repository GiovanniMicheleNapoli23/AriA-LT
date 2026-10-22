//
//  AdminWorkflowBadges.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I distintivi di un flusso: lo stato (bozza, archiviato) e, se c'è, la versione pubblicata.
//

import SwiftUI

struct AdminWorkflowStatusBadge: View {
    let status: AdminWorkflowStatus

    private var color: Color { status == .archived ? .secondary : .orange }

    var body: some View {
        Label(status.label, systemImage: status.systemImage)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .fixedSize()
    }
}

struct AdminWorkflowPublishedBadge: View {
    let version: Int

    var body: some View {
        Label("Published v\(version)", systemImage: "paperplane.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.green)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.14), in: Capsule())
            .fixedSize()
    }
}
