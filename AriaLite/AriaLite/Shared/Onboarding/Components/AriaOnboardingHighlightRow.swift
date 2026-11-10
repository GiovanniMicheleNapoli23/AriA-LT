//
//  AriaOnboardingHighlightRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Una voce sotto il testo di una pagina: simbolo e titolo, e sotto cosa fa (le sezioni dell'admin).
//

import SwiftUI

struct AriaOnboardingHighlightRow: View {
    let highlight: AriaOnboardingPage.Highlight

    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 26

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: highlight.symbol)
                .font(.body)
                .foregroundStyle(Color.liteAccent)
                .frame(width: iconWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(highlight.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.liteText)
                if let detail = highlight.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }
}
