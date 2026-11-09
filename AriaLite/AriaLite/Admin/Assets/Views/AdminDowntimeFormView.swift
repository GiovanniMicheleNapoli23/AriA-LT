//
//  AdminDowntimeFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio per registrare o modificare un fermo macchina: inizio, fine (o "ancora fermo"),
//  motivo e ordine di lavoro collegato. "Save" sta sempre in alto.
//

import SwiftUI

struct AdminDowntimeFormView: View {
    @State private var viewModel: AdminDowntimeFormViewModel
    let onSaved: (AdminDowntime) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var reasonFocused: Bool

    init(viewModel: AdminDowntimeFormViewModel, onSaved: @escaping (AdminDowntime) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Started", selection: $viewModel.startedAt, in: ...Date.now)
                    Toggle("Still down", isOn: $viewModel.isOngoing.animation(.snappy))
                    if !viewModel.isOngoing {
                        DatePicker("Ended", selection: $viewModel.endedAt, in: viewModel.startedAt...)
                    }
                } footer: {
                    if let message = viewModel.validationMessage { Text(message) }
                }
                Section("Reason") {
                    TextField("What happened?", text: $viewModel.reason, axis: .vertical)
                        .lineLimit(2...6)
                        .focused($reasonFocused)
                }
                if !viewModel.workOrderOptions.isEmpty {
                    Section("Work order") {
                        Picker("Linked work order", selection: $viewModel.workOrderId) {
                            Text("None").tag(String?.none)
                            ForEach(viewModel.workOrderOptions) { Text($0.title).tag(Optional($0.id)) }
                        }
                    }
                }
                if let message = viewModel.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .tint(Color.liteAccent)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        if viewModel.isSaving { ProgressView() } else { Text("Save").fontWeight(.semibold) }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    private func save() {
        reasonFocused = false
        Task {
            if let saved = await viewModel.save() {
                onSaved(saved)
                dismiss()
            }
        }
    }
}
