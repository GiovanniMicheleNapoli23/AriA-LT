//
//  AdminLLMUsageView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione LLM Usage, come la pagina /settings/usage della web: periodo in alto, poi riepilogo,
//  listino e sessioni recenti. Ogni parte si carica e si ricarica da sola.
//

import SwiftUI

struct AdminLLMUsageView: View {
    @Bindable var viewModel: AdminLLMUsageViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Period", selection: $viewModel.period) {
                        ForEach(AdminLLMUsagePeriod.allCases) { period in
                            Text(period.label).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    AdminLLMUsageSummarySection(viewModel: viewModel)
                    AdminLLMUsagePricingSection(viewModel: viewModel)
                    AdminLLMUsageSessionsSection(viewModel: viewModel)
                }
                .padding(16)
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.refresh() }
            .task(id: viewModel.loadKey) { await viewModel.loadAll() }
            .liteBackground()
            .navigationTitle("LLM Usage")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
            }
            .confirmationDialog(
                "Stop this session?",
                isPresented: $viewModel.isShowingStopConfirmation,
                titleVisibility: .visible
            ) {
                Button("Stop session", role: .destructive) {
                    Task { await viewModel.confirmStop() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The answer in progress will be interrupted.")
            }
            .alert("Couldn't stop the session", isPresented: $viewModel.isShowingStopFailure) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.stopFailure ?? "")
            }
        }
    }
}
