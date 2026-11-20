//
//  AdminAssetListRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Una riga della lista asset: apre il dettaglio, oppure (durante la selezione delle bozze) sceglie la riga.
//  Legge la selezione qui e non nella lista, così scegliere una riga non ricostruisce tutta la lista.
//

import SwiftUI

struct AdminAssetListRow: View {
    let viewModel: AdminAssetsViewModel
    let asset: AdminAsset

    var body: some View {
        if viewModel.isSelecting {
            Button { viewModel.toggle(asset) } label: {
                AdminAssetRow(asset: asset, isSelected: viewModel.selection.contains(asset.id))
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: asset) {
                AdminAssetRow(asset: asset)
            }
            .buttonStyle(.plain)
        }
    }
}
