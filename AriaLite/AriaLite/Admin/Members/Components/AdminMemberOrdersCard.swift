//
//  AdminMemberOrdersCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Gli ordini aperti assegnati alla persona, per chi ha la sezione Work Orders. Si apre un ordine per vedere i
//  risultati dei suoi passi (la destinazione la registra la scheda).
//

import SwiftUI

struct AdminMemberOrdersCard: View {
    let viewModel: AdminMemberDetailViewModel

    var body: some View {
        AdminCard(title: "Open work orders", systemImage: "wrench.and.screwdriver") {
            if let message = viewModel.ordersError, viewModel.orders.isEmpty {
                AdminSectionNotice(text: message, isError: true)
            } else if !viewModel.hasLoadedOrders {
                ProgressView().frame(maxWidth: .infinity)
            } else if viewModel.orders.isEmpty {
                AdminSectionNotice(text: String(localized: "No open work orders assigned."),
                                   systemImage: "checkmark.circle")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.orders) { order in
                        // Collegamento con la destinazione, non con un valore: la scheda vive in pile con un percorso
                        // tipizzato (Members, Roles & Rights) che non accetterebbe un ordine come valore.
                        NavigationLink {
                            AdminMobileUserStepReportsView(viewModel: viewModel.makeStepReportsViewModel(for: order))
                        } label: {
                            AdminMobileUserWorkOrderRow(order: order)
                        }
                        .buttonStyle(.plain)
                        if order != viewModel.orders.last { Divider() }
                    }
                }
            }
        }
    }
}
