//
//  AriaOnboardingProgressBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  A che pagina si è, come le storie: un segmento per pagina, pieni quelli già visti. VoiceOver legge "Pagina 2 di 7".
//

import SwiftUI

struct AriaOnboardingProgressBar: View {
    let count: Int
    let index: Int
    let label: String

    @ScaledMetric(relativeTo: .caption) private var thickness: CGFloat = 3

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { page in
                Capsule()
                    .fill(Color.liteAccent.opacity(page <= index ? 0.9 : 0.12))
                    .frame(height: thickness)
            }
        }
        .animation(.snappy, value: index)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: label))
    }
}
