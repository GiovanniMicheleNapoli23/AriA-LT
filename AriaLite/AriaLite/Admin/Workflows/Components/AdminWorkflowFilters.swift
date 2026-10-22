//
//  AdminWorkflowFilters.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il filtro di stato sopra la lista dei flussi (chiesto al server): tutti, bozze, archiviati.
//

import SwiftUI

struct AdminWorkflowFilters: View {
    @Bindable var viewModel: AdminWorkflowsViewModel

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Status", selection: $viewModel.statusFilter) {
                    Text("All").tag(AdminWorkflowStatus?.none)
                    ForEach(AdminWorkflowStatus.allCases, id: \.self) {
                        Label($0.label, systemImage: $0.systemImage).tag(Optional($0))
                    }
                }
            } label: {
                AdminFilterChip(title: "Status", value: viewModel.statusFilterLabel,
                                isActive: viewModel.statusFilter != nil)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }
}
