//
//  AdminMemberProfileFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il foglio per cambiare nome, qualifica e specialità di una persona. "Save" sta sempre in alto; controlli e
//  salvataggio sono nel view model.
//

import SwiftUI

struct AdminMemberProfileFormView: View {
    @State private var viewModel: AdminMemberProfileFormViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    init(viewModel: AdminMemberProfileFormViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let message = viewModel.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    TextField("Full name", text: $viewModel.name)
                        .textContentType(.name)
                        .focused($focused)
                } header: {
                    Text("Name")
                }
                Section {
                    Picker("Qualification", selection: $viewModel.label) {
                        ForEach(viewModel.labelChoices, id: \.value) { choice in
                            Text(verbatim: choice.title).tag(choice.value)
                        }
                    }
                } footer: {
                    Text("The qualification doesn't give any access.")
                }
                specialtiesSection
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle("Edit details")
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
        .interactiveDismissDisabled(viewModel.isSaving || viewModel.hasChanges)
    }

    private var specialtiesSection: some View {
        Section {
            HStack {
                TextField("Add a specialty", text: $viewModel.draft, prompt: Text("e.g. Electrical, HVAC"))
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { viewModel.addDraft() }
                Button("Add", systemImage: "plus.circle.fill") { viewModel.addDraft() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .tint(Color.liteAccent)
                    .disabled(!viewModel.canAdd)
            }
            if viewModel.specialties.isEmpty {
                Text("No specialties yet.").foregroundStyle(.secondary)
            } else {
                AdminMobileUserFlowLayout {
                    ForEach(viewModel.specialties, id: \.self) { specialty in
                        AdminMobileUserSpecialtyChip(title: specialty) { viewModel.remove(specialty) }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Specialties")
        } footer: {
            Text("Separate several with commas.")
        }
    }

    private func save() {
        focused = false
        Task { if await viewModel.save() { dismiss() } }
    }
}
