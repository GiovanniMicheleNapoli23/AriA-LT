//
//  AdminAgentStudioIcon.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un simbolo in un quadrato tinto col colore dell'app, accanto alle righe delle liste.
//  Il quadrato cresce col Dynamic Type come il testo che lo accompagna.
//

import SwiftUI

struct AdminAgentStudioIcon: View {
    let systemImage: String
    var tint: Color = .liteAccent

    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 36

    var body: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: side, height: side)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: side * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}
