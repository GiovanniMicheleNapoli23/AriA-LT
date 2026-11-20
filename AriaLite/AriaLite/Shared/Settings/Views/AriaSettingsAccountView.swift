//
//  AriaSettingsAccountView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  La pagina dell'account, dalla prima riga delle impostazioni: avatar e nome in cima, poi nome, email, ruolo
//  nell'azienda attiva e tipo di account.
//

import SwiftUI

struct AriaSettingsAccountView: View {
    let viewModel: AriaSettingsViewModel

    @ScaledMetric(relativeTo: .title) private var avatarSide: CGFloat = 76

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    AriaSettingsAvatar(initials: viewModel.initials, side: avatarSide, textStyle: .title)
                    Text(verbatim: viewModel.name)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine)
            }
            Section {
                LabeledContent("Name", value: viewModel.name)
                if let email = viewModel.email {
                    LabeledContent("Email") {
                        Text(verbatim: email).textSelection(.enabled)
                    }
                }
                LabeledContent("Role", value: viewModel.roleLabel)
                LabeledContent("Account type", value: viewModel.accountType)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .ariaReadableWidth()
        .liteBackground()
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
    }
}
