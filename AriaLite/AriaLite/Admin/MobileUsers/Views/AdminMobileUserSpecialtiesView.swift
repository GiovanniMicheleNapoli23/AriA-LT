//
//  AdminMobileUserSpecialtiesView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio per cambiare le specialità di un operatore: etichette libere da aggiungere e togliere.
//  "Save" sta sempre in alto. Gli errori del salvataggio li mostra la lista (AdminMobileUsersView).
//

import SwiftUI

struct AdminMobileUserSpecialtiesView: View {
    @State private var viewModel: AdminMobileUserSpecialtiesViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    init(viewModel: AdminMobileUserSpecialtiesViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
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
                } footer: {
                    Text("Separate several with commas.")
                }
                Section {
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
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Color.liteAccent)
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        if viewModel.isSaving { ProgressView() } else { Text("Save").fontWeight(.semibold) }
                    }
                    .tint(Color.liteAccent)
                    .disabled(!viewModel.canSave)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    private func save() {
        focused = false
        Task { if await viewModel.save() { dismiss() } }
    }
}
