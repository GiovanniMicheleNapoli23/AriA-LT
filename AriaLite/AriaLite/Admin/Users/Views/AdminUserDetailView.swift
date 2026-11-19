//
//  AdminUserDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda di una persona (contratto Users §4, §5): una lista raggruppata come Impostazioni, non schede. In cima
//  l'intestazione, poi l'accesso (livello, interruttori, specialità, sessioni, email), poi Today, Schedule e
//  History, e in fondo lo stato. Si apre dall'elenco di Users e da Roles & Rights: i sottopagine usano link a
//  destinazione, mai valori. Cosa si vede lo decide solo AdminUsersRules.
//

import SwiftUI

struct AdminUserDetailView: View {
    @State private var viewModel: AdminUserDetailViewModel

    @Environment(\.dismiss) private var dismiss

    init(userId: String, owner: AdminUsersViewModel) {
        _viewModel = State(initialValue: AdminUserDetailViewModel(userId: userId, owner: owner))
    }

    var body: some View {
        content
            .liteBackground()
            .navigationTitle(Text(verbatim: viewModel.name))
            .navigationBarTitleDisplayMode(.inline)
            .adminUsersToast(viewModel.owner)
            .task { await viewModel.load() }
            .onChange(of: viewModel.isGone) { _, gone in
                if gone { dismiss() }
            }
            .alert(Text(verbatim: alertContent?.title ?? ""), isPresented: confirmationBinding,
                   presenting: viewModel.confirmation) { item in
                let content = viewModel.alert(item)
                Button(content.confirmTitle, role: content.isDestructive ? .destructive : nil) {
                    viewModel.confirm(item)
                }
                Button("Cancel", role: .cancel) {}
            } message: { item in
                Text(verbatim: viewModel.alert(item).message)
            }
            .sheet(isPresented: assigningBinding) {
                if let assignment = viewModel.assignment {
                    AdminUserAssignWorkOrderSheet(viewModel: assignment, owner: viewModel.owner)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.row != nil {
            list
        } else if viewModel.cannotOpen {
            // Aperta da Roles & Rights da chi non ha la sezione Members: GET …/users non si può leggere.
            ContentUnavailableView(String(localized: "Your role doesn't allow this."), systemImage: "lock")
        } else if viewModel.owner.loadFailed, !viewModel.owner.hasLoaded {
            Text("Couldn't load the people of this workspace.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        } else {
            // L'elenco non è ancora arrivato, o la persona non c'è più e la scheda si sta chiudendo.
            ProgressView()
        }
    }

    private var list: some View {
        List {
            AdminUserHeaderSection(viewModel: viewModel)
            AdminUserLevelSection(viewModel: viewModel)
            AdminUserSwitchesSection(viewModel: viewModel)
            AdminUserFieldWorkSection(viewModel: viewModel)
            AdminUserSessionsSection(viewModel: viewModel)
            AdminUserResendSection(viewModel: viewModel)
            AdminUserTodaySection(details: viewModel.details, viewModel: viewModel.shifts)
            shiftsSection
            AdminUserStatusSection(viewModel: viewModel)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .ariaReadableWidth()
        .refreshable { await viewModel.load() }
    }

    private var shiftsSection: some View {
        Section {
            if viewModel.showsSchedule {
                NavigationLink {
                    AdminUserScheduleView(viewModel: viewModel.shifts)
                } label: {
                    Label("Schedule", systemImage: "calendar.badge.plus")
                }
            }
            NavigationLink {
                AdminUserHistoryView(viewModel: viewModel.shifts)
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
        }
    }

    // MARK: - Conferme

    private var alertContent: AdminUserAlertContent? {
        viewModel.confirmation.map(viewModel.alert)
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(get: { viewModel.confirmation != nil },
                set: { if !$0 { viewModel.confirmation = nil } })
    }

    private var assigningBinding: Binding<Bool> {
        Binding(get: { viewModel.assignment != nil },
                set: { if !$0 { viewModel.assignment = nil } })
    }
}
