//
//  AdminAssetHealthSignalRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Un segnale del punteggio di salute, in forma compatta: nome, valore e, se c'è, il dettaglio.
//

import SwiftUI

struct AdminAssetHealthSignalRow: View {
    let signal: AdminAssetHealthSignal

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: signal.name)
                    .font(.subheadline)
                Spacer(minLength: 8)
                if let value = signal.value {
                    Text(value.formatted(.number.precision(.fractionLength(0...1))))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if let details = signal.details {
                Text(verbatim: details)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
