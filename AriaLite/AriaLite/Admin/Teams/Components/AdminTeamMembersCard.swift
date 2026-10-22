//
//  AdminTeamMembersCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda dei membri: elenco con ruolo e specialità, "Add" per aggiungerne, il tasto meno per toglierli (con
//  conferma).
//

import SwiftUI

struct AdminTeamMembersCard: View {
    let viewModel: AdminTeamDetailViewModel

    var body: some View {
        AdminCard(title: "Members", systemImage: "person.2") {
            if viewModel.isRemovingMember { ProgressView().controlSize(.small) }
            Button("Add", systemImage: "plus") { viewModel.startAddingMember() }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
        } content: {
            if viewModel.team.members.isEmpty {
                AdminSectionNotice(text: String(localized: "No members yet."), systemImage: "person.2")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.team.members) { member in
                        HStack(alignment: .top, spacing: 8) {
                            AdminTeamMemberRow(name: viewModel.name(of: member), member: member)
                            if member.membershipId != nil {
                                Button("Remove", systemImage: "minus.circle", role: .destructive) {
                                    viewModel.confirmRemoval(of: member)
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                            }
                        }
                        if member.id != viewModel.team.members.last?.id { Divider() }
                    }
                }
            }
        }
    }
}
