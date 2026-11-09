//
//  AdminMobileUserDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un operatore: stato, info, specialità (modificabili), telefoni su cui è entrato (si può
//  farli uscire) e ordini di lavoro aperti, in sola lettura, con i passi in una schermata a parte. Sospendi,
//  riattiva, rimanda l'invito e rimuovi stanno nel menu in alto: le conferme le mostra AdminMobileUsersView.
//

import SwiftUI

struct AdminMobileUserDetailView: View {
    @State private var viewModel: AdminMobileUserDetailViewModel

    @Environment(\.dismiss) private var dismiss

    init(viewModel: AdminMobileUserDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if let user = viewModel.user {
                content(user)
            } else {
                ContentUnavailableView("Operator removed", systemImage: "person.slash",
                                       description: Text("This operator no longer has mobile access."))
            }
        }
        .liteBackground()
        .navigationTitle(viewModel.user?.displayName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let user = viewModel.user {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Actions", systemImage: "ellipsis") {
                        AdminMobileUserActionButtons(user: user, viewModel: viewModel.list)
                    }
                    .disabled(viewModel.list.isBusy(user))
                }
            }
        }
        .navigationDestination(for: AdminMobileUserWorkOrder.self) { order in
            AdminMobileUserStepReportsView(viewModel: viewModel.makeStepReportsViewModel(for: order))
        }
        .sheet(item: $viewModel.specialtiesForm) { form in
            AdminMobileUserSpecialtiesView(viewModel: form)
        }
        .alert(viewModel.pendingConfirmation?.title ?? "", isPresented: $viewModel.showsConfirmation,
               presenting: viewModel.pendingConfirmation) { confirmation in
            Button(confirmation.actionTitle, role: .destructive) { Task { await viewModel.confirm(confirmation) } }
            Button("Cancel", role: .cancel) {}
        } message: { confirmation in
            Text(confirmation.message)
        }
        .alert("Couldn't log out", isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        // Rimosso (da qui o dal menu della lista): si torna alla lista.
        .onChange(of: viewModel.user == nil) { _, removed in
            if removed { dismiss() }
        }
    }

    private func content(_ user: AdminMobileUser) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(user)
                AdminCard(title: "Details", systemImage: "person.text.rectangle") {
                    VStack(alignment: .leading, spacing: 0) {
                        let fields = viewModel.infoFields(of: user)
                        ForEach(fields) { field in
                            AdminFieldRow(field: field, showsDivider: field != fields.last)
                        }
                    }
                }
                specialtiesCard(user)
                if user.knownStatus?.hasSessions ?? true { sessionsCard(user) }
                workOrdersCard(user)
            }
            .padding(20)
            .ariaReadableWidth()
        }
    }

    private func header(_ user: AdminMobileUser) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AdminMobileUserStatusBadge(status: user.status)
                if user.knownStatus == .active { AdminMobileUserAvailabilityLabel(availability: user.availability) }
            }
            Text(viewModel.workLoadText(of: user))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Schede

    private func specialtiesCard(_ user: AdminMobileUser) -> some View {
        AdminCard(title: "Specialties", systemImage: "star.circle") {
            if viewModel.list.canEditSpecialties(user) {
                Button("Edit", systemImage: "pencil") { viewModel.startEditingSpecialties(of: user) }
                    .labelStyle(.iconOnly)
                    .tint(Color.liteAccent)
            }
        } content: {
            if user.specialties.isEmpty {
                AdminSectionNotice(text: String(localized: "No specialties set."), systemImage: "star")
            } else {
                AdminMobileUserFlowLayout {
                    ForEach(user.specialties, id: \.self) { AdminMobileUserSpecialtyChip(title: $0) }
                }
            }
        }
    }

    private func sessionsCard(_ user: AdminMobileUser) -> some View {
        AdminCard(title: "Devices", systemImage: "iphone.gen3") {
            if viewModel.sessions.count > 1 {
                Button("Log out all", systemImage: "rectangle.portrait.and.arrow.right") {
                    viewModel.askToLogOutAll(user)
                }
                    .font(.footnote.weight(.semibold))
                    .tint(Color.liteAccent)
                    .disabled(viewModel.isRevoking)
            }
        } content: {
            if let message = viewModel.sessionsError, viewModel.sessions.isEmpty {
                AdminSectionNotice(text: message, isError: true)
            } else if !viewModel.sessionsLoaded {
                ProgressView().frame(maxWidth: .infinity)
            } else if viewModel.sessions.isEmpty {
                AdminSectionNotice(text: String(localized: "Not signed in on any device."), systemImage: "iphone.slash")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.sessions) { session in
                        AdminMobileUserSessionRow(title: viewModel.sessionTitle(session),
                                                  line: viewModel.sessionLine(session)) {
                            viewModel.askToLogOut(session, of: user)
                        }
                        .disabled(viewModel.isRevoking)
                        if session != viewModel.sessions.last { Divider() }
                    }
                }
            }
        }
    }

    private func workOrdersCard(_ user: AdminMobileUser) -> some View {
        AdminCard(title: "Open work orders", systemImage: "wrench.and.screwdriver") {
            if let message = viewModel.workOrdersError, viewModel.workOrders.isEmpty {
                AdminSectionNotice(text: message, isError: true)
            } else if !viewModel.workOrdersLoaded {
                ProgressView().frame(maxWidth: .infinity)
            } else if viewModel.workOrders.isEmpty {
                AdminSectionNotice(text: String(localized: "No open work orders assigned."),
                                   systemImage: "checkmark.circle")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.workOrders) { order in
                        NavigationLink(value: order) { AdminMobileUserWorkOrderRow(order: order) }
                            .buttonStyle(.plain)
                        if order != viewModel.workOrders.last { Divider() }
                    }
                }
            }
        }
    }
}
