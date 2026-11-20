//
//  AdminAssetsApprovalAlerts.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Gli avvisi dell'approvazione in blocco: la conferma e l'errore. Il messaggio della conferma conta le righe
//  scelte, quindi sta in un modificatore a parte: la lista non si rifà a ogni riga scelta.
//

import SwiftUI

struct AdminAssetsApprovalAlerts: ViewModifier {
    @Bindable var viewModel: AdminAssetsViewModel

    func body(content: Content) -> some View {
        content
            .alert(viewModel.approveConfirmationTitle, isPresented: $viewModel.showsApproveConfirmation) {
                Button("Approve") { Task { await viewModel.approveSelected() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(verbatim: viewModel.approveConfirmationMessage)
            }
            .alert("Couldn't approve the assets", isPresented: $viewModel.isShowingApproveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(verbatim: viewModel.approveError ?? "")
            }
    }
}
