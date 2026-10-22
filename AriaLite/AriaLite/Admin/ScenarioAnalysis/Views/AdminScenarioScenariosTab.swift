//
//  AdminScenarioScenariosTab.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda Scenarios: lo stato del backfill, le tessere d'insieme, i filtri (tipo, ordine) e gli scenari.
//

import SwiftUI

struct AdminScenarioScenariosTab: View {
    @Bindable var viewModel: AdminScenarioListViewModel
    let backfill: AdminScenarioBackfillViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AdminScenarioBackfillBanner(viewModel: backfill)
                .padding(.horizontal, 20)
            filters
            AdminScenarioListState(
                hasLoaded: viewModel.hasLoaded, isLoading: viewModel.isLoading, errorMessage: viewModel.errorMessage,
                isEmpty: viewModel.visibleScenarios.isEmpty, searchText: viewModel.searchText,
                failureTitle: "Can't load scenarios", emptyTitle: "No scenarios yet",
                emptySystemImage: "point.3.connected.trianglepath.dotted",
                emptyDescription: "Scenarios appear as Aria handles alarms and procedures. Run a backfill to build them from past sessions.",
                retry: { await viewModel.load() }
            ) {
                list
            }
            .padding(.horizontal, 20)
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Picker("Type", selection: $viewModel.kindFilter) {
                        Text("All").tag(AdminScenarioKind?.none)
                        ForEach(AdminScenarioKind.allCases) { Label($0.label, systemImage: $0.systemImage).tag(Optional($0)) }
                    }
                } label: {
                    AdminFilterChip(title: "Type", value: viewModel.kindFilterLabel, isActive: viewModel.kindFilter != nil)
                }
                Menu {
                    Picker("Sort", selection: $viewModel.sort) {
                        ForEach(AdminScenarioSort.allCases) { Text($0.label).tag($0) }
                    }
                } label: {
                    AdminFilterChip(title: "Sort", value: viewModel.sort.label, isActive: viewModel.sort != .mostSessions)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            AdminScenarioStatGrid(stats: viewModel.overview)
                .padding(.bottom, 6)
            AdminScenarioSectionHeader(text: viewModel.subtitle)
            ForEach(viewModel.visibleScenarios) { scenario in
                NavigationLink(value: AdminScenarioRoute.scenario(scenario.id)) {
                    AdminScenarioRow(scenario: scenario)
                }
                .buttonStyle(.plain)
            }
            AdminScenarioUpdatedFooter(date: viewModel.lastUpdated)
        }
    }
}
