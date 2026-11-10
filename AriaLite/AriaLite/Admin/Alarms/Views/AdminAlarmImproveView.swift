//
//  AdminAlarmImproveView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Improve with AI" in un foglio: un Form di sistema con le richieste possibili, l'errore (con i valori di
//  `action` validi, se il server li dice) e la proposta da applicare o scartare. La logica sta nel view model.
//

import SwiftUI

struct AdminAlarmImproveView: View {
    @State private var viewModel: AdminAlarmImproveViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: AdminAlarmImproveViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Alarm") {
                        Text(verbatim: viewModel.alarm.code).font(.body.monospaced())
                    }
                }
                AdminAlarmImproveActions(viewModel: viewModel)
                if let failure = viewModel.failure { failureSection(failure) }
                if let proposal = viewModel.proposal {
                    AdminAlarmProposalSections(viewModel: viewModel, proposal: proposal)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .animation(.default, value: viewModel.proposal?.changes.map(\.field))
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

    private func failureSection(_ failure: AdminAlarmAssistFailure) -> some View {
        Section {
            Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
            ForEach(failure.validActions, id: \.self) { action in
                Button { viewModel.retry(with: action) } label: {
                    HStack {
                        Text(verbatim: action)
                        Spacer()
                        if viewModel.runningAction == action { ProgressView() }
                    }
                }
                .disabled(viewModel.isRunning)
            }
        } header: {
            if !failure.validActions.isEmpty { Text("Valid actions") }
        }
    }
}
