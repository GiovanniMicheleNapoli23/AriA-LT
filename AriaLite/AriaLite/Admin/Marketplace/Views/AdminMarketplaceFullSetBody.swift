//
//  AdminMarketplaceFullSetBody.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il corpo della pagina di un full set, come FullSetBody della web: cosa c'è nel set, una scheda per ogni posto dove scrive, i componenti degli altri scaffali e cosa permette ad Aria.
//

import SwiftUI

struct AdminMarketplaceFullSetBody: View {
    let viewModel: AdminMarketplaceItemDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            overviewCard
            ForEach(viewModel.setPlaces) { place in
                placeCard(place)
            }
            componentsCard
            AdminMarketplaceAddsCard(title: viewModel.item.kind.addsTitle, lines: viewModel.item.adds)
        }
    }

    // MARK: Cosa c'è nel set

    private var overviewCard: some View {
        let rows = viewModel.setOverview
        return AdminMarketplaceDetailCard(
            title: Text("What's in the set"), systemImage: "list.bullet.rectangle",
            caption: Text("Everything Aria keeps about this machine, and where each part lands once the set is added.")
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: row.label).font(.subheadline.weight(.semibold))
                        AdminMarketplaceSectionFlow(spacing: 6) {
                            ForEach(row.phrases, id: \.self) { AdminMarketplaceCapsule(verbatim: $0) }
                        }
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if row.id != rows.last?.id { Divider() }
                }
            }
        }
    }

    // MARK: Un posto

    private func placeCard(_ place: AdminMarketplaceSetPlace) -> some View {
        AdminMarketplaceDetailCard(
            title: Text(verbatim: place.title), systemImage: place.systemImage, caption: Text(verbatim: place.blurb)
        ) {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(place.sections) { summary in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(verbatim: summary.title)
                                .textCase(.uppercase)
                            Text(verbatim: "\(summary.count)")
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        AdminMarketplaceSetSectionView(viewModel: viewModel, section: summary.section)
                    }
                }
            }
        }
    }

    // MARK: Componenti

    @ViewBuilder
    private var componentsCard: some View {
        let groups = viewModel.setComponentGroups
        if !groups.isEmpty {
            AdminMarketplaceDetailCard(
                title: Text(verbatim: viewModel.setComponentsTitle), systemImage: "shippingbox",
                caption: Text("Included with the set from the other shelves.")
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Label {
                                Text(verbatim: group.title).textCase(.uppercase)
                            } icon: {
                                Image(systemName: group.kind.systemImage)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            AdminMarketplaceItemLinkList(items: group.items, viewModel: viewModel)
                        }
                    }
                    if viewModel.showsConnectorsFootnote {
                        Text("Connectors are not part of any set — a connection needs your own credentials. The ones this machine talks through are listed under Requires.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
