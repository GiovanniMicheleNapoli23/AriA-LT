//
//  AdminCraftedReaderDestination.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La schermata che si apre da una riga: il lettore dell'artifact o del rapporto, col suo VM preso dal
//  VM di Crafted (lo stesso finché la schermata resta aperta).
//

import SwiftUI

struct AdminCraftedReaderDestination: View {
    let item: AdminCraftedItem
    let viewModel: AdminCraftedViewModel

    var body: some View {
        switch item {
        case .artifact(let artifact):
            if let reader = viewModel.artifactReader(for: artifact) {
                AdminCraftedArtifactReaderView(viewModel: reader)
            } else {
                unavailable
            }
        case .report(let review):
            if let reader = viewModel.reportReader(for: review) {
                AdminCraftedReportReaderView(viewModel: reader)
            } else {
                unavailable
            }
        }
    }

    private var unavailable: some View {
        ContentUnavailableView("Can't open this", systemImage: "exclamationmark.triangle",
                               description: Text("Choose a company to open this."))
            .liteBackground()
    }
}
