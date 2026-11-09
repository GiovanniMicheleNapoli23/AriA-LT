//
//  AdminMemberFilterBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I filtri sopra la lista: ruolo, stato e team, in una griglia adattiva (a capo se non ci stanno).
//

import SwiftUI

struct AdminMemberFilterBar: View {
    let viewModel: AdminMembersViewModel

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            if !viewModel.roleOptions.isEmpty {
                AdminMemberFilterMenu(title: String(localized: "Role"), allLabel: String(localized: "All roles"),
                                      options: viewModel.roleOptions, selection: viewModel.roleFilter,
                                      onSelect: { select(viewModel.selectRole, $0) })
            }
            AdminMemberFilterMenu(title: String(localized: "Status"), allLabel: String(localized: "All statuses"),
                                  options: viewModel.statusOptions, selection: viewModel.statusFilter?.rawValue,
                                  onSelect: { select(viewModel.selectStatus, $0) })
            if !viewModel.teamFilterOptions.isEmpty {
                AdminMemberFilterMenu(title: String(localized: "Team"), allLabel: String(localized: "All teams"),
                                      options: viewModel.teamFilterOptions, selection: viewModel.teamFilter,
                                      onSelect: { select(viewModel.selectTeam, $0) })
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }

    private func select(_ action: (String?) -> Void, _ key: String?) {
        withAnimation(.snappy) { action(key) }
    }
}
