//
//  AdminScenarioAnalysisView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Scenario analysis, come la pagina /settings/scenario-analysis della web: tre schede (scenari,
//  revisione delle sessioni, chiusure di procedura), ricerca, trascina per aggiornare e il backfill dal menu "…".
//

import SwiftUI

struct AdminScenarioAnalysisView: View {
    @Bindable var viewModel: AdminScenarioAnalysisViewModel

    @State private var path: [AdminScenarioRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("View", selection: $viewModel.tab) {
                        ForEach(AdminScenarioTab.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    tabContent
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
                .ariaReadableWidth()
            }
            .refreshable { await refresh() }
            .liteBackground()
            .navigationTitle("Scenario analysis")
            .navigationDestination(for: AdminScenarioRoute.self) { destination($0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("More", systemImage: "ellipsis.circle") {
                        Button("Backfill scenarios…", systemImage: "arrow.triangle.2.circlepath") {
                            viewModel.backfill.showsConfirmation = true
                        }
                        .disabled(viewModel.backfill.isRunning)
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: Text(viewModel.searchPrompt))
            .alert("Backfill scenarios?", isPresented: Bindable(viewModel.backfill).showsConfirmation) {
                Button("Assess new sessions") {
                    viewModel.tab = .scenarios
                    viewModel.backfill.start(force: false)
                }
                Button("Re-judge every session", role: .destructive) {
                    viewModel.tab = .scenarios
                    viewModel.backfill.start(force: true)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Aria re-reads concluded sessions and updates the scenarios. Re-judging applies today's rules to every session and can take several minutes. It's safe to repeat: no session is counted twice.")
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.tab {
        case .scenarios:
            AdminScenarioScenariosTab(viewModel: viewModel.scenarios, backfill: viewModel.backfill)
        case .reviews:
            AdminScenarioReviewsTab(viewModel: viewModel.reviews)
        case .closures:
            AdminScenarioClosuresTab(viewModel: viewModel.closures)
        }
    }

    private func refresh() async {
        switch viewModel.tab {
        case .scenarios: await viewModel.scenarios.load()
        case .reviews: await viewModel.reviews.load()
        case .closures: await viewModel.closures.load()
        }
    }

    @ViewBuilder
    private func destination(_ route: AdminScenarioRoute) -> some View {
        switch route {
        case .scenario(let id):
            if let scenario = viewModel.scenarios.scenario(id: id) {
                AdminScenarioDetailView(viewModel: viewModel.scenarios.makeDetailViewModel(for: scenario))
            } else {
                missing
            }
        case .review(let id):
            if let review = viewModel.reviews.session(id: id) {
                AdminScenarioReviewDetailView(viewModel: viewModel.reviews.makeDetailViewModel(for: review))
            } else {
                missing
            }
        case .closure(let id):
            if let closure = viewModel.closures.closure(id: id) {
                AdminScenarioClosureDetailView(viewModel: viewModel.closures.makeDetailViewModel(for: closure))
            } else {
                missing
            }
        }
    }

    private var missing: some View {
        ContentUnavailableView("Not available", systemImage: "questionmark.folder",
                               description: Text("This item is no longer in the list. Pull to refresh and try again."))
            .liteBackground()
    }
}
