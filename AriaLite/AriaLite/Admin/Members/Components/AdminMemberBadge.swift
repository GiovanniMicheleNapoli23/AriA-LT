//
//  AdminMemberBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Capsula con un testo corto (ruolo, "Inactive", team ad hoc), in tinta piena o tenue.
//

import SwiftUI

struct AdminMemberBadge: View {
    let text: String
    var tint: Color = .liteAccent

    var body: some View {
        Text(verbatim: text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
    }
}
