//
//  AdminMemberDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un membro (pagina /members della web): intestazione, team, carico, specialità e turni
//  dei prossimi giorni. "Assign shift" apre il modulo; togliere un turno chiede conferma.
//

import SwiftUI

struct AdminMemberDetailView: View {
    @State private var viewModel: AdminMemberDetailViewModel

    init(member: AdminMember, owner: AdminMembersViewModel) {
        _viewModel = State(initialValue: AdminMemberDetailViewModel(member: member, owner: owner))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminMemberHeader(member: viewModel.member)
                if let failure = viewModel.failure { AdminMemberFailureNote(failure: failure) }
                AdminMemberTeamsCard(member: viewModel.member)
                AdminMemberWorkloadCard(workload: viewModel.workload)
                if !viewModel.member.specialties.isEmpty {
                    AdminMemberSpecialtiesCard(specialties: viewModel.member.specialties)
                }
                AdminMemberShiftsCard(viewModel: viewModel)
            }
            .ariaReadableWidth()
            .padding(20)
        }
        .liteBackground()
        .navigationTitle(Text(verbatim: viewModel.member.displayName))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Assign shift", systemImage: "calendar.badge.plus") { viewModel.startAssigning() }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(item: $viewModel.assignForm) { form in
            AdminMemberAssignShiftView(viewModel: form)
        }
        .alert("Remove this shift?", isPresented: $viewModel.isConfirmingRemoval,
               presenting: viewModel.shiftToRemove) { shift in
            Button("Remove shift", role: .destructive) {
                Task { await viewModel.remove(shift) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { shift in
            Text(verbatim: viewModel.removalMessage(for: shift))
        }
        .alert("Couldn't remove the shift", isPresented: $viewModel.isShowingActionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: viewModel.actionError ?? "")
        }
    }
}
