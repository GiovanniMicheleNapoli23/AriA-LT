//
//  AdminTaskboardFilterBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I filtri della bacheca: squadra, persona assegnata, priorità e, quando uno è acceso, "Clear".
//  Chip in una striscia orizzontale (i filtri possono scorrere); lo stabilimento attivo è nel sottotitolo.
//

import SwiftUI

struct AdminTaskboardFilterBar: View {
    @Bindable var viewModel: AdminTaskboardViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                teamMenu
                memberMenu
                priorityMenu
                if viewModel.filters.isActive {
                    Button("Clear", systemImage: "xmark.circle.fill") { viewModel.clearFilters() }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.borderless)
                        .tint(Color.liteAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private var teamMenu: some View {
        Menu {
            Picker("Team", selection: $viewModel.filters.teamId) {
                Text("All teams").tag(String?.none)
                ForEach(viewModel.teamChoices) { Text($0.name).tag(Optional($0.id)) }
            }
        } label: {
            AdminFilterChip(title: "Team", value: viewModel.teamFilterName ?? String(localized: "All"),
                            isActive: viewModel.filters.teamId != nil)
        }
        .disabled(viewModel.teamChoices.isEmpty && viewModel.filters.teamId == nil)
    }

    private var memberMenu: some View {
        Menu {
            Picker("Assigned to", selection: $viewModel.filters.memberId) {
                Text("Anyone").tag(String?.none)
                ForEach(viewModel.memberChoices) { Text($0.title).tag(Optional($0.id)) }
            }
        } label: {
            AdminFilterChip(title: "Assigned", value: viewModel.memberFilterName ?? String(localized: "Anyone"),
                            isActive: viewModel.filters.memberId != nil)
        }
        .disabled(viewModel.memberChoices.isEmpty && viewModel.filters.memberId == nil)
    }

    private var priorityMenu: some View {
        Menu {
            Picker("Priority", selection: $viewModel.filters.priority) {
                Text("Any priority").tag(AdminWorkOrderPriority?.none)
                ForEach(AdminWorkOrderPriority.known, id: \.self) {
                    Label($0.localized, systemImage: $0.systemImage).tag(Optional($0))
                }
            }
        } label: {
            AdminFilterChip(title: "Priority", value: viewModel.filters.priority?.localized ?? String(localized: "Any"),
                            isActive: viewModel.filters.priority != nil)
        }
    }
}
