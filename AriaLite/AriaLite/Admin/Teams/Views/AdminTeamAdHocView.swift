//
//  AdminTeamAdHocView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo "New ad-hoc team" in uno sheet: nome, tipo di turno, giorni (calendario a selezione multipla)
//  e i membri da mettere nel team, con ricerca. Controlli e salvataggio sono nel view model.
//

import SwiftUI

struct AdminTeamAdHocView: View {
    @Bindable var viewModel: AdminTeamAdHocViewModel
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
                    TextField("Team name", text: $viewModel.name)
                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(1...4)
                } footer: {
                    Text("Name is required.")
                }
                Section("Shift") {
                    Picker("Type", selection: $viewModel.shiftType) {
                        ForEach(AdminMemberShiftType.allCases) { type in
                            Text(verbatim: type.localized).tag(type)
                        }
                    }
                    MultiDatePicker("Days", selection: $viewModel.days, in: viewModel.dayRange)
                }
                membersSection
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle("New ad-hoc team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Create") { Task { if await viewModel.save() { dismiss() } } }
                            .disabled(!viewModel.canSave)
                    }
                }
            }
            .disabled(viewModel.isSaving)
            .interactiveDismissDisabled(viewModel.hasChanges)
        }
        .task { await viewModel.loadPeople() }
    }

    private var membersSection: some View {
        Section {
            TextField("Search members", text: $viewModel.memberQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if viewModel.isLoadingPeople {
                ProgressView().frame(maxWidth: .infinity)
            } else if viewModel.peopleFailed {
                VStack(spacing: 8) {
                    Text("Couldn't load people.")
                        .foregroundStyle(.secondary)
                    Button("Retry") { Task { await viewModel.loadPeople() } }
                }
                .frame(maxWidth: .infinity)
            } else if viewModel.candidates.isEmpty {
                Text("No people to add.").foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.candidates) { person in
                    Button {
                        viewModel.toggle(person)
                    } label: {
                        AdminPersonPickRow(
                            name: person.displayName,
                            detail: person.email.isEmpty || person.displayName == person.email ? nil : person.email,
                            isSelected: viewModel.isSelected(person)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(viewModel.isSelected(person) ? .isSelected : [])
                }
            }
        } header: {
            Text("Members")
        } footer: {
            Text(verbatim: viewModel.selectedCountText)
        }
    }
}
