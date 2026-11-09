//
//  AdminLLMUsageKPITile.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una cifra del riepilogo (costo, token, chiamate) in una scheda piccola sul vetro dell'app.
//

import SwiftUI

struct AdminLLMUsageKPITile: View {
    let title: LocalizedStringKey
    let value: String
    var caption: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 14))
    }
}
