//
//  AdminDocumentStatusBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La pillola con lo stato complessivo di un documento (in elaborazione, pronto, fallito…).
//

import SwiftUI

struct AdminDocumentStatusBadge: View {
    let group: AdminDocumentStatusGroup

    var body: some View {
        Label(group.label, systemImage: group.systemImage)
            .font(.caption2.weight(.bold))
            .foregroundStyle(group.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(group.tint.opacity(0.14), in: Capsule())
            .fixedSize()
    }
}
