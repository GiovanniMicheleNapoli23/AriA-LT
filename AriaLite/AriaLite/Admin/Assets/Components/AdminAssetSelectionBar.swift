//
//  AdminAssetSelectionBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  La barra in basso durante la selezione delle bozze: "Select all" e "Approve" con quante ne sono scelte.
//  Approve chiede conferma (la decide la lista).
//

import SwiftUI

struct AdminAssetSelectionBar: View {
    let viewModel: AdminAssetsViewModel

    var body: some View {
        HStack(spacing: 12) {
            Button(viewModel.allVisibleSelected ? "Deselect all" : "Select all") {
                viewModel.toggleSelectAll()
            }
            .font(.subheadline.weight(.semibold))
            Spacer(minLength: 8)
            if viewModel.isApproving {
                ProgressView()
            } else {
                Button {
                    viewModel.showsApproveConfirmation = true
                } label: {
                    Label("Approve \(viewModel.selectedCount)", systemImage: "checkmark.seal")
                }
                .ariaAccentGlassButtonStyle()
                .disabled(viewModel.selectedCount == 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}
