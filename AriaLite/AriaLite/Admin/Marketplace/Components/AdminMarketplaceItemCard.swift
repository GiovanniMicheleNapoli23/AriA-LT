//
//  AdminMarketplaceItemCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La scheda di un elemento del catalogo nella griglia: icona, un badge (in arrivo, stato del connettore,
//  acquistato, prezzo o incluso), nome, "tipo · descrittore", riassunto e la scala. Riceve valori semplici:
//  lo stato lo decide il view model.
//

import SwiftUI

struct AdminMarketplaceItemCard: View {
    let item: AdminMarketplaceItem
    let ownership: AdminMarketplaceOwnership
    /// Lo stato grezzo della riga del server, solo per un connettore che il server conosce.
    var serverStatus: String?

    private var kindLine: String {
        [item.kind.label, item.descriptor].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                AdminMarketplaceGlyph(item: item)
                Spacer(minLength: 8)
                badge
            }
            Text(item.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            HStack(spacing: 6) {
                Text(kindLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if item.isNew { newBadge }
            }
            if !item.summary.isEmpty {
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            Text(item.scale)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    // MARK: Badge

    /// Uno solo, per priorità: in arrivo, stato del server, acquistato, prezzo, incluso.
    @ViewBuilder
    private var badge: some View {
        if item.isPreview {
            pill(String(localized: "Coming soon"), systemImage: nil, tint: .blue)
        } else if item.kind == .connector, let serverStatus {
            AdminConnectorStatusBadge(status: serverStatus)
        } else if ownership == .purchased {
            pill(String(localized: "Purchased"), systemImage: "checkmark.seal.fill", tint: .green)
        } else if let price = item.priceText {
            pill(price, systemImage: nil, tint: Color.liteAccent)
        } else if ownership == .included {
            pill(String(localized: "Included"), systemImage: nil, tint: .secondary)
        }
    }

    private var newBadge: some View {
        Text("New")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.liteAccent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.liteAccent.opacity(0.14), in: Capsule())
            .fixedSize()
    }

    private func pill(_ text: String, systemImage: String?, tint: Color) -> some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tint.opacity(0.14), in: Capsule())
    }
}
