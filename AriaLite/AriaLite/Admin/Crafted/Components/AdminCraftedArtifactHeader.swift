//
//  AdminCraftedArtifactHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  L'intestazione del lettore: il titolo, la richiesta come l'ha scritta l'operatore e lo stato
//  (in creazione, data, serve la chat, non riuscito), con la versione attuale se è stato modificato.
//

import SwiftUI

struct AdminCraftedArtifactHeader: View {
    let viewModel: AdminCraftedArtifactReaderViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.title)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: "“\(viewModel.request)”")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.statusSymbol)
                    Text(viewModel.statusText)
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                if viewModel.currentNumber > 1 {
                    AriaBadge(text: viewModel.currentLabel, tint: Color.liteAccent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
