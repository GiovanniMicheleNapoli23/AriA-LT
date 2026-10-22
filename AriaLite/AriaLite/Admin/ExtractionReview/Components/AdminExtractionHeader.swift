//
//  AdminExtractionHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio: tipo, codice, titolo, stato e confidenza dell'estrazione.
//

import SwiftUI

struct AdminExtractionHeader: View {
    let item: AdminExtractionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(item.kind.title, systemImage: item.kind.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            if let code = item.code {
                Text(code)
                    .font(.subheadline.weight(.bold).monospaced())
                    .foregroundStyle(Color.liteAccent)
                    .textSelection(.enabled)
            }
            Text(item.title)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            HStack(spacing: 8) {
                if let status = item.status { AdminAssetStatusBadge(status: status) }
                if let confidence = item.confidence { AdminExtractionConfidenceBadge(confidence: confidence) }
                if let updated = item.updatedAt {
                    Text(updated.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
