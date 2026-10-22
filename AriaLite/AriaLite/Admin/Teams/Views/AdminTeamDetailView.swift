//
//  AdminTeamDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di una squadra (pagina /teams/{id} della web): intestazione, carico e distribuzioni, membri,
//  ordini. "Edit" apre il modulo; il cestino chiede conferma, poi elimina e torna all'elenco.
//

import SwiftUI

struct AdminTeamDetailView: View {
    @State private var viewModel: AdminTeamDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(team: AdminTeam, owner: AdminTeamsViewModel) {
        _viewModel = State(initialValue: AdminTeamDetailViewModel(team: team, owner: owner))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminTeamDetailHeader(team: viewModel.team, plantName: viewModel.plantName,
                                      memberCountText: viewModel.memberCountText)
                if let failure = viewModel.failure {
                    AdminTeamFailureNote(message: failure.message, isForbidden: failure.isForbidden)
                }
                AdminTeamWorkloadCard(workload: viewModel.workload, message: viewModel.workloadMessage)
                distributions
                AdminTeamMembersCard(viewModel: viewModel)
                AdminTeamOrdersCard(viewModel: viewModel)
            }
            .ariaReadableWidth()
            .padding(20)
        }
        .liteBackground()
        .navigationTitle(Text(verbatim: viewModel.team.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { viewModel.startEditing() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isDeleting {
                    ProgressView()
                } else {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        viewModel.showsDeleteConfirmation = true
                    }
                }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(item: $viewModel.editForm) { form in
            AdminTeamFormView(viewModel: form)
        }
        .sheet(item: $viewModel.addMemberModel) { model in
            AdminTeamAddMemberView(viewModel: model)
        }
        .confirmationDialog("Delete this team?", isPresented: $viewModel.showsDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { if await viewModel.delete() { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(viewModel.team.title)” will be removed along with its memberships. This can't be undone.")
        }
        .confirmationDialog("Remove this member?", isPresented: removalShown, titleVisibility: .visible,
                            presenting: viewModel.memberPendingRemoval) { member in
            Button("Remove", role: .destructive) { Task { await viewModel.remove(member) } }
            Button("Cancel", role: .cancel) {}
        } message: { member in
            Text(verbatim: viewModel.removalMessage(for: member))
        }
        .alert("Couldn't delete the team", isPresented: $viewModel.isShowingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: viewModel.deleteError ?? "")
        }
        .alert("Couldn't change the members", isPresented: $viewModel.isShowingMemberError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: viewModel.memberError ?? "")
        }
    }

    private var removalShown: Binding<Bool> {
        Binding(get: { viewModel.memberPendingRemoval != nil },
                set: { if !$0 { viewModel.memberPendingRemoval = nil } })
    }

    @ViewBuilder
    private var distributions: some View {
        let status = viewModel.statusRows
        let priority = viewModel.priorityRows
        let category = viewModel.categoryRows
        if !status.isEmpty || !priority.isEmpty || !category.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16, alignment: .top)], spacing: 16) {
                if !status.isEmpty {
                    AdminTeamDistributionCard(title: "By status", systemImage: "chart.bar", rows: status)
                }
                if !priority.isEmpty {
                    AdminTeamDistributionCard(title: "By priority", systemImage: "flag", rows: priority)
                }
                if !category.isEmpty {
                    AdminTeamDistributionCard(title: "By category", systemImage: "square.grid.2x2", rows: category)
                }
            }
        }
    }
}
