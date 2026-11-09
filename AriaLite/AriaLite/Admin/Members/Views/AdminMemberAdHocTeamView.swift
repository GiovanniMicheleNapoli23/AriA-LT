//
//  AdminMemberAdHocTeamView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo "New ad-hoc team" in uno sheet: nome, tipo di turno, giorni (calendario a selezione multipla)
//  e i membri da mettere nel team, con ricerca. Controlli e salvataggio sono nel view model.
//

import SwiftUI

struct AdminMemberAdHocTeamView: View {
    @Bindable var viewModel: AdminMemberAdHocTeamViewModel
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
    }

    private var membersSection: some View {
        Section {
            TextField("Search members", text: $viewModel.memberQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            ForEach(viewModel.candidates) { member in
                Button {
                    viewModel.toggle(member)
                } label: {
                    HStack(spacing: 12) {
                        AdminMemberAvatar(initials: member.initials)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: member.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            if let role = member.roleLabel {
                                Text(verbatim: role).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: viewModel.isSelected(member) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.isSelected(member) ? Color.liteAccent : Color.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(viewModel.isSelected(member) ? .isSelected : [])
            }
        } header: {
            Text("Members")
        } footer: {
            Text(verbatim: viewModel.selectedCountText)
        }
    }
}
