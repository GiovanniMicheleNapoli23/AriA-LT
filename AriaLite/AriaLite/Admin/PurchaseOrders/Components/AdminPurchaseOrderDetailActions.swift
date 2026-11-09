//
//  AdminPurchaseOrderDetailActions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La barra in basso con le azioni dello stato: approva e rifiuta (bozza o in attesa), ricevi (approvato o ordinato). Le azioni che chiedono conferma passano dal view model; durante una chiamata i pulsanti sono spenti.
//

import SwiftUI

struct AdminPurchaseOrderDetailActions: View {
    let viewModel: AdminPurchaseOrderDetailViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))
        VStack(spacing: 8) {
            layout {
                if viewModel.canReject { rejectButton }
                if viewModel.canApprove { approveButton }
                if viewModel.canReceive { receiveButton }
            }
            if let hint = viewModel.approveBlockedHint {
                Text(verbatim: hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .controlSize(.large)
        .ariaReadableWidth()
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var approveButton: some View {
        Button { viewModel.ask(.approve) } label: {
            label("Approve", systemImage: "checkmark.seal", running: viewModel.isRunning(.approve))
        }
        .ariaProminentGlassButtonStyle(tint: .liteAccent, foreground: .liteOnAccent)
        .disabled(!viewModel.canApproveNow)
    }

    private var rejectButton: some View {
        Button(role: .destructive) { viewModel.ask(.reject) } label: {
            label("Reject", systemImage: "xmark.octagon", running: viewModel.isRunning(.reject))
        }
        .ariaGlassButtonStyle()
        .foregroundStyle(.red)
        .disabled(viewModel.isBusy)
    }

    private var receiveButton: some View {
        Button { viewModel.ask(.receive) } label: {
            label("Mark as received", systemImage: "tray.and.arrow.down", running: viewModel.isRunning(.receive))
        }
        .ariaProminentGlassButtonStyle(tint: .liteAccent, foreground: .liteOnAccent)
        .disabled(viewModel.isBusy)
    }

    private func label(_ title: LocalizedStringKey, systemImage: String, running: Bool) -> some View {
        HStack(spacing: 8) {
            if running {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: systemImage)
            }
            Text(title).fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }
}
