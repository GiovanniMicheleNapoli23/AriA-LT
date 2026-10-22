//
//  AdminAssetHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: icona del tipo, tag, nome, stato e dove si trova.
//

import SwiftUI

struct AdminAssetHeader: View {
    let asset: AdminAsset
    /// Tipo, zona e stabilimento in una riga.
    let place: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AdminAssetTypeIcon(assetType: asset.assetType, size: 52)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(asset.tag)
                        .font(.subheadline.weight(.bold).monospaced())
                        .foregroundStyle(Color.liteAccent)
                        .textSelection(.enabled)
                    if let status = asset.status { AdminAssetStatusBadge(status: status) }
                }
                Text(asset.name)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if !place.isEmpty {
                    Text(place)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
