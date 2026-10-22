//
//  AdminReportKPITile.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un riquadro della panoramica: icona, numero grande e nome. Il numero diventa rosso quando segnala un
//  problema (ordini in ritardo).
//

import SwiftUI

struct AdminReportKPITile: View {
    let kpi: AdminReportKPI

    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 32

    private var tint: Color { kpi.isAlert ? .red : .liteAccent }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: kpi.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: iconSize, height: iconSize)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            Text(kpi.value.formatted())
                .font(.title.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(kpi.isAlert ? Color.red : Color.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(kpi.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
