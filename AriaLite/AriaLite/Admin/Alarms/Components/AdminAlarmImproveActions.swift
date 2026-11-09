//
//  AdminAlarmImproveActions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa si può chiedere all'AI: le scorciatoie (griglia adattiva) e una richiesta libera.
//

import SwiftUI

struct AdminAlarmImproveActions: View {
    @Bindable var viewModel: AdminAlarmImproveViewModel
    @FocusState private var promptFocused: Bool
    @ScaledMetric(relativeTo: .body) private var minTile: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minTile), spacing: 10)], spacing: 10) {
                ForEach(AdminAlarmImproveAction.shortcuts) { action in
                    Button { viewModel.run(action) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(action.title, systemImage: action.systemImage)
                                .font(.subheadline.weight(.semibold))
                            Text(verbatim: action.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .ariaGlass(in: RoundedRectangle(cornerRadius: 14), interactive: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isRunning)
                }
            }
            AdminCard(title: "Custom request", systemImage: AdminAlarmImproveAction.custom.systemImage) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("What should the assistant change?", text: $viewModel.customPrompt, axis: .vertical)
                        .lineLimit(2...6)
                        .textFieldStyle(.roundedBorder)
                        .focused($promptFocused)
                    Button {
                        promptFocused = false
                        viewModel.run(.custom)
                    } label: {
                        Label("Ask", systemImage: "paperplane")
                    }
                    .ariaGlassButtonStyle()
                    .disabled(!viewModel.canAskCustom)
                }
            }
        }
    }
}
