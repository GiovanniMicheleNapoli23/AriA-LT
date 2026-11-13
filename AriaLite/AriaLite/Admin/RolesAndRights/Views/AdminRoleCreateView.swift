//
//  AdminRoleCreateView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il modulo "Nuovo ruolo" in uno sheet: nome e, per owner e admin, il livello (alto o base).
//

import SwiftUI

struct AdminRoleCreateView: View {
    @Bindable var viewModel: AdminRoleCreateViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Night shift technician", text: $viewModel.name)
                        .submitLabel(.done)
                } header: {
                    Text("Name")
                } footer: {
                    if let error = viewModel.nameError {
                        Text(verbatim: error)
                            .foregroundStyle(.red)
                    }
                }
                if viewModel.asksLevel {
                    Section("Level") {
                        Picker("Level", selection: $viewModel.level) {
                            levelOption("High role", detail: "Site manager, planner, maintenance manager")
                                .tag(AdminRoleSet.high)
                            levelOption("Low role", detail: "Site operator, technician")
                                .tag(AdminRoleSet.low)
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
                if let message = viewModel.errorMessage {
                    Section {
                    } footer: {
                        Text(verbatim: message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle(viewModel.isLow ? Text("New Low role") : Text("New role"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Create") { Task { if await viewModel.submit() { dismiss() } } }
                            .disabled(!viewModel.canSubmit)
                    }
                }
            }
            .disabled(viewModel.isSaving)
        }
        .presentationDetents([.medium, .large])
        .adminRolesToast(viewModel.owner)
    }

    private func levelOption(_ title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
