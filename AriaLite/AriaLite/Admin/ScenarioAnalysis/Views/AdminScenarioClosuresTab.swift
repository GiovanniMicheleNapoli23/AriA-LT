//
//  AdminScenarioClosuresTab.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda Closures: le procedure chiuse senza riparazione confermata, il numero di avvisi aperti
//  e il filtro per stato. "Show more" chiede più righe al server (fino a 200).
//

import SwiftUI

struct AdminScenarioClosuresTab: View {
    @Bindable var viewModel: AdminScenarioClosuresViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            filters
            if let notice = viewModel.unreadNotice {
                Label(notice, systemImage: "bell.badge")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 20)
            }
            AdminScenarioListState(
                hasLoaded: viewModel.hasLoaded, isLoading: viewModel.isLoading, errorMessage: viewModel.errorMessage,
                isEmpty: viewModel.closures.isEmpty, searchText: "",
                failureTitle: "Can't load closures", emptyTitle: "No closures",
                emptySystemImage: "checkmark.shield",
                emptyDescription: "No procedure was ended without a confirmed fix for this filter.",
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
                    Picker("Status", selection: $viewModel.statusFilter) {
                        Text("All").tag(AdminScenarioClosureStatus?.none)
                        ForEach(AdminScenarioClosureStatus.allCases) { Text($0.label).tag(Optional($0)) }
                    }
                } label: {
                    AdminFilterChip(title: "Status", value: viewModel.statusFilterLabel, isActive: viewModel.statusFilter != nil)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            AdminScenarioSectionHeader(text: viewModel.subtitle)
            if viewModel.visibleClosures.isEmpty {
                if viewModel.isSearching {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    AdminSectionNotice(text: String(localized: "No closures for this plant in the rows loaded so far."))
                        .padding(.vertical, 12)
                }
            }
            ForEach(viewModel.visibleClosures) { closure in
                NavigationLink(value: AdminScenarioRoute.closure(closure.id)) {
                    AdminScenarioClosureRow(closure: closure)
                }
                .buttonStyle(.plain)
            }
            if viewModel.canShowMore {
                Button {
                    viewModel.showMore()
                } label: {
                    Label("Show more", systemImage: "arrow.down.circle")
                }
                .ariaGlassButtonStyle()
                .disabled(viewModel.isLoading)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            }
            AdminScenarioUpdatedFooter(date: viewModel.lastUpdated)
        }
    }
}
