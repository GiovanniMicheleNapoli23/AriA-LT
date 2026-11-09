//
//  AdminAssetRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di un asset nella lista: tag, nome, tipo e zona, stato a destra.
//

import SwiftUI

struct AdminAssetRow: View {
    let asset: AdminAsset

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Testo enorme: l'icona ruberebbe spazio al nome.
            if !dynamicTypeSize.isAccessibilitySize {
                AdminAssetTypeIcon(assetType: asset.assetType)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(asset.tag)
                    .font(.subheadline.weight(.bold).monospaced())
                    .foregroundStyle(Color.liteAccent)
                Text(asset.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                if !asset.summaryLine.isEmpty {
                    Text(asset.summaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                }
            }
            Spacer(minLength: 8)
            if let status = asset.status { AdminAssetStatusBadge(status: status) }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
