//
//  AdminReportFailingAssetRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga di "asset con più guasti": posizione in classifica, nome e tag, numero di guasti.
//

import SwiftUI

struct AdminReportFailingAssetRow: View {
    let asset: AdminReportFailingAsset
    let rank: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.title)
                    .font(.headline)
                    .lineLimit(2)
                if let subtitle = asset.subtitle {
                    Text(subtitle)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let count = asset.count {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(AdminReportFormat.count(count))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                    Text("failures")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
