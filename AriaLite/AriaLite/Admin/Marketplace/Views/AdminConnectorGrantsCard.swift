//
//  AdminConnectorGrantsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Chi ha collegato il proprio account a un connettore personale (owner e admin), con la revoca
//  per membro. La conferma la mostra il dettaglio.
//

import SwiftUI

struct AdminConnectorGrantsCard: View {
    @Bindable var viewModel: AdminConnectorDetailViewModel

    var body: some View {
        AdminCard(title: "Member connections", systemImage: "person.2") {
            if !viewModel.grants.isEmpty {
                Text("\(viewModel.grants.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        } content: {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.grants.isEmpty {
            VStack(spacing: 0) {
                ForEach(viewModel.grants) { grant in
                    AdminConnectorGrantRow(grant: grant, isRevoking: viewModel.revokingIds.contains(grant.id)) {
                        viewModel.grantToRevoke = grant
                    }
                    if grant != viewModel.grants.last { Divider() }
                }
            }
        } else if let message = viewModel.grantsError {
            AdminSectionNotice(text: message, isError: true)
        } else if viewModel.hasLoadedGrants {
            AdminSectionNotice(text: String(localized: "No member has connected an account yet."), systemImage: "person.2")
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }
}
