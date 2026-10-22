//
//  AdminAlarmRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Scheda di un allarme nella lista: codice e stato in alto, descrizione, poi asset e zona. In selezione
//  mostra un cerchio da spuntare al posto della freccia.
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
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        HStack(alignment: .top, spacing: 12) {
            if let isSelected {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.liteAccent : .secondary)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 8) {
                line {
                    Text(verbatim: alarm.code)
                        .font(.subheadline.weight(.semibold).monospaced())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if !isAX { Spacer(minLength: 8) }
                    AdminAlarmStatusBadge(alarm: alarm)
                }
                if !alarm.description.isEmpty {
                    Text(verbatim: alarm.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(isAX ? nil : 2)
                }
                line {
                    if let asset = alarm.assetTag {
                        Label(asset, systemImage: "gearshape.2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if !isAX { Spacer(minLength: 8) }
                    if let place = alarm.placeSummary {
                        Text(verbatim: place)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityAddTraits(isSelected == true ? .isSelected : [])
    }
}
