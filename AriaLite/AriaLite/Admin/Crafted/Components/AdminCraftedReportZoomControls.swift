//
//  AdminCraftedReportZoomControls.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Zoom della pagina del rapporto: meno, la percentuale (tocca per tornare alla larghezza intera) e più.
//

import SwiftUI

struct AdminCraftedReportZoomControls: View {
    let viewModel: AdminCraftedReportReaderViewModel

    var body: some View {
        HStack(spacing: 4) {
            Button { viewModel.zoomOut() } label: {
                Image(systemName: "minus").frame(minWidth: 32, minHeight: 32)
            }
            .disabled(!viewModel.canZoomOut)
            .accessibilityLabel("Zoom out")

            Button { viewModel.resetZoom() } label: {
                Text(viewModel.zoomText)
                    .font(.subheadline.monospacedDigit())
                    .frame(minWidth: 52, minHeight: 32)
            }
            .accessibilityLabel("Fit width")

            Button { viewModel.zoomIn() } label: {
                Image(systemName: "plus").frame(minWidth: 32, minHeight: 32)
            }
            .disabled(!viewModel.canZoomIn)
            .accessibilityLabel("Zoom in")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.liteAccent)
        .padding(.horizontal, 4)
        .ariaGlass(in: Capsule())
    }
}
