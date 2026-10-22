//
//  AdminWorkOrdersView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli ordini di lavoro dell'azienda, come la pagina /work-orders della web: lista, dettaglio, creazione e modifica.
//

import SwiftUI

struct AdminWorkOrdersView: View {
    let viewModel: AdminWorkOrdersViewModel

    var body: some View {
        NavigationStack {
            ContentUnavailableView("Work Orders", systemImage: "wrench.and.screwdriver")
                .liteBackground()
                .navigationTitle("Work Orders")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                }
        }
    }
}
