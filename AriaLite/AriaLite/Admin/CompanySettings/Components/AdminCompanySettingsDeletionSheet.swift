//
//  AdminCompanySettingsDeletionSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo sheet di conferma: spiega cosa sparisce, chiede di riscrivere il nome esatto e mostra l'esito.
//  Il pulsante si abilita e le azioni passano dalla VM.
//

import SwiftUI

struct AdminCompanySettingsDeletionSheet: View {
    @Bindable var viewModel: AdminCompanySettingsViewModel
    let target: AdminCompanySettingsTarget
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(target.explanation)
                        .font(.body)
                    Label("This can't be undone.", systemImage: "exclamationmark.octagon.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type \(target.name) to confirm.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField(target.name, text: $viewModel.typedName)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .disabled(viewModel.isRunning || viewModel.isSucceeded)
                    }
                    statusView
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ariaReadableWidth()
            }
            .liteBackground()
            .navigationTitle(target.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isRunning)
                }
                ToolbarItem(placement: .bottomBar) {
                    actionButton
                }
            }
            .interactiveDismissDisabled(viewModel.isRunning)
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.phase {
        case .confirming:
            EmptyView()
        case .running:
            HStack(spacing: 10) {
                ProgressView()
                Text("Deleting data…")
            }
        case .succeeded:
            Label("Data deleted.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Text(message)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if viewModel.isSucceeded {
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        } else {
            Button(role: .destructive) {
                Task { await viewModel.confirmDeletion() }
            } label: {
                Text(target.title)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!viewModel.canConfirm)
        }
    }
}
