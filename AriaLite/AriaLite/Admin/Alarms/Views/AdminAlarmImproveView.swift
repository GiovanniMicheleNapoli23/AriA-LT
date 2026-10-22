//
//  AdminAlarmImproveView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Improve with AI" in un foglio: le richieste possibili, il caricamento, l'errore (con i valori di
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Working on").font(.caption).foregroundStyle(.secondary)
                        Text(verbatim: viewModel.alarm.code).font(.headline.monospaced())
                    }
                    AdminAlarmImproveActions(viewModel: viewModel)
                    if viewModel.isRunning {
                        ProgressView("Asking the assistant…").frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    if let failure = viewModel.failure { failureCard(failure) }
                    if let proposal = viewModel.proposal {
                        AdminAlarmProposalCard(viewModel: viewModel, proposal: proposal)
                    }
                }
                .padding(20)
                .ariaReadableWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
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

    private func failureCard(_ failure: AdminAlarmAssistFailure) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(failure.message, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.orange)
            if !failure.validActions.isEmpty {
                Text("Valid actions").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(failure.validActions, id: \.self) { action in
                    Button(action) { viewModel.retry(with: action) }
                        .font(.footnote.weight(.semibold))
                        .disabled(viewModel.isRunning)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
