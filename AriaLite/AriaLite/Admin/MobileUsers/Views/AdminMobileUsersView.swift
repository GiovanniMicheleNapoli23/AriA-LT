//
//  AdminMobileUsersView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Mobile Users, come la pagina /mobile-users della web: posti della licenza, filtro per stato,
//  ricerca, "+" per invitare un operatore nuovo o promuovere un utente esistente, menu contestuale sulle righe.
//  Il dettaglio è in AdminMobileUserDetailView; i dialoghi di conferma e gli errori sono qui sullo stack,
//  così valgono anche col dettaglio aperto.
//

import SwiftUI

struct AdminMobileUsersView: View {
    @Bindable var viewModel: AdminMobileUsersViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let seats = viewModel.seats, let text = viewModel.seatsText {
                        AdminMobileUserSeatsCard(seats: seats, text: text)
                            .padding(.horizontal, 20)
                    }
                    if viewModel.hasLoaded, viewModel.operators.count > 1 {
                        AdminMobileUsersFilters(viewModel: viewModel)
                    }
                    errorPill
                    content
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Mobile Users")
            .navigationDestination(for: String.self) { userId in
                AdminMobileUserDetailView(viewModel: viewModel.makeDetailViewModel(userId: userId))
            }
            .toolbar { toolbar }
            .searchable(text: $viewModel.searchText, prompt: Text("Name, email, specialty"))
            .sheet(item: $viewModel.inviteForm) { form in
                AdminMobileUserInviteView(viewModel: form) { user in
                    Task { await viewModel.didAdd(user) }
                }
            }
            .sheet(item: $viewModel.picker) { picker in
                AdminMobileUserPickerView(viewModel: picker)
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
        .alert(viewModel.pendingConfirmation?.title ?? "", isPresented: $viewModel.showsConfirmation,
               presenting: viewModel.pendingConfirmation) { confirmation in
            Button(confirmation.actionTitle, role: .destructive) { Task { await viewModel.confirm(confirmation) } }
            Button("Cancel", role: .cancel) {}
        } message: { confirmation in
            Text(confirmation.message)
        }
        .alert("Couldn't update the operator", isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .alert("Done", isPresented: $viewModel.showsActionNotice) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionNotice ?? "")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
        ToolbarItem(placement: .topBarTrailing) {
            Menu("Add operator", systemImage: "plus") {
                Button("Invite new operator", systemImage: "envelope.badge") { viewModel.startInviting() }
                Button("Add existing user", systemImage: "person.badge.plus") { viewModel.startPicking() }
            }
            .disabled(viewModel.backend.activeCompanyId == nil)
        }
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if let message = viewModel.errorMessage {
                // L'elenco non è mai arrivato: non si dice "nessun operatore", si dice perché.
                VStack(spacing: 14) {
                    ContentUnavailableView("Can't load the operators", systemImage: "exclamationmark.triangle",
                                           description: Text(message))
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .ariaGlassButtonStyle()
                }
                .padding(.top, 40)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            }
        } else if viewModel.visibleOperators.isEmpty {
            if viewModel.isSearching {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView("No operators", systemImage: "iphone.gen3",
                                       description: Text(
                                           "Invite a field operator or add an existing user to get started."))
                    .padding(.top, 40)
            }
        } else {
            list
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.top, 4)
            ForEach(viewModel.visibleOperators) { user in
                NavigationLink(value: user.id) {
                    AdminMobileUserRow(user: user, workLoad: viewModel.workLoadText(of: user),
                                       isBusy: viewModel.isBusy(user))
                }
                .buttonStyle(.plain)
                .contextMenu { AdminMobileUserActionButtons(user: user, viewModel: viewModel) }
                .padding(.horizontal, 20)
            }
            if let updated = viewModel.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
        }
    }

    /// Elenco già a schermo ma l'ultimo aggiornamento è fallito: una riga sottile con il motivo.
    @ViewBuilder
    private var errorPill: some View {
        if viewModel.hasLoaded, let message = viewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Button("Retry") { Task { await viewModel.load() } }
                    .font(.footnote.weight(.semibold))
                    .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
        }
    }
}
