//
//  AdminMaintenanceImproveActions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Cosa si può chiedere all'AI per un piano, come sezioni di un Form (come "Improve with AI" di un allarme):
//  un solo elenco di azioni (una riga ciascuna, con la rotella su quella in corso; "Improve one step" e
//  "Translate" aprono un menu, coi passi o le lingue, e partono appena si sceglie) e una richiesta libera col
//  pulsante d'invio accanto al campo.
//

import SwiftUI

struct AdminMaintenanceImproveActions: View {
    @Bindable var viewModel: AdminMaintenanceImproveViewModel
    @FocusState private var promptFocused: Bool

    var body: some View {
        Section("What should the assistant do?") {
            ForEach(AdminMaintenanceImproveAction.shortcuts(hasSteps: hasSteps)) { action in
                AdminAIActionRow(title: action.title, subtitle: action.subtitle, systemImage: action.systemImage,
                                 isRunning: viewModel.isRunning(action)) {
                    viewModel.run(action)
                }
                .disabled(viewModel.isRunning)
            }
            if hasSteps {
                stepMenu
                translateMenu
            }
        }
        customSection
    }

    private var hasSteps: Bool { !viewModel.plan.tasks.isEmpty }

    // MARK: Menu

    /// "Improve one step": il menu elenca i passi, sceglierne uno fa partire la richiesta.
    private var stepMenu: some View {
        Menu {
            ForEach(viewModel.plan.tasks.indices, id: \.self) { index in
                Button { viewModel.improveStep(at: index) } label: {
                    Text(verbatim: viewModel.stepLabel(index))
                }
            }
        } label: {
            menuLabel(.improveStep)
        }
        .disabled(viewModel.isRunning)
        .adminAIActionRow()
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
            menuLabel(.translate)
        }
        .disabled(viewModel.isRunning)
        .adminAIActionRow()
    }

    private func menuLabel(_ action: AdminMaintenanceImproveAction) -> some View {
        AdminAIActionLabel(title: action.title, subtitle: action.subtitle, systemImage: action.systemImage,
                           isRunning: viewModel.isRunning(action), isMenu: true)
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
            Text("Or ask in your own words")
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
