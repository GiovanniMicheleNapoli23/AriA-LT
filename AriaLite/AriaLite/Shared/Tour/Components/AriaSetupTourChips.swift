//
//  AriaSetupTourChips.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I chip sotto il testo di un passo (i formati dei documenti, cosa si estrae, i team) o, all'intro, i nomi delle
//  sezioni: vanno a capo con il Dynamic Type, niente scorrimento orizzontale. Solo decorativi: VoiceOver li legge
//  come un'unica frase.
//

import SwiftUI

struct AriaSetupTourChips: View {
    let titles: [LocalizedStringResource]
    var alignment: Alignment = .leading

    var body: some View {
        AriaFlowLayout(spacing: 6) {
            ForEach(Array(titles.enumerated()), id: \.offset) { _, title in
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.liteText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.liteAccent.opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .accessibilityElement(children: .combine)
    }
}
