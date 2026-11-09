//
//  AriaWordmark.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/09/26.
//
//  Il nome dell'app come logo: "AriaPLT" pieno, "Mobile" più leggero.
//  In riga nella sidebar; impilato al login ("Mobile" sotto, maiuscolo e spaziato).
//

import SwiftUI

struct AriaWordmark: View {
    var size: CGFloat = 30
    /// "Mobile" sotto "AriaPLT" invece che accanto.
    var stacked = false
    /// La dimensione data è quella a testo "Large": segue il Dynamic Type come un `@ScaledMetric`.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// `size` scalata con le metriche di `.largeTitle` (il logo è un titolo).
    private var scaled: CGFloat {
        UIFontMetrics(forTextStyle: .largeTitle)
            .scaledValue(for: size, compatibleWith: UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize)))
    }

    var body: some View {
        Group {
            if stacked {
                VStack(spacing: scaled * 0.12) {
                    Text(verbatim: "AriaPLT")
                        .font(.system(size: scaled, weight: .bold))
                        .tracking(-scaled * 0.02)
                        .foregroundStyle(Color.liteText)
                    Text(verbatim: "MOBILE")
                        .font(.system(size: scaled * 0.32, weight: .semibold))
                        .tracking(scaled * 0.14)
                        .foregroundStyle(Color.liteText.opacity(0.45))
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: scaled * 0.22) {
                    Text(verbatim: "AriaPLT")
                        .fontWeight(.bold)
                        .foregroundStyle(Color.liteText)
                    Text(verbatim: "Mobile")
                        .fontWeight(.regular)
                        .foregroundStyle(Color.liteText.opacity(0.45))
                }
                .font(.system(size: scaled))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "AriaPLT Mobile"))
    }
}

#Preview {
    VStack(spacing: 40) {
        AriaWordmark()
        AriaWordmark(size: 40, stacked: true)
    }
}
