//
//  AdminMarketplaceItemHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  L'intestazione della pagina: glifo, nome, badge (Nuovo, Acquistato), riga di contesto, sommario e connettori richiesti come chip che vanno a capo.
//

import SwiftUI

struct AdminMarketplaceItemHeader: View {
    let viewModel: AdminMarketplaceItemDetailViewModel

    @ScaledMetric(relativeTo: .title2) private var glyphSide: CGFloat = 64

    var body: some View {
        let item = viewModel.item
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                AdminMarketplaceGlyph(item: item, side: glyphSide)
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: item.name)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    if item.isNew || viewModel.isPurchased {
                        AdminMarketplaceSectionFlow(spacing: 6) {
                            if item.isNew { AdminMarketplaceCapsule("New") }
                            if viewModel.isPurchased { AdminMarketplaceCapsule("Purchased", systemImage: "checkmark") }
                        }
                    }
                    Text(verbatim: viewModel.metaLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            if !item.summary.isEmpty {
                Text(verbatim: item.summary)
                    .font(.body)
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            let requirements = viewModel.requirements
            if !requirements.isEmpty {
                AdminMarketplaceSectionFlow(spacing: 6) {
                    ForEach(requirements) { AdminMarketplaceCapsule(verbatim: $0.name, systemImage: "cable.connector") }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
