//
//  AdminAlarmImproveView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Improve with AI" in un foglio: un Form di sistema che in cima dice su quale allarme si lavora e come
//  funziona, l'errore (con i valori di `action` validi, se il server li dice), poi o le richieste possibili
//  (AdminAlarmImproveActions) o, quando arriva, la proposta da applicare o scartare (scartandola si torna
//  alle richieste). Come il foglio di un piano di manutenzione. La logica sta nel view model.
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
            ScrollViewReader { proxy in
                form
                    // La proposta prende il posto delle richieste e l'errore sta in cima: si riparte dall'alto.
                    .onChange(of: viewModel.proposal == nil) { proxy.scrollTo(Self.introID, anchor: .top) }
                    .onChange(of: viewModel.failure?.message) { _, message in
                        if message != nil { proxy.scrollTo(Self.introID, anchor: .top) }
                    }
            }
        }
        .presentationDragIndicator(.visible)
        .onDisappear { viewModel.cancel() }
    }

    private static let introID = "intro"

    private var form: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: viewModel.alarm.code)
                        .font(.subheadline.weight(.bold).monospaced())
                        .foregroundStyle(Color.liteAccent)
                    if !viewModel.alarm.description.isEmpty {
                        Text(verbatim: viewModel.alarm.description)
                            .font(.headline)
                            .lineLimit(3)
                    }
                    Text(introText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                .padding(.vertical, 2)
                .id(Self.introID)
            }
            if let failure = viewModel.failure { failureSection(failure) }
            if let proposal = viewModel.proposal {
                AdminAlarmProposalSections(viewModel: viewModel, proposal: proposal)
            } else {
                AdminAlarmImproveActions(viewModel: viewModel)
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .liteBackground()
        .animation(.default, value: viewModel.proposal)
        .animation(.default, value: viewModel.failure?.message)
        .ariaTopToast("Applied to the alarm", systemImage: "checkmark.circle.fill", isPresented: viewModel.showsApplied)
        .navigationTitle("Improve with AI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var introText: LocalizedStringKey {
        viewModel.proposal == nil
            ? "Choose what the assistant should do with this alarm. Nothing changes until you apply its proposal."
            : "Here is the proposal: keep the fields you want and tap Apply."
    }

    private func failureSection(_ failure: AdminAlarmAssistFailure) -> some View {
        Section {
            Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(Color.liteWarning)
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
