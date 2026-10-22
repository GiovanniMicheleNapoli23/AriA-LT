//
//  AdminAuditLogFilterMenu.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il menu dei filtri dello storico: tipo di oggetto e azione. Ogni scelta ricarica la lista dal server.
//

import SwiftUI

struct AdminAuditLogFilterMenu: View {
    @Bindable var viewModel: AdminAuditLogViewModel

    var body: some View {
        Menu {
            Picker("Type", selection: $viewModel.entityTypeFilter) {
                Text("All types").tag(String?.none)
                ForEach(viewModel.entityTypeOptions, id: \.self) { type in
                    Text(AdminAuditLogText.entityTypeLabel(type)).tag(Optional(type))
                }
            }
            Picker("Action", selection: $viewModel.actionFilter) {
                Text("All actions").tag(String?.none)
                ForEach(viewModel.actionOptions, id: \.self) { action in
                    Text(AdminAuditLogText.actionLabel(action)).tag(Optional(action))
                }
            }
            if viewModel.hasFilters {
                Button("Clear filters", role: .destructive) { viewModel.clearFilters() }
            }
        } label: {
            Label("Filters", systemImage: viewModel.hasFilters
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
    }
}
