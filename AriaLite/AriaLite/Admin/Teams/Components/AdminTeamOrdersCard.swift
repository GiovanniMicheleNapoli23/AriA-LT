//
//  AdminTeamOrdersCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda degli ordini della squadra: quelli aperti per primi, un conteggio, e l'accesso alla bacheca.
//

import SwiftUI

struct AdminTeamOrdersCard: View {
    let viewModel: AdminTeamDetailViewModel

    var body: some View {
        AdminCard(title: "Work orders", systemImage: "wrench.and.screwdriver") {
            if viewModel.hasLoadedOrders {
                Text(viewModel.workOrders.count, format: .number)
                    .font(.footnote.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        } content: {
            if let message = viewModel.ordersMessage {
                AdminSectionNotice(text: message, isError: true)
            } else if !viewModel.hasLoadedOrders {
                ProgressView().frame(maxWidth: .infinity)
            } else if viewModel.workOrders.isEmpty {
                AdminSectionNotice(text: String(localized: "No work orders assigned to this team."),
                                   systemImage: "tray")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.workOrders) { order in
                        AdminTeamWorkOrderRow(order: order)
                        if order.id != viewModel.workOrders.last?.id { Divider() }
                    }
                }
            }
            NavigationLink(value: AdminTeamBoardRoute(teamId: viewModel.team.id)) {
                Label("Open board", systemImage: "rectangle.split.3x1")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}
