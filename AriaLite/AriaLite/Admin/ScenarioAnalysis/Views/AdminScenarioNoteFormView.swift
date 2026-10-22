//
//  AdminScenarioNoteFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il form "Add note": una nota dell'admin sulla procedura, che resta nella traccia così com'è.
//

import SwiftUI

struct AdminScenarioNoteFormView: View {
    @Bindable var viewModel: AdminScenarioNoteFormViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(viewModel.title).font(.headline)
                } footer: {
                    Text("Notes are added to the procedure's trail and can't be edited later. To change your mind, add another note.")
                }
                Section("Note") {
                    TextField("Your assessment", text: $viewModel.note, axis: .vertical)
                        .lineLimit(4...12)
                        .focused($isFocused)
                }
                if let message = viewModel.errorMessage {
                    Section { Text(message).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Add note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Add") {
                            Task { if await viewModel.save() { dismiss() } }
                        }
                        .disabled(!viewModel.canSave)
                    }
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving)
            .onAppear { isFocused = true }
        }
    }
}
