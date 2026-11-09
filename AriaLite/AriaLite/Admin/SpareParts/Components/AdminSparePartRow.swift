//
//  AdminSparePartRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Scheda di un ricambio nella lista: codice e stato in alto, nome, poi quantità contro scorta minima
//  e ubicazione. Sotto scorta la scheda ha un filo rosso.
//

import SwiftUI

struct AdminSparePartRow: View {
    let part: AdminSparePart

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Testo molto grande: le righe vanno in colonna invece di spezzarsi a metà parola.
        let isAX = dynamicTypeSize.isAccessibilitySize
        let line = isAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        VStack(alignment: .leading, spacing: 8) {
            line {
                Text(verbatim: part.code)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !isAX { Spacer(minLength: 8) }
                if let status = part.status { AdminSparePartStatusBadge(status: status) }
            }
            Text(verbatim: part.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(isAX ? nil : 2)
            line {
                AdminSparePartStockLabel(part: part)
                if !isAX { Spacer(minLength: 8) }
                if let location = part.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            if part.isLowStock {
                RoundedRectangle(cornerRadius: 16).strokeBorder(Color.red.opacity(0.35), lineWidth: 1)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
