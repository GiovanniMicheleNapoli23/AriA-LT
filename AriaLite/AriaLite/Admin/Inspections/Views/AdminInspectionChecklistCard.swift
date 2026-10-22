//
//  AdminInspectionChecklistCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La checklist dell'ispezione, da compilare sul posto: ogni controllo si spunta e si annota subito.
//  Lo stato di scrittura (item in corso, rollback) è del view model.
//

import SwiftUI

struct AdminInspectionChecklistCard: View {
    let viewModel: AdminInspectionDetailViewModel

    var body: some View {
        AdminCard(title: "Checklist", systemImage: "checklist") {
            if viewModel.inspection.items.isEmpty {
                AdminSectionNotice(text: String(localized: "This inspection has no checks yet. Use Edit to add some."),
                                   systemImage: "checklist")
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.inspection.items) { item in
                        AdminInspectionItemRow(item: item, canEdit: viewModel.canEdit,
                                               isPending: viewModel.pendingItemIds.contains(item.id)) {
                            Task { await viewModel.toggle(item) }
                        } onNote: { text in
                            Task { await viewModel.setNote(text, for: item) }
                        }
                        if item.id != viewModel.inspection.items.last?.id { Divider() }
                    }
                }
            }
        }
    }
}
