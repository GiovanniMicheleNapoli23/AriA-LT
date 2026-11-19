//
//  AdminUsageCardFrame.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il contenitore di ogni scheda della pagina Usage: titolo, frase che dice a cosa serve e il contenuto, su `liteSurface`.
//  Qui anche i colori dei toni: normale = accento, avviso = ambra, "over" e critico = grigio (mai rosso per un dato).
//

import SwiftUI

struct AdminUsageCardFrame<Content: View>: View {
    let title: Text
    var description: Text?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                title
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                if let description {
                    description
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
    }
}

extension AdminUsageTone {
    /// Normale = accento, avviso = ambra, "over" = grigio.
    var tint: Color {
        switch self {
        case .normal: Color.liteAccent
        case .warning: Color.liteWarning
        case .over: Color.secondary
        }
    }
}

extension AdminUsageAlertTone {
    var tint: Color {
        switch self {
        case .info: Color.liteAccent
        case .warning: Color.liteWarning
        case .critical: Color.secondary
        }
    }

    var symbol: String {
        switch self {
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.circle.fill"
        }
    }
}
