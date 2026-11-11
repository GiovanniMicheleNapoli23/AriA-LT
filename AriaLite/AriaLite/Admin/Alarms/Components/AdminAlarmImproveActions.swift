//
//  AdminAlarmImproveActions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa si può chiedere all'AI, come sezioni di un Form: in cima l'azione principale ("Improve everything",
//  in evidenza), poi le altre richieste (una parte alla volta e la traduzione, un menu dove scegliere la
//  lingua fa partire la richiesta), infine una richiesta libera col pulsante d'invio accanto al campo. Ogni
//  riga dice cosa riscrive; quella in corso mostra la rotella.
//

import SwiftUI

struct AdminAlarmImproveActions: View {
    @Bindable var viewModel: AdminAlarmImproveViewModel
    @FocusState private var promptFocused: Bool

    var body: some View {
        Section {
            AdminAIPrimaryActionButton(title: AdminAlarmImproveAction.improveAll.title,
                                       systemImage: AdminAlarmImproveAction.improveAll.systemImage,
                                       isRunning: viewModel.isRunning(.improveAll)) {
                viewModel.run(.improveAll)
            }
            .disabled(viewModel.isRunning)
        } footer: {
            Text(verbatim: AdminAlarmImproveAction.improveAll.subtitle)
        }
        Section("Other requests") {
            ForEach(AdminAlarmImproveAction.parts) { action in
                row(action)
            }
            translateMenu
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

    private func row(_ action: AdminAlarmImproveAction) -> some View {
        AdminAIActionRow(title: action.title, subtitle: action.subtitle, systemImage: action.systemImage,
                         isRunning: viewModel.isRunning(action)) {
            viewModel.run(action)
        }
        .disabled(viewModel.isRunning)
    }

    /// "Translate": il menu elenca le lingue, sceglierne una fa partire la richiesta.
    private var translateMenu: some View {
        Menu {
            ForEach(viewModel.translationLanguages, id: \.code) { language in
                Button { viewModel.translate(to: language.code) } label: {
                    Text(verbatim: language.name)
                }
            }
        } label: {
            AdminAIActionLabel(title: AdminAlarmImproveAction.translate.title,
                               subtitle: AdminAlarmImproveAction.translate.subtitle,
                               systemImage: AdminAlarmImproveAction.translate.systemImage,
                               isRunning: viewModel.isRunning(.translate), isMenu: true)
        }
        .adminAIActionRow()
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
