//
//  AdminMaintenanceImproveView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Improve with AI" in un foglio: le scorciatoie (griglia adattiva), un passo da riscrivere, una richiesta
//  libera; sotto, la proposta con le parti da applicare. La logica sta in AdminMaintenanceImproveViewModel.
//

import SwiftUI

struct AdminMaintenanceImproveView: View {
    @State private var viewModel: AdminMaintenanceImproveViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var promptFocused: Bool
    @ScaledMetric(relativeTo: .body) private var minTile: CGFloat = 150

    init(viewModel: AdminMaintenanceImproveViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    context
                    shortcuts
                    if !viewModel.plan.tasks.isEmpty { stepCard }
                    customCard
                    if viewModel.isRunning {
                        ProgressView("Asking the assistant…").frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    if let failure = viewModel.failure { failureCard(failure) }
                    if let proposal = viewModel.proposal {
                        AdminMaintenanceProposalCard(viewModel: viewModel, proposal: proposal)
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

    // MARK: Sezioni

    private var context: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Working on").font(.caption).foregroundStyle(.secondary)
            Text(viewModel.plan.name).font(.headline).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shortcuts: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minTile), spacing: 10)], spacing: 10) {
            ForEach(AdminMaintenanceImproveAction.shortcuts) { action in
                Button { viewModel.run(action) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(action.title, systemImage: action.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liteAccent)
                        Text(action.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ariaGlass(in: RoundedRectangle(cornerRadius: 14), interactive: true)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isRunning)
            }
        }
    }

    private var stepCard: some View {
        AdminCard(title: "One step", systemImage: AdminMaintenanceImproveAction.improveStep.systemImage) {
            VStack(alignment: .leading, spacing: 10) {
                AdminMaintenanceMenuRow(title: "Step", value: stepValue) {
                    Picker("Step", selection: $viewModel.stepIndex) {
                        ForEach(viewModel.plan.tasks.indices, id: \.self) { Text(viewModel.stepLabel($0)).tag($0) }
                    }
                }
                Button { viewModel.run(.improveStep) } label: {
                    Label(AdminMaintenanceImproveAction.improveStep.title, systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .ariaGlassButtonStyle()
                .disabled(!viewModel.canImproveStep)
            }
        }
    }

    private var stepValue: String {
        viewModel.plan.tasks.indices.contains(viewModel.stepIndex) ? "\(viewModel.stepIndex + 1)" : "—"
    }

    private var customCard: some View {
        AdminCard(title: "Ask something specific", systemImage: AdminMaintenanceImproveAction.custom.systemImage) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("e.g. Add a lockout/tagout step", text: $viewModel.customPrompt, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.subheadline)
                    .focused($promptFocused)
                    .padding(10)
                    .background(Color.liteAccent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Button {
                    promptFocused = false
                    viewModel.run(.custom)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(viewModel.canAskCustom ? Color.liteAccent : Color.secondary.opacity(0.5))
                }
                .disabled(!viewModel.canAskCustom)
                .accessibilityLabel("Send")
            }
        }
    }

    private func failureCard(_ failure: AdminWorkOrderAssistantFailure) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            AdminSectionNotice(text: failure.message, isError: true)
            if !failure.validActions.isEmpty {
                Text("The server accepts these actions. Tap one to try it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(failure.validActions, id: \.self) { action in
                        Button(action) { viewModel.retry(with: action) }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.bordered)
                            .tint(Color.liteAccent)
                            .disabled(viewModel.isRunning)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}
