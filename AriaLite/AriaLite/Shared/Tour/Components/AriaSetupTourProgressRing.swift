//
//  AriaSetupTourProgressRing.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il simbolo del passo dentro un anello che si riempie con l'avanzamento del giro (intro esclusa).
//

import SwiftUI

struct AriaSetupTourProgressRing: View {
    let symbol: String
    /// Da 0 a 1.
    let fraction: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title2) private var side: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().stroke(Color.liteBorder, lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.liteAccent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .snappy(duration: 0.4), value: fraction)
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.liteAccent)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}
