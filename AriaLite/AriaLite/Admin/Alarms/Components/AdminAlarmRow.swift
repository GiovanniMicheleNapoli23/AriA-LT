//
//  AdminAlarmRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Scheda di un allarme nella lista, come l'intestazione del dettaglio: la descrizione come titolo e, su una
//  riga sotto, lo stato con codice, asset e zona. In selezione mostra un cerchio da spuntare.
//

import SwiftUI

struct AdminAlarmRow: View {
    let alarm: AdminAlarm
    /// `nil` fuori dalla selezione; altrimenti se la riga è scelta.
    var isSelected: Bool?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Testo molto grande: le righe vanno in colonna invece di spezzarsi a metà parola.
        let isAX = dynamicTypeSize.isAccessibilitySize
        let line = isAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        HStack(alignment: .top, spacing: 12) {
            if let isSelected {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.liteAccent : .secondary)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 8) {
                title
                line {
                    AdminAlarmStatusBadge(alarm: alarm)
                    Text(verbatim: alarm.rowSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(isAX ? nil : 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityAddTraits(isSelected == true ? .isSelected : [])
    }

    @ViewBuilder
    private var title: some View {
        if alarm.description.isEmpty {
            Text("No description")
                .font(.headline)
                .foregroundStyle(.secondary)
        } else {
            Text(verbatim: alarm.description)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
        }
    }
}
