//
//  AriaWordmark.swift
//  AriaLite
//
//  Il nome dell'app come logo: "AriaPLT" pieno, "Mobile" più leggero.
//  In riga nella sidebar; impilato al login ("Mobile" sotto, maiuscolo e spaziato).
//

import SwiftUI

struct AriaWordmark: View {
    var size: CGFloat = 30
    /// "Mobile" sotto "AriaPLT" invece che accanto.
    var stacked = false

    var body: some View {
        Group {
            if stacked {
                VStack(spacing: size * 0.12) {
                    Text(verbatim: "AriaPLT")
                        .font(.system(size: size, weight: .bold))
                        .tracking(-size * 0.02)
                        .foregroundStyle(Color.liteText)
                    Text(verbatim: "MOBILE")
                        .font(.system(size: size * 0.32, weight: .semibold))
                        .tracking(size * 0.14)
                        .foregroundStyle(Color.liteText.opacity(0.45))
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: size * 0.22) {
                    Text(verbatim: "AriaPLT")
                        .fontWeight(.bold)
                        .foregroundStyle(Color.liteText)
                    Text(verbatim: "Mobile")
                        .fontWeight(.regular)
                        .foregroundStyle(Color.liteText.opacity(0.45))
                }
                .font(.system(size: size))
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
