//
//  AdminUsageKPITile.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Una tessera delle cifre (contratto 3.4): etichetta, cifra grande con l'unità, le righe sotto e, se c'è, la barra con la
//  tacca dell'avviso. I crediti extra in addebito prendono il tono di avviso.
//

import SwiftUI

struct AdminUsageKPITile: View {
    let kpi: AdminUsageKPI

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: kpi.label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            figure
            if let bar = kpi.bar { barView(bar) }
            line(kpi.sub)
            line(kpi.sub2)
            line(kpi.note)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var figure: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
        return layout {
            Text(verbatim: kpi.value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(kpi.isExtra ? Color.liteWarning : Color.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if !kpi.unit.isEmpty {
                Text(verbatim: kpi.unit)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func barView(_ bar: AdminUsageKPI.Bar) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            AriaCreditsMeter(fill: bar.fraction, tick: bar.tick, tint: bar.isOver ? Color.secondary : Color.liteAccent)
            if let label = bar.tickLabel {
                Text(verbatim: label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func line(_ text: String?) -> some View {
        if let text {
            Text(verbatim: text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// La griglia delle tessere: colonne adattive, una sola con testo molto grande.
struct AdminUsageKPIGrid: View {
    let kpis: [AdminUsageKPI]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 160), spacing: 12)], spacing: 12) {
            ForEach(kpis) { AdminUsageKPITile(kpi: $0) }
        }
    }
}
