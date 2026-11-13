//
//  AdminRoleDefaultView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 13/11/26.
//
//  La scelta del ruolo predefinito, come una pagina di Impostazioni: i ruoli base attivi (più quello di ora anche se
//  in pausa) con la spunta sul predefinito. Un tocco lo cambia subito; la pagina resta aperta.
//

import SwiftUI

struct AdminRoleDefaultView: View {
    let viewModel: AdminRolesViewModel

    var body: some View {
        List {
            Section {
                ForEach(viewModel.defaultOptions) { role in
                    Button { viewModel.chooseDefault(role) } label: {
                        HStack(spacing: 8) {
                            Text(verbatim: viewModel.pickerLabel(role))
                                .foregroundStyle(Color.primary)
                            Spacer(minLength: 8)
                            if role.isDefault {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.liteAccent)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .accessibilityAddTraits(role.isDefault ? .isSelected : [])
                }
            } footer: {
                Text(verbatim: viewModel.defaultFooter)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .ariaReadableWidth()
        .disabled(viewModel.isSettingDefault)
        .liteBackground()
        .navigationTitle("Default role")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isSettingDefault {
                ToolbarItem(placement: .topBarTrailing) { ProgressView() }
            }
        }
    }
}
