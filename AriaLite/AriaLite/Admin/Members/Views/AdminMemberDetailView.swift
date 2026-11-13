//
//  AdminMemberDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di una persona: testata, avvisi, "In azienda", "Accesso all'app" (solo owner e admin) e "Lavoro"
//  (team, carico, specialità, turni, ordini aperti). Le conferme sono dialoghi; la persona che sparisce (rimossa
//  o non più nell'azienda) fa tornare all'elenco. Ogni decisione è nel view model.
//

import SwiftUI

struct AdminMemberDetailView: View {
    @State private var viewModel: AdminMemberDetailViewModel

    @Environment(\.dismiss) private var dismiss

    init(userId: String, owner: AdminMembersViewModel) {
        _viewModel = State(initialValue: AdminMemberDetailViewModel(userId: userId, owner: owner))
    }

    init(member: AdminMember, owner: AdminMembersViewModel) {
        self.init(userId: member.id, owner: owner)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        Group {
            if let member = viewModel.member {
                content(member)
            } else if let failure = viewModel.failure {
                AdminMemberFailureNote(failure: failure).padding(20)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .liteBackground()
        .navigationTitle(Text(verbatim: viewModel.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.canAssignShifts {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Assign shift", systemImage: "calendar.badge.plus") { viewModel.startAssigning() }
                }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(item: $viewModel.assignForm) { form in
            AdminMemberAssignShiftView(viewModel: form)
        }
        .sheet(item: $viewModel.profileForm) { form in
            AdminMemberProfileFormView(viewModel: form)
        }
        .alert(viewModel.pendingConfirmation?.title ?? "", isPresented: $viewModel.showsConfirmation,
               presenting: viewModel.pendingConfirmation) { confirmation in
            Button(confirmation.actionTitle, role: .destructive) { Task { await viewModel.confirm(confirmation) } }
            Button("Cancel", role: .cancel) {}
        } message: { confirmation in
            Text(verbatim: confirmation.message)
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
        .alert("Couldn't complete this", isPresented: $viewModel.isShowingActionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: viewModel.actionError ?? "")
        }
        // La persona non c'è più (rimossa da qui o da un altro): si torna all'elenco.
        .onChange(of: viewModel.isGone) { _, gone in
            if gone { dismiss() }
        }
    }

    private func content(_ member: AdminMember) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminMemberHeader(member: member, roleLine: viewModel.roleLine,
                                  roleLineIsMuted: viewModel.roleLineIsMuted, badge: viewModel.badge)
                ForEach(Array(viewModel.noticeLines.enumerated()), id: \.offset) { _, line in
                    AdminMemberNoticeNote(text: line)
                }
                if let failure = viewModel.failure { AdminMemberFailureNote(failure: failure) }
                AdminMemberCompanyCard(viewModel: viewModel)
                if viewModel.appState != nil { AdminMemberAppAccessCard(viewModel: viewModel) }
                if viewModel.showsDevices { AdminMemberDevicesList(viewModel: viewModel) }
                AdminMemberTeamsCard(member: member)
                AdminMemberWorkloadCard(workload: viewModel.workload)
                if !member.specialties.isEmpty || viewModel.canStartEditingProfile {
                    AdminMemberSpecialtiesCard(specialties: member.specialties,
                                               onEdit: viewModel.canStartEditingProfile
                                                   ? { viewModel.startEditingProfile() } : nil)
                }
                AdminMemberShiftsCard(viewModel: viewModel)
                if viewModel.canSeeOrders { AdminMemberOrdersCard(viewModel: viewModel) }
            }
            .ariaReadableWidth()
            .padding(20)
        }
    }
}
