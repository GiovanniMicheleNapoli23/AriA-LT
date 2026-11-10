//
//  AdminAlarmConfidenceMeter.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Una fiducia (dell'estrazione o della diagnosi) come barra con la percentuale accanto al titolo.
//

import SwiftUI

struct AdminAlarmConfidenceMeter: View {
    let title: LocalizedStringKey
    /// 0…1.
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: "gauge.with.dots.needle.50percent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.weight(.bold).monospacedDigit())
            }
            ProgressView(value: fraction)
                .tint(Color.liteAccent)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}
