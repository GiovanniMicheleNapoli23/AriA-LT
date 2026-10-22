//
//  AdminWorkOrderCompletionSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio "Complete work order": le note di chiusura (obbligatorie) e il pulsante che chiude l'ordine.
//  Se mancano risultati dei passi lo dice e, dal dettaglio, porta alla scheda dei passi.
//

import SwiftUI

struct AdminWorkOrderCompletionSheet: View {
    @Bindable var viewModel: AdminWorkOrderCompletionViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(viewModel.order.title)
                        .font(.subheadline.weight(.semibold))
                } footer: {
                    Text("Every step needs a result before the work order can be completed.")
                }
                Section {
                    TextField("What was done?", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(4...10)
                        .focused($isFocused)
                } header: {
                    Text("Resolution notes")
                } footer: {
                    if viewModel.isTooLong {
                        Text("The notes are too long (2000 characters at most).").foregroundStyle(.red)
                    }
                }
                if let message = viewModel.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                        if viewModel.isMissingSteps, let showSteps = viewModel.showSteps {
                            Button("Go to steps", systemImage: "list.number", action: showSteps)
                        }
                    }
                }
            }
            .navigationTitle("Complete work order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Complete") { Task { await viewModel.submit() } }
                            .disabled(!viewModel.canSubmit)
                    }
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving)
            .onChange(of: viewModel.isDone) { _, done in
                if done { dismiss() }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium, .large])
    }
}
