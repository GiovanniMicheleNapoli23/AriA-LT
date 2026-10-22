//
//  AdminAssetDowntimeCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I fermi macchina dell'asset: prima quelli in corso, poi gli altri dal più recente.
//  "Log" registra un fermo nuovo; modifica, chiusura ed eliminazione sono su ogni riga.
//

import SwiftUI

struct AdminAssetDowntimeCard: View {
    let viewModel: AdminAssetDetailViewModel
    /// `nil`: fermo nuovo.
    let openForm: (AdminDowntime?) -> Void

    var body: some View {
        AdminCard(title: "Downtime", systemImage: "pause.circle") {
            Button("Log", systemImage: "plus") { openForm(nil) }
                .font(.subheadline.weight(.semibold))
                .tint(Color.liteAccent)
                .disabled(!viewModel.canLogDowntime)
        } content: {
            let rows = viewModel.orderedDowntimes
            if !rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(rows) { downtime in
                        AdminDowntimeRow(downtime: downtime,
                                         workOrderTitle: viewModel.workOrderTitle(for: downtime.workOrderId),
                                         isBusy: viewModel.isBusy(downtime),
                                         onEdit: { openForm(downtime) },
                                         onClose: { Task { await viewModel.close(downtime) } },
                                         onDelete: { viewModel.downtimeToDelete = downtime })
                        if downtime.id != rows.last?.id { Divider().padding(.leading, 34) }
                    }
                }
            } else if let message = viewModel.downtimesError {
                AdminSectionNotice(text: message, isError: true)
            } else if viewModel.hasLoaded {
                AdminSectionNotice(text: String(localized: "No downtime logged for this asset."), systemImage: "checkmark.circle")
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }
}
