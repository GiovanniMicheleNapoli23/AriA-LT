//
//  AdminAlarmFactTile.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Un fatto dell'intestazione del dettaglio: icona in un riquadro, etichetta piccola e valore leggibile.
//

import SwiftUI

struct AdminAlarmFactTile: View {
    let fact: AdminAlarmFact

    @ScaledMetric(relativeTo: .subheadline) private var iconSide: CGFloat = 32

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: fact.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liteAccent)
                .frame(width: iconSide, height: iconSide)
                .background(Color.liteAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: fact.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: fact.value)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
