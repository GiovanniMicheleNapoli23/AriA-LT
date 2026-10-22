//
//  AdminScenarioReviewsTab.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda Reviews: il riepilogo delle sessioni concluse, i filtri (da rivedere, verdetto) e le sessioni.
//  "Show more" chiede più righe al server (non c'è paginazione, solo un limite).
//

import SwiftUI

struct AdminScenarioReviewsTab: View {
    @Bindable var viewModel: AdminScenarioReviewsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            filters
            AdminScenarioListState(
                hasLoaded: viewModel.hasLoaded, isLoading: viewModel.isLoading, errorMessage: viewModel.errorMessage,
                isEmpty: viewModel.sessions.isEmpty, searchText: "",
                failureTitle: "Can't load session reviews", emptyTitle: "No concluded sessions",
                emptySystemImage: "checkmark.bubble",
                emptyDescription: "Sessions show up here once they're concluded and Aria has given a verdict.",
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
                    Picker("Review", selection: $viewModel.filter) {
                        ForEach(AdminScenarioReviewFilter.allCases) { Text($0.label).tag($0) }
                    }
                } label: {
                    AdminFilterChip(title: "Review", value: viewModel.filter.label, isActive: viewModel.filter != .all)
                }
                if !viewModel.verdicts.isEmpty {
                    Menu {
                        Picker("Verdict", selection: $viewModel.verdictFilter) {
                            Text("All").tag(String?.none)
                            ForEach(viewModel.verdicts, id: \.self) { Text(AdminScenarioLabel.verdict($0)).tag(Optional($0)) }
                        }
                    } label: {
                        AdminFilterChip(title: "Verdict", value: viewModel.verdictFilterLabel,
                                        isActive: viewModel.verdictFilter != nil)
                    }
                }
                if viewModel.hasLocalFilters {
                    Button("Clear", systemImage: "xmark.circle.fill") {
                        withAnimation(.snappy) { viewModel.clearFilters() }
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Clear filters"))
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
            if viewModel.visibleSessions.isEmpty {
                if viewModel.isSearching {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    AdminSectionNotice(text: String(localized: "No sessions match these filters."))
                        .padding(.vertical, 12)
                }
            }
            ForEach(viewModel.visibleSessions) { review in
                NavigationLink(value: AdminScenarioRoute.review(review.id)) {
                    AdminScenarioReviewRow(review: review)
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
