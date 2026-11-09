//
//  AdminMarketplaceItemLinkList.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Righe toccabili (nome e sommario) verso altri elementi del catalogo: i componenti di un set, le skill di un pacchetto. La rotta la gestisce lo stack padre.
//

import SwiftUI

struct AdminMarketplaceItemLinkList: View {
    let items: [AdminMarketplaceItem]
    let viewModel: AdminMarketplaceItemDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                NavigationLink(value: viewModel.route(for: item)) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: item.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(verbatim: item.summary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if item.id != items.last?.id { Divider() }
            }
        }
    }
}
