//
//  AdminMaintenanceProposalCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La proposta dell'AI per il piano: ogni parte (passi, ricambi, descrizione, durata) con la sua
//  spunta, e "Apply" che scrive solo quelle scelte. Il testo libero della risposta sta sopra.
//

import SwiftUI

struct AdminMaintenanceProposalCard: View {
    @Bindable var viewModel: AdminMaintenanceImproveViewModel
    let proposal: AdminMaintenanceProposal

    var body: some View {
        AdminCard(ariaTitle: "Proposal") {
            VStack(alignment: .leading, spacing: 14) {
                if let text = proposal.text {
                    Text(text).font(.subheadline).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                }
                if let raw = proposal.raw {
                    Text(raw).font(.caption.monospaced()).textSelection(.enabled).foregroundStyle(.secondary)
                }
                if !proposal.tasks.isEmpty {
                    part("Steps", isOn: $viewModel.applyTasks) { numbered(proposal.tasks) }
                }
                if !proposal.spareParts.isEmpty {
                    part("Spare parts", isOn: $viewModel.applyParts) { bullets(proposal.spareParts) }
                }
                if let description = proposal.description {
                    part("Description", isOn: $viewModel.applyDescription) {
                        Text(description).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let minutes = proposal.estimatedDurationMin {
                    part("Estimated duration", isOn: $viewModel.applyDuration) {
                        Text(AdminMaintenanceFormat.duration(minutes: minutes)).font(.subheadline)
                    }
                }
                if proposal.hasChanges { applyControls }
            }
        }
    }

    // MARK: Parti

    private func part<Content: View>(_ title: LocalizedStringKey, isOn: Binding<Bool>,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(title, isOn: isOn)
                .font(.subheadline.weight(.semibold))
                .tint(Color.liteAccent)
                .disabled(viewModel.didApply)
            content()
                .opacity(isOn.wrappedValue ? 1 : 0.5)
        }
    }

    private func numbered(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Text("\(index + 1). \(item)").font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func bullets(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text("• \(item)").font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Applicare

    @ViewBuilder
    private var applyControls: some View {
        if let message = viewModel.applyError { AdminSectionNotice(text: message, isError: true) }
        if viewModel.didApply {
            Label("Applied to the plan", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
        } else {
            Button {
                Task { await viewModel.apply() }
            } label: {
                if viewModel.isApplying {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("Apply selected changes", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
            }
            .ariaGlassButtonStyle()
            .disabled(!viewModel.canApply)
        }
    }
}
