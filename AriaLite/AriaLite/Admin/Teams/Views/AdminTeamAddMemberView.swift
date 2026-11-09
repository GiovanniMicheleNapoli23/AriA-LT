//
//  AdminTeamAddMemberView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio per aggiungere un membro: ricerca, elenco delle persone che si possono aggiungere (tocco per
//  sceglierne una) e ruolo nella squadra.
//

import SwiftUI

struct AdminTeamAddMemberView: View {
    @Bindable var viewModel: AdminTeamAddMemberViewModel
    @Environment(\.dismiss) private var dismiss

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
                    TextField("Role in the team (optional)", text: $viewModel.role)
                }
                Section("People") {
                    if viewModel.isLoadingPeople {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if viewModel.choices.isEmpty {
                        Text("Nobody left to add.").foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.choices) { person in
                            Button { viewModel.select(person) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(verbatim: person.displayName).font(.body)
                                        if !person.email.isEmpty, person.displayName != person.email {
                                            Text(verbatim: person.email).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer(minLength: 8)
                                    if viewModel.selectedId == person.id {
                                        Image(systemName: "checkmark").foregroundStyle(Color.liteAccent)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(viewModel.selectedId == person.id ? .isSelected : [])
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .searchable(text: $viewModel.search, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Text("Search people"))
            .navigationTitle(Text(verbatim: viewModel.title))
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
            .disabled(viewModel.isSaving)
            .interactiveDismissDisabled(viewModel.hasChanges)
        }
    }
}
