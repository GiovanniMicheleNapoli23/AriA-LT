//
//  AdminUserFiltersView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I filtri dell'elenco (§3.3) in uno sheet: Livello, Ruolo, Accesso all'app, Operatore sul campo, Disponibilità,
//  Stato e, per i titolari, Online. Ogni scelta è una pagina con il segno di spunta; si scrive in `viewModel.filters`.
//

import SwiftUI

struct AdminUserFiltersView: View {
    @Bindable var viewModel: AdminUsersViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Level", selection: $viewModel.filters.level) {
                        any(AdminUserFilters.Level.self)
                        ForEach(AdminUserFilters.Level.allCases, id: \.self) { level in
                            Text(verbatim: level.listTitle).tag(Optional(level))
                        }
                    }
                    if !viewModel.roleFilterOptions.isEmpty {
                        Picker("Role", selection: $viewModel.filters.roleId) {
                            any(String.self)
                            ForEach(viewModel.roleFilterOptions, id: \.id) { role in
                                Text(verbatim: role.name).tag(Optional(role.id))
                            }
                        }
                    }
                    flag("App access", $viewModel.filters.appAccess, yes: "users.filter.on", no: "users.filter.off")
                    flag("Field worker", $viewModel.filters.fieldWorker, yes: "Yes", no: "No")
                    Picker("Availability", selection: $viewModel.filters.availability) {
                        any(AdminUserAvailability.self)
                        ForEach(AdminUserAvailability.allCases, id: \.self) { availability in
                            Text(verbatim: availability.listTitle).tag(Optional(availability))
                        }
                    }
                    Picker("Status", selection: $viewModel.filters.status) {
                        any(AdminUserStatus.self)
                        ForEach([AdminUserStatus.active, .invited, .suspended], id: \.self) { status in
                            Text(verbatim: status.listTitle).tag(Optional(status))
                        }
                    }
                    if viewModel.offersOnlineFilter {
                        flag("Online", $viewModel.filters.online, yes: "Online now", no: "Not online")
                    }
                }
                .pickerStyle(.navigationLink)
                Section {
                    Button("Clear filters") { viewModel.clearFilters() }
                        .disabled(!viewModel.hasActiveFilters)
                }
            }
            .scrollContentBackground(.hidden)
            .liteBackground()
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// "Any": nessun filtro.
    private func any<Value: Hashable>(_: Value.Type) -> some View {
        Text("Any").tag(Value?.none)
    }

    /// Un filtro sì/no.
    private func flag(_ title: LocalizedStringKey, _ selection: Binding<Bool?>,
                      yes: LocalizedStringKey, no: LocalizedStringKey) -> some View {
        Picker(title, selection: selection) {
            Text("Any").tag(Bool?.none)
            Text(yes).tag(Bool?.some(true))
            Text(no).tag(Bool?.some(false))
        }
    }
}
