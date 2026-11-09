//
//  AdminMobileUsersFilters.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il filtro per stato sopra la lista: tutti, o uno degli stati che hanno almeno un operatore (con il numero).
//

import SwiftUI

struct AdminMobileUsersFilters: View {
    @Bindable var viewModel: AdminMobileUsersViewModel

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Status", selection: $viewModel.statusFilter) {
                    Text("All").tag(AdminMobileUserStatus?.none)
                    ForEach(viewModel.presentStatuses, id: \.self) { status in
                        Label("\(status.label) (\(viewModel.count(for: status)))", systemImage: status.systemImage)
                            .tag(Optional(status))
                    }
                }
            } label: {
                AdminFilterChip(title: "Status", value: viewModel.statusFilterLabel,
                                isActive: viewModel.statusFilter != nil)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }
}
