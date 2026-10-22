//
//  AdminAssetWorkOrdersCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli ordini di lavoro dell'asset, aperti e chiusi, in sola lettura.
//

import SwiftUI

struct AdminAssetWorkOrdersCard: View {
    let viewModel: AdminAssetDetailViewModel

    var body: some View {
        AdminCard(title: "Work orders", systemImage: "wrench.and.screwdriver") {
            let orders = viewModel.workOrders
            if !orders.isEmpty {
                VStack(spacing: 0) {
                    ForEach(orders) { order in
                        AdminAssetWorkOrderRow(order: order)
                        if order.id != orders.last?.id { Divider() }
                    }
                }
            } else if let message = viewModel.workOrdersError {
                AdminSectionNotice(text: message, isError: true)
            } else if viewModel.hasLoaded {
                AdminSectionNotice(text: String(localized: "No work orders for this asset."))
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }
}
