//
//  AdminInspectionProgressBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una barra di avanzamento sottile (controlli spuntati su totali) con il conteggio a lato.
//  Verde a lista completa, nel colore dell'app altrimenti.
//

import SwiftUI

struct AdminInspectionProgressBar: View {
    let checked: Int
    let total: Int

    @ScaledMetric(relativeTo: .caption) private var barHeight = 6.0

    private var fraction: Double { total == 0 ? 0 : Double(checked) / Double(total) }
    private var tint: Color { total > 0 && checked == total ? .green : .liteAccent }

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.primary.opacity(0.1))
                .frame(height: barHeight)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule().fill(tint).frame(width: proxy.size.width * fraction)
                    }
                }
                .clipShape(Capsule())
            Text("\(checked)/\(total)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(checked) of \(total) checks done"))
    }
}
