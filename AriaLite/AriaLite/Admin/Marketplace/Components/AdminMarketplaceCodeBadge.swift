//
//  AdminMarketplaceCodeBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il codice di un allarme o di un ricambio, in monospazio come lo stampano i gestionali di manutenzione.
//

import SwiftUI

struct AdminMarketplaceCodeBadge: View {
    let code: String

    var body: some View {
        Text(verbatim: code)
            .font(.caption.monospaced())
            .foregroundStyle(.primary.opacity(0.85))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
