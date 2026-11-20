//
//  AdminUsersView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La vista Users della sezione Users (§3; l'altra è Roles): il pannello del tetto per i titolari (o la riga dei posti per gli altri), le persone in una
//  lista raggruppata con ricerca e filtri, e la scheda di una persona a tocco. "Add user" apre il foglio per aggiungere;
//  "Revoke" sugli inviti per email chiede conferma. Si rilegge entrando e tornando in primo piano (se i dati sono
//  vecchi) e tirando per aggiornare; mai a tempo.
//

import SwiftUI

struct AdminUsersView: View {
    @Bindable var viewModel: AdminUsersViewModel
    /// Le viste della sezione (Users e Roles): la scelta in alto, se si aprono entrambe.
    var tabs: AdminUsersSectionViewModel? = nil
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsFilters = false

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            content
                .liteBackground()
                .navigationTitle("Users")
                .toolbar { toolbar }
                .navigationDestination(for: AdminUserRoute.self) { route in
                    AdminUserDetailView(userId: route.userId, owner: viewModel)
                }
                .searchable(text: $viewModel.query, prompt: Text("Search people…"))
                .sheet(item: $viewModel.addForm) { form in
                    AdminUserAddView(viewModel: form)
                }
                .sheet(isPresented: $showsFilters) {
                    AdminUserFiltersView(viewModel: viewModel)
                }
                .alert(revokeTitle, isPresented: $viewModel.isRevokeAlertPresented, presenting: viewModel.invitationToRevoke) { row in
                    Button("Revoke invitation", role: .destructive) { Task { await viewModel.revoke(row) } }
                    Button("Cancel", role: .cancel) {}
                } message: { _ in
                    Text("The link in their email stops working, and the seat is free again.")
                }
                // Il giro guidato si fa da parte mentre il modulo "Add a person" è aperto.
                .ariaSetupTourAside(viewModel.addForm != nil, source: "users.add")
        }
        .adminUsersToast(viewModel)
        .task(id: viewModel.loadKey) { await viewModel.loadIfNeeded() }
        // Tornando in primo piano si rilegge solo se i dati sono vecchi; mai a tempo.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.refreshIfStale() } }
        }
    }

    // MARK: - Contenuto

    @ViewBuilder
    private var content: some View {
        if viewModel.isClosed {
            ContentUnavailableView("You don't have access to Users.", systemImage: "lock")
        } else {
            list
        }
    }

    private var list: some View {
        List {
            if viewModel.showsCapPanel { AdminUsersCapPanel(viewModel: viewModel) }
            if let readout = viewModel.seatsReadout {
                Section {
                    Label(readout, systemImage: "person.2")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let placeholder = viewModel.placeholder {
                Section {
                    AdminUsersPlaceholder(placeholder: placeholder, viewModel: viewModel)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(viewModel.items) { item in rowView(item) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.refresh() }
        .ariaReadableWidth()
    }

    /// Una persona apre la sua scheda; un invito per email no, e si può solo revocare (titolari).
    @ViewBuilder
    private func rowView(_ item: AdminUserListItem) -> some View {
        if item.opens {
            NavigationLink(value: AdminUserRoute(userId: item.id)) {
                AdminUserListRow(item: item)
            }
        } else {
            AdminUserListRow(item: item)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if item.canRevoke { revokeButton(item) }
                }
                .contextMenu {
                    if item.canRevoke { revokeButton(item) }
                }
        }
    }

    private func revokeButton(_ item: AdminUserListItem) -> some View {
        Button("Revoke", systemImage: "xmark.circle", role: .destructive) { viewModel.askToRevoke(item.row) }
    }

    /// "Revoke the invitation to {email}?", con l'email così com'è.
    private var revokeTitle: String {
        viewModel.invitationToRevoke.map { viewModel.revokeTitle(for: $0) } ?? ""
    }

    // MARK: - Barra

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
        if let tabs, tabs.showsTabs {
            ToolbarItem(placement: .principal) { AdminUsersTabPicker(section: tabs) }
        }
        if viewModel.offersFilters {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsFilters = true
                } label: {
                    Label("Filters", systemImage: viewModel.hasActiveFilters
                          ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
        if viewModel.viewer.isOwner {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add user", systemImage: "plus") { viewModel.startAdding() }
                    .disabled(!viewModel.canAdd)
                    .ariaSetupTourAnchor(.invite)
            }
        }
    }
}
