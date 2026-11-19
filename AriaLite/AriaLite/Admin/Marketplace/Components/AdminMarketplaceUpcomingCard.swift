//
//  AdminMarketplaceUpcomingCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  La scheda compatta di un connettore "in arrivo", in fondo allo scaffale: icona piccola, nome e una riga
//  (il descrittore o il riassunto). Niente badge: lo dice già il titolo sopra.
//

import SwiftUI

struct AdminMarketplaceUpcomingCard: View {
    let item: AdminMarketplaceItem

    @ScaledMetric(relativeTo: .subheadline) private var glyphSide: CGFloat = 28

    private var subtitle: String? {
        [item.descriptor, item.summary].compactMap { $0 }.first { !$0.isEmpty }
    }

    var body: some View {
        HStack(spacing: 10) {
            AdminMarketplaceGlyph(item: item, side: glyphSide)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
