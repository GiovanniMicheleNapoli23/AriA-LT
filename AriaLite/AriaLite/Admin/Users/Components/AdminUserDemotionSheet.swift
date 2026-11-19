//
//  AdminUserDemotionSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  "Choose {name}'s new role": il foglio con cui un titolare smette di esserlo (§5.2). Parte dal ruolo predefinito
//  attivo, o da "No role", qualunque voce si sia toccata. Per un altro il pulsante è "Continue" (poi la conferma),
//  su se stessi "Step down" e manda subito.
//

import SwiftUI

struct AdminUserDemotionSheet: View {
    let viewModel: AdminUserDetailViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("New role", selection: roleBinding) {
                        ForEach(viewModel.demotionRoles) { role in
                            Text(verbatim: role.title).tag(String?.some(role.id))
                        }
                        Text("No role").tag(String?.none)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Owners hold every section. Choose what \(viewModel.name) keeps.")
                        .textCase(nil)
                }
            }
            .scrollContentBackground(.hidden)
            .liteBackground()
            .navigationTitle(Text("Choose \(viewModel.name)'s new role"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.demotionButtonTitle) { viewModel.continueDemotion() }
                }
            }
            .adminUsersToast(viewModel.owner)
        }
        .presentationDetents([.medium, .large])
    }

    private var roleBinding: Binding<String?> {
        Binding(get: { viewModel.demotionRoleId }, set: { viewModel.demotionRoleId = $0 })
    }
}
