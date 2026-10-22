//
//  AdminStatTile.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un numero con la sua etichetta (disponibilità, ore di fermo, eventi…).
//

import SwiftUI

struct AdminStatTile: View {
    let title: String
    let value: String
    var systemImage: String?
    var tint: Color = .liteAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage).foregroundStyle(tint)
                }
                Text(title)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .font(.caption.weight(.semibold))
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.liteAccent.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
