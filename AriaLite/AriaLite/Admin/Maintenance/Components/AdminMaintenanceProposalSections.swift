//
//  AdminMaintenanceProposalSections.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La proposta dell'AI per il piano, come sezioni di un Form (come quella di un allarme): il testo libero
//  della risposta, ogni parte (passi, ricambi, descrizione, durata) con il suo interruttore e il valore
//  proposto, poi "Apply" (solo le parti scelte) e "Discard". Applicata, la proposta se ne va: il foglio torna
//  alle richieste e conferma con un avviso in alto.
//

import SwiftUI

struct AdminMaintenanceProposalSections: View {
    @Bindable var viewModel: AdminMaintenanceImproveViewModel
    let proposal: AdminMaintenanceProposal

    var body: some View {
        if proposal.text != nil || proposal.raw != nil {
            Section("Proposal") {
                if let text = proposal.text {
                    Text(verbatim: text).textSelection(.enabled)
                }
                if let raw = proposal.raw {
                    Text(verbatim: raw)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        if proposal.hasChanges {
            Section {
                if !proposal.tasks.isEmpty {
                    part("Steps", isOn: $viewModel.applyTasks, lines: numbered(proposal.tasks))
                }
                if !proposal.spareParts.isEmpty {
                    part("Spare parts", isOn: $viewModel.applyParts, lines: proposal.spareParts)
                }
                if let description = proposal.description {
                    part("Description", isOn: $viewModel.applyDescription, lines: [description])
                }
                if let minutes = proposal.estimatedDurationMin {
                    part("Estimated duration", isOn: $viewModel.applyDuration,
                         lines: [AdminMaintenanceFormat.duration(minutes: minutes)])
                }
            } header: {
                Text("Changes")
            } footer: {
                Text("Only the selected parts are written to the plan.")
            }
            Section { controls }
        }
    }

    private func numbered(_ items: [String]) -> [String] {
        items.enumerated().map { "\($0.offset + 1). \($0.element)" }
    }

    private func part(_ title: LocalizedStringKey, isOn: Binding<Bool>, lines: [String]) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(verbatim: line)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if let error = viewModel.applyError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
        Button { Task { await viewModel.apply() } } label: {
            HStack {
                Label("Apply", systemImage: "checkmark")
                Spacer()
                if viewModel.isApplying { ProgressView() }
            }
        }
        .tint(Color.liteAccent)
        .disabled(!viewModel.canApply)
        Button("Discard", systemImage: "xmark", role: .destructive) { viewModel.discard() }
            .disabled(viewModel.isApplying)
    }
}
