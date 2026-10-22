//
//  AdminMemberAssignShiftView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo "Assign shift" in uno sheet: team, giorno, tipo di turno e note. Un Form di sistema.
//  Controlli e salvataggio sono nel view model.
//

import SwiftUI

struct AdminMemberAssignShiftView: View {
    @Bindable var viewModel: AdminMemberAssignShiftViewModel
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
                teamSection
                Section("Shift") {
                    DatePicker("Day", selection: $viewModel.date, in: viewModel.today..., displayedComponents: .date)
                    Picker("Type", selection: $viewModel.shiftType) {
                        ForEach(AdminMemberShiftType.allCases) { type in
                            Text(verbatim: type.localized).tag(type)
                        }
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle("Assign shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Assign") { Task { if await viewModel.save() { dismiss() } } }
                            .disabled(!viewModel.canSave)
                    }
                }
            }
            .disabled(viewModel.isSaving)
            .interactiveDismissDisabled(viewModel.hasChanges)
            .task { await viewModel.loadTeams() }
        }
    }

    private var teamSection: some View {
        Section {
            if viewModel.isLoadingTeams {
                ProgressView()
            } else if let error = viewModel.teamsError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                Button("Retry") { Task { await viewModel.loadTeams() } }
            } else if viewModel.teams.isEmpty {
                Text("No teams yet. Create one on the web first.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Team", selection: $viewModel.teamId) {
                    Text("Choose a team").tag(String?.none)
                    ForEach(viewModel.teams) { team in
                        Text(verbatim: team.isAdHoc ? "\(team.name) (ad hoc)" : team.name).tag(Optional(team.id))
                    }
                }
            }
        } header: {
            Text(verbatim: viewModel.member.displayName)
        }
    }
}
