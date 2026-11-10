//
//  AriaOnboardingPageView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Il testo di una pagina, allineato a sinistra sotto la sfera: titolo grande e leggero, la frase e le voci
//  su righe sottili, senza card. Il simbolo della pagina sta nel medaglione della sfera (AriaOnboardingOrb).
//  Scorre con testo grande, su SE e in orizzontale.
//

import SwiftUI

struct AriaOnboardingPageView: View {
    let page: AriaOnboardingPage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AriaOnboardingTitle(text: page.title)
                Text(page.message)
                    .font(.body)
                    .lineSpacing(3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !page.highlights.isEmpty {
                    highlights.padding(.top, 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 8)
            .ariaReadableWidth(560)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(page.highlights) { highlight in
                Rectangle()
                    .fill(Color.liteBorder)
                    .frame(height: 0.5)
                AriaOnboardingHighlightRow(highlight: highlight)
            }
        }
    }
}
