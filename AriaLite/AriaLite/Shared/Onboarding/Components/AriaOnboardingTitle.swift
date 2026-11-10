//
//  AriaOnboardingTitle.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Il titolo della presentazione: SF Pro leggero e più grande di `.largeTitle`. Nessuno stile di testo di iOS
//  va oltre, quindi la dimensione è quella a testo "Large" e scala con le metriche di `.largeTitle`, come il logo
//  (AriaWordmark): segue il Dynamic Type come un font di sistema.
//

import SwiftUI

struct AriaOnboardingTitle: View {
    let text: LocalizedStringResource
    /// La dimensione a testo "Large".
    var size: CGFloat = 44

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var scaled: CGFloat {
        UIFontMetrics(forTextStyle: .largeTitle)
            .scaledValue(for: size, compatibleWith: UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize)))
    }

    var body: some View {
        Text(text)
            .font(.system(size: scaled, weight: .light))
            .tracking(-scaled * 0.02)
            .foregroundStyle(Color.liteText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}
