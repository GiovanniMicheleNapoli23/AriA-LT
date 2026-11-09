//
//  LoginCardRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga della card del login, come nelle Impostazioni di sistema: icona a sinistra, poi il campo.
//

import SwiftUI

struct LoginCardRow<Content: View>: View {
    let icon: String
    @ViewBuilder let content: Content
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 20

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: iconWidth)
            content
                .font(.body)
                .foregroundStyle(Color.liteText)
        }
        .padding(.horizontal, 16)
        // 54pt a testo "Large"; coi testi grandi la riga cresce quanto il campo.
        .padding(.vertical, 8)
        .frame(minHeight: 54)
    }
}
