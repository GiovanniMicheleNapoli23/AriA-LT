//
//  AdminAlarmImproveActions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa si può chiedere all'AI, come sezioni di un Form: le scorciatoie (una riga ciascuna, con la rotella
//  su quella in corso) e una richiesta libera col pulsante d'invio accanto al campo.
//

import SwiftUI

struct AdminAlarmImproveActions: View {
    @Bindable var viewModel: AdminAlarmImproveViewModel
    @FocusState private var promptFocused: Bool

    var body: some View {
        Section("Suggestions") {
            ForEach(AdminAlarmImproveAction.shortcuts) { action in
                shortcutRow(action)
            }
        }
        Section {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("What should the assistant change?", text: $viewModel.customPrompt, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($promptFocused)
                sendButton
            }
        } header: {
            Text(verbatim: AdminAlarmImproveAction.custom.title)
        } footer: {
            Text("The assistant proposes the changes: you choose which ones to apply.")
        }
    }

    private func shortcutRow(_ action: AdminAlarmImproveAction) -> some View {
        Button { viewModel.run(action) } label: {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: action.title).foregroundStyle(.primary)
                        Text(verbatim: action.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
            .accessibilityLabel("Ask")
        }
    }

    private func ask() {
        guard viewModel.canAskCustom else { return }
        promptFocused = false
        viewModel.run(.custom)
    }
}
