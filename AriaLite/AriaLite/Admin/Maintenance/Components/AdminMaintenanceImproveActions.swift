//
//  AdminMaintenanceImproveActions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Cosa si può chiedere all'AI per un piano, come sezioni di un Form (come "Improve with AI" di un allarme):
//  le scorciatoie (una riga ciascuna, con la rotella su quella in corso), un passo da riscrivere e una
//  richiesta libera col pulsante d'invio accanto al campo.
//

import SwiftUI

struct AdminMaintenanceImproveActions: View {
    @Bindable var viewModel: AdminMaintenanceImproveViewModel
    @FocusState private var promptFocused: Bool

    var body: some View {
        Section("Suggestions") {
            ForEach(AdminMaintenanceImproveAction.shortcuts) { action in
                actionRow(action, subtitle: action.subtitle) { viewModel.run(action) }
            }
        }
        if !viewModel.plan.tasks.isEmpty { stepSection }
        customSection
    }

    // MARK: Righe

    private func actionRow(_ action: AdminMaintenanceImproveAction, subtitle: String?,
                           run: @escaping () -> Void) -> some View {
        Button(action: run) {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: action.title).foregroundStyle(.primary)
                        if let subtitle {
                            Text(verbatim: subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: action.systemImage).foregroundStyle(Color.liteAccent)
                }
                Spacer(minLength: 8)
                if viewModel.isRunning(action) { ProgressView() }
            }
            .contentShape(Rectangle())
        }
        .disabled(viewModel.isRunning)
    }

    // MARK: Un passo

    private var stepSection: some View {
        Section {
            Picker("Step", selection: $viewModel.stepIndex) {
                ForEach(viewModel.plan.tasks.indices, id: \.self) { index in
                    Text(verbatim: viewModel.stepLabel(index)).tag(index)
                }
            }
            .pickerStyle(.navigationLink)
            .disabled(viewModel.isRunning)
            actionRow(.improveStep, subtitle: nil) { viewModel.run(.improveStep) }
                .disabled(!viewModel.canImproveStep)
        } header: {
            Text("One step")
        } footer: {
            Text(verbatim: AdminMaintenanceImproveAction.improveStep.subtitle)
        }
    }

    // MARK: Richiesta libera

    private var customSection: some View {
        Section {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("e.g. Add a lockout/tagout step", text: $viewModel.customPrompt, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($promptFocused)
                sendButton
            }
        } header: {
            Text(verbatim: AdminMaintenanceImproveAction.custom.title)
        } footer: {
            Text("The assistant proposes the changes: you choose which ones to apply.")
        }
    }

    @ViewBuilder
    private var sendButton: some View {
        if viewModel.isRunning(.custom) {
            ProgressView()
        } else {
            Button(action: ask) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.canAskCustom ? Color.liteAccent : Color.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(!viewModel.canAskCustom)
            .accessibilityLabel("Send")
        }
    }

    private func ask() {
        guard viewModel.canAskCustom else { return }
        promptFocused = false
        viewModel.run(.custom)
    }
}
