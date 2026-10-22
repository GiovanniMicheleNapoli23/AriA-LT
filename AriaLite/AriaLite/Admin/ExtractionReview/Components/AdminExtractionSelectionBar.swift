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
            .disabled(viewModel.selectableItems.isEmpty || viewModel.isBulkApproving)
            .ariaGlassButtonStyle()

            Spacer(minLength: 8)

            Button {
                Task { await viewModel.approveSelection() }
            } label: {
                if viewModel.isBulkApproving {
                    ProgressView()
                } else {
                    Label("Approve \(viewModel.selection.count)", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .disabled(!viewModel.canApproveSelection)
            .ariaProminentGlassButtonStyle(tint: .green)
            .accessibilityLabel(Text("Approve selected"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .ariaReadableWidth()
    }
}
