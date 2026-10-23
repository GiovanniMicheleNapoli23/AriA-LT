//
//  AdminMarketplaceTimelineView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La catena di un workflow, 'Come funziona': il trigger e i passi uniti da una linea verticale, così si legge come una sola corsa.
//

import SwiftUI

struct AdminMarketplaceTimelineView: View {
    let rows: [AdminMarketplaceTimelineRow]

    @ScaledMetric(relativeTo: .body) private var marker: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                let isLast = row.id == rows.last?.id
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Image(systemName: row.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liteAccent)
                            .frame(width: marker, height: marker)
                            .background(Color.liteAccent.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: marker * 0.28, style: .continuous))
                            .accessibilityHidden(true)
                        if !isLast {
                            Rectangle()
                                .fill(Color.liteAccent.opacity(0.2))
                                .frame(width: 1)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: row.tag)
                            .font(.caption2.weight(.semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        Text(verbatim: row.title)
                            .font(.subheadline.weight(.semibold))
                        if let detail = row.detail, !detail.isEmpty {
                            Text(verbatim: detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, isLast ? 0 : 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
