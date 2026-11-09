//
//  AdminExtractionSelectionBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La barra in basso della selezione multipla: seleziona tutto e "Approve selected" con il conteggio.
//

import SwiftUI

struct AdminExtractionSelectionBar: View {
    let viewModel: AdminExtractionReviewViewModel

    var body: some View {
        HStack(spacing: 12) {
            Button(viewModel.allSelected ? LocalizedStringKey("Deselect all") : LocalizedStringKey("Select all")) {
                viewModel.toggleSelectAll()
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color.liteAccent)
            .disabled(viewModel.selectableItems.isEmpty || viewModel.isBulkApproving)

            Spacer(minLength: 8)

            Button {
                Task { await viewModel.approveSelection() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isBulkApproving {
                        ProgressView().tint(Color.liteOnAccent)
                    } else {
                        Image(systemName: "checkmark")
                        Text("Approve \(viewModel.selection.count)")
                    }
                }
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(minHeight: 46)
            }
            .disabled(!viewModel.canApproveSelection)
            .ariaAccentGlassButtonStyle()
            .buttonBorderShape(.capsule)
            .accessibilityLabel(Text("Approve selected"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .ariaReadableWidth()
    }
}
