//
//  AdminMemberCompanyCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il blocco "In azienda" della scheda: ruolo (con il selettore a chi può darli), Lavoro sul campo, qualifica,
//  e i pulsanti per sospendere o rimuovere. Ogni controllo compare solo se il view model dice che il server lo
//  accetta; l'interruttore spento dice perché.
//

import SwiftUI

struct AdminMemberCompanyCard: View {
    let viewModel: AdminMemberDetailViewModel

    var body: some View {
        AdminCard(title: "In the company", systemImage: "building.2") {
            if viewModel.isReadOnly {
                AdminSectionNotice(text: String(localized: "This record has no membership in the company: it can only be viewed."),
                                   systemImage: "eye")
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    roleRow
                    Divider()
                    fieldRow
                    Divider()
                    detailsRow
                    if viewModel.canChangeCompanyStatus || viewModel.canRemove {
                        Divider()
                        actions
                    }
                }
            }
        }
    }

    // MARK: - Ruolo

    private var roleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Role").font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            if let choice = viewModel.roleChoice {
                Menu {
                    ForEach(choice.options) { role in
                        Button {
                            Task { await viewModel.setRole(role.id) }
                        } label: {
                            if viewModel.isCurrentRole(role) {
                                Label(viewModel.roleTitle(role), systemImage: "checkmark")
                            } else {
                                Text(verbatim: viewModel.roleTitle(role))
                            }
                        }
                    }
                    if choice.canUnassign {
                        Divider()
                        Button("No role", systemImage: "xmark.circle") { Task { await viewModel.setRole(nil) } }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(verbatim: viewModel.roleValueText)
                        Image(systemName: "chevron.up.chevron.down").font(.caption)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liteAccent)
                }
                .disabled(viewModel.isWorking)
            } else {
                Text(verbatim: viewModel.roleValueText)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Lavoro sul campo, qualifica

    private var fieldRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Field work", isOn: Binding(
                get: { viewModel.isFieldOn },
                set: { on in Task { await viewModel.setField(on) } }))
                .font(.subheadline)
                .tint(Color.liteAccent)
                .disabled(!viewModel.isFieldToggleEnabled)
            if let reason = viewModel.fieldToggleReason {
                Text(verbatim: reason).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var detailsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Qualification").font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(verbatim: viewModel.qualificationText)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.trailing)
            }
            if viewModel.canEditProfile {
                Button("Edit name, qualification and specialties", systemImage: "pencil") {
                    viewModel.startEditingProfile()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
                .foregroundStyle(Color.liteAccent)
                .disabled(!viewModel.canStartEditingProfile)
            }
            if let hint = viewModel.profileHint {
                Text(verbatim: hint).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Sospendere e rimuovere

    private var actions: some View {
        VStack(spacing: 10) {
            if viewModel.canChangeCompanyStatus {
                if viewModel.isSuspendedInCompany {
                    Button { Task { await viewModel.reactivate() } } label: {
                        Label("Reactivate in the company", systemImage: "play.circle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liteAccent)
                    .foregroundStyle(Color.liteOnAccent)
                } else {
                    Button { viewModel.askToSuspend() } label: {
                        Label("Suspend in the company", systemImage: "pause.circle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.liteAccent)
                }
            }
            if viewModel.canRemove {
                Button(role: .destructive) { viewModel.askToRemove() } label: {
                    Label("Remove from the company", systemImage: "person.badge.minus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.large)
        .disabled(viewModel.isWorking)
    }
}
