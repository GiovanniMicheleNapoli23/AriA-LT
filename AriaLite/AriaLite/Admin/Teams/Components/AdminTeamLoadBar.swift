//
//  AdminTeamLoadBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La barra del carico di una squadra: riempita in proporzione, arancione da 80%, rossa oltre il 100%. Senza dati
//  mostra un trattino.
//

import SwiftUI

struct AdminTeamLoadBar: View {
    let workload: AdminTeamWorkload?

    @ScaledMetric(relativeTo: .caption) private var height = 6

    private var tint: Color {
        guard let workload else { return .secondary }
        if workload.isOverloaded { return .red }
        return workload.loadPercent >= 80 ? .orange : Color.liteAccent
    }

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(.quaternary)
                .frame(height: height)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(tint)
                            .frame(width: proxy.size.width * (workload?.loadFraction ?? 0))
                    }
                }
            Text(verbatim: workload?.loadText ?? "–")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(workload?.isOverloaded == true ? Color.red : Color.secondary)
                .frame(minWidth: 40, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Load"))
        .accessibilityValue(Text(verbatim: workload?.loadText ?? "–"))
    }
}
