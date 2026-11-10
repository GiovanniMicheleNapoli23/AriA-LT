//
//  AdminMaintenanceImproveView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Improve with AI" di un piano in un foglio, come quello di un allarme: un Form di sistema con il piano, le
//  richieste possibili (AdminMaintenanceImproveActions), l'errore (con i valori di `action` validi, se il
//  server li dice) e la proposta da applicare o scartare. La logica sta in AdminMaintenanceImproveViewModel.
//

import SwiftUI

struct AdminMaintenanceImproveView: View {
    @State private var viewModel: AdminMaintenanceImproveViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: AdminMaintenanceImproveViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Plan") {
                        Text(verbatim: viewModel.plan.name).multilineTextAlignment(.trailing)
                    }
                }
                AdminMaintenanceImproveActions(viewModel: viewModel)
                if let failure = viewModel.failure { failureSection(failure) }
                if let proposal = viewModel.proposal {
                    AdminMaintenanceProposalSections(viewModel: viewModel, proposal: proposal)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .animation(.default, value: viewModel.proposal)
            .animation(.default, value: viewModel.failure?.message)
            .navigationTitle("Improve with AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onDisappear { viewModel.cancel() }
    }

    private func failureSection(_ failure: AdminWorkOrderAssistantFailure) -> some View {
        Section {
            Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
            ForEach(failure.validActions, id: \.self) { action in
                Button { viewModel.retry(with: action) } label: {
                    HStack {
                        Text(verbatim: action)
                        Spacer()
                        if viewModel.isRunning(rawAction: action) { ProgressView() }
                    }
                }
                .disabled(viewModel.isRunning)
            }
        } header: {
            if !failure.validActions.isEmpty { Text("Valid actions") }
        }
    }
}
