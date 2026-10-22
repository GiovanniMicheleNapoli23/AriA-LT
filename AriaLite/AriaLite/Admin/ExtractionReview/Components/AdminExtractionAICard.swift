//
//  AdminExtractionAICard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda dell'AI nel dettaglio: azioni rapide, richiesta libera, poi la proposta campo per campo
//  con "Apply & save" e "Discard". Lo stato è tutto nel view model.
//

import SwiftUI

struct AdminExtractionAICard: View {
    @Bindable var viewModel: AdminExtractionDetailViewModel

    @ScaledMetric(relativeTo: .subheadline) private var actionWidth = 150

    var body: some View {
        AdminCard(title: LocalizedStringKey(viewModel.item.kind.aiTitle), systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: actionWidth), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(viewModel.aiActions) { action in
                        Button {
                            Task { await viewModel.ask(action) }
                        } label: {
                            HStack(spacing: 6) {
                                if viewModel.aiAction == action {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: action.systemImage)
                                }
                                Text(action.title).lineLimit(2).multilineTextAlignment(.leading)
                            }
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .ariaGlassButtonStyle()
                        .disabled(!viewModel.canAskAI)
                    }
                }
                prompt
                if let message = viewModel.aiError {
                    AdminSectionNotice(text: message, isError: true)
                }
                if let proposal = viewModel.proposal { proposalView(proposal) }
            }
        }
    }

    private var prompt: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask the AI to change something…", text: $viewModel.customPrompt, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .submitLabel(.send)
                .onSubmit { Task { await viewModel.sendPrompt() } }
            Button {
                Task { await viewModel.sendPrompt() }
            } label: {
                if viewModel.aiAction == .custom {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
            }
            .disabled(!viewModel.canSendPrompt)
            .foregroundStyle(Color.liteAccent)
            .accessibilityLabel(Text("Send"))
        }
    }

    @ViewBuilder
    private func proposalView(_ proposal: AdminExtractionAIProposal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            if let text = proposal.text {
                Text(text)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let raw = proposal.raw {
                Text(raw)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(20)
            }
            ForEach(proposal.changes) { AdminExtractionProposalChangeRow(change: $0) }
            HStack(spacing: 10) {
                Button("Discard", role: .cancel) { viewModel.discardProposal() }
                    .ariaGlassButtonStyle()
                Spacer(minLength: 0)
                if !proposal.changes.isEmpty {
                    Button {
                        Task { await viewModel.applyProposal() }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Label("Apply & save", systemImage: "checkmark")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .disabled(viewModel.isSaving || !viewModel.canEdit)
                    .ariaProminentGlassButtonStyle(tint: .liteAccent, foreground: .liteOnAccent)
                }
            }
        }
    }
}
